import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../core/models.dart';
import '../core/settings.dart';
import '../store/store.dart';
import 'remote_input.dart';

/// HTTP-сервер приёма: текст, файлы (потоком, любой размер) и события ввода.
class ReceiveServer {
  final Settings settings;
  final Store store;
  ReceiveServer(this.settings, this.store);

  HttpServer? _server;
  int get port => _server?.port ?? 0;

  /// Вызывается при получении текста/файла (для уведомления в UI).
  void Function(SavedItem item)? onReceived;

  // Предпочтительный фиксированный порт — чтобы легко открыть в фаерволе.
  // Если занят, пробуем следующие, и лишь потом произвольный.
  static const preferredPort = 45889;
  static const _portRange = 11; // 45889..45899

  Future<void> start() async {
    await stop();
    for (var i = 0; i < _portRange; i++) {
      try {
        _server = await HttpServer.bind(
            InternetAddress.anyIPv4, preferredPort + i,
            shared: true);
        break;
      } catch (_) {
        // порт занят — пробуем следующий
      }
    }
    // Крайний случай: любой свободный порт.
    _server ??= await HttpServer.bind(InternetAddress.anyIPv4, 0, shared: true);
    debugPrint('ReceiveServer слушает на :$port');
    _server!.listen(_handle, onError: (e) => debugPrint('server err: $e'));
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _handle(HttpRequest req) async {
    try {
      switch (req.uri.path) {
        case '/info':
          _json(req, {
            'id': settings.deviceId,
            'name': settings.deviceName,
            'platform': Platform.isAndroid ? 'android' : 'linux',
          });
          break;
        case '/message':
          await _handleMessage(req);
          break;
        case '/file':
          await _handleFile(req);
          break;
        case '/key':
          await _handleKey(req);
          break;
        default:
          req.response.statusCode = HttpStatus.notFound;
          await req.response.close();
      }
    } catch (e) {
      debugPrint('handle err: $e');
      try {
        req.response.statusCode = HttpStatus.internalServerError;
        await req.response.close();
      } catch (_) {}
    }
  }

  String _decodeFrom(HttpRequest req) {
    final raw = req.headers.value('x-from');
    if (raw == null) return 'Устройство';
    try {
      return Uri.decodeComponent(raw);
    } catch (_) {
      return raw;
    }
  }

  void _json(HttpRequest req, Map<String, dynamic> body) {
    req.response
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    req.response.close();
  }

  Future<void> _handleMessage(HttpRequest req) async {
    final text = await utf8.decoder.bind(req).join();
    final from = _decodeFrom(req);
    final item = SavedItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      kind: ItemKind.text,
      text: text,
      createdAt: DateTime.now(),
      outgoing: false,
      fromName: from,
    );
    await store.add(item);
    onReceived?.call(item);
    req.response
      ..statusCode = HttpStatus.ok
      ..write('ok');
    await req.response.close();
  }

  Future<void> _handleFile(HttpRequest req) async {
    final rawName = req.headers.value('x-filename') ?? 'file.bin';
    final name = Uri.decodeComponent(rawName);
    final mime =
        req.headers.value('x-mime') ?? req.headers.contentType?.mimeType;
    final from = _decodeFrom(req);
    final ttlSeconds = int.tryParse(req.headers.value('x-ttl-seconds') ?? '');
    final expectedTotal = req.contentLength > 0 ? req.contentLength : 0;

    final kind = kindFromMime(mime, name);
    final target = store.newFileFor(name);

    // Плейсхолдер «идёт приём» — сразу виден в ленте с прогресс-баром.
    final item = SavedItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      kind: kind,
      filePath: target.path,
      fileName: name,
      mime: mime,
      createdAt: DateTime.now(),
      outgoing: false,
      fromName: from,
      receiving: true,
      expectedSize: expectedTotal,
      expiresAt: ttlSeconds != null
          ? DateTime.now().add(Duration(seconds: ttlSeconds))
          : null,
    );
    await store.addReceiving(item);

    final sink = target.openWrite();
    var received = 0;
    var lastNotify = 0;
    try {
      await for (final chunk in req) {
        sink.add(chunk);
        received += chunk.length;
        // Не дёргаем UI на каждый чанк — раз в ~256KB достаточно для плавного бара.
        if (received - lastNotify > 256 * 1024) {
          lastNotify = received;
          store.updateReceivedBytes(item, received);
        }
      }
      await sink.flush();
    } catch (e) {
      await sink.close();
      await store.cancelReceiving(item);
      rethrow;
    }
    await sink.close();

    await store.finishReceiving(item, received);
    onReceived?.call(item);

    req.response
      ..statusCode = HttpStatus.ok
      ..write('ok');
    await req.response.close();
  }

  Future<void> _handleKey(HttpRequest req) async {
    if (!settings.remoteInputEnabled || !RemoteInput.supported) {
      req.response.statusCode = HttpStatus.forbidden;
      await req.response.close();
      return;
    }
    final body = await utf8.decoder.bind(req).join();
    bool ok = false;
    try {
      final j = jsonDecode(body) as Map<String, dynamic>;
      final type = j['type'] as String?;
      if (type == 'text') {
        ok = await RemoteInput.typeText(j['text'] as String? ?? '');
      } else if (type == 'key') {
        final count = (j['count'] as num?)?.toInt() ?? 1;
        ok = await RemoteInput.pressKey(j['key'] as String? ?? '',
            count: count);
      }
    } catch (e) {
      debugPrint('key parse err: $e');
    }
    req.response
      ..statusCode = ok ? HttpStatus.ok : HttpStatus.badRequest
      ..write(ok ? 'ok' : 'fail');
    await req.response.close();
  }
}
