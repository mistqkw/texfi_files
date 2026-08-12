import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';
import '../core/models.dart';

/// Отправка текста/файлов/клавиш на пир по HTTP.
class SendClient {
  final String deviceName;
  final String deviceId;
  SendClient(this.deviceName, this.deviceId);

  final _http = HttpClient()..connectionTimeout = const Duration(seconds: 8);

  Future<bool> sendText(Peer peer, String text, {int? ttlSeconds}) async {
    try {
      final req = await _http.postUrl(Uri.parse('${peer.baseUrl}/message'));
      req.headers.contentType = ContentType('text', 'plain', charset: 'utf-8');
      req.headers.set('x-from', Uri.encodeComponent(deviceName));
      req.headers.set('x-device-id', deviceId);
      if (ttlSeconds != null) req.headers.set('x-ttl-seconds', '$ttlSeconds');
      req.add(utf8.encode(text));
      final resp = await req.close();
      await resp.drain();
      return resp.statusCode == HttpStatus.ok;
    } catch (e) {
      debugPrint('sendText err: $e');
      return false;
    }
  }

  /// Отправка файла потоком. Возвращает поток прогресса 0..1.
  Stream<double> sendFile(Peer peer, File file, {int? ttlSeconds}) async* {
    final total = await file.length();
    final name = file.uri.pathSegments.last;
    final mime = lookupMimeType(file.path) ?? 'application/octet-stream';
    try {
      final req = await _http.postUrl(Uri.parse('${peer.baseUrl}/file'));
      req.headers.set('x-filename', Uri.encodeComponent(name));
      req.headers.set('x-mime', mime);
      req.headers.set('x-from', Uri.encodeComponent(deviceName));
      req.headers.set('x-device-id', deviceId);
      if (ttlSeconds != null) req.headers.set('x-ttl-seconds', '$ttlSeconds');
      req.headers.contentType = ContentType.parse(mime);
      if (total > 0) req.contentLength = total;

      var sent = 0;
      await for (final chunk in file.openRead()) {
        req.add(chunk);
        sent += chunk.length;
        yield total > 0 ? sent / total : 0.0;
      }
      final resp = await req.close();
      await resp.drain();
      if (resp.statusCode != HttpStatus.ok) {
        throw HttpException('статус ${resp.statusCode}');
      }
      yield 1.0;
    } catch (e) {
      debugPrint('sendFile err: $e');
      rethrow;
    }
  }

  Future<bool> sendTyping(Peer peer,
      {String? text, String? key, int count = 1}) async {
    try {
      final req = await _http.postUrl(Uri.parse('${peer.baseUrl}/key'));
      req.headers.contentType = ContentType.json;
      req.add(utf8.encode(jsonEncode({
        'type': key != null ? 'key' : 'text',
        if (text != null) 'text': text,
        if (key != null) 'key': key,
        if (key != null) 'count': count,
      })));
      final resp = await req.close();
      await resp.drain();
      return resp.statusCode == HttpStatus.ok;
    } catch (e) {
      debugPrint('sendTyping err: $e');
      return false;
    }
  }

  void close() => _http.close(force: true);
}
