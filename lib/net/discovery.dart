import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/auth_service.dart';
import '../core/models.dart';
import '../core/settings.dart';

/// Поиск устройств ЧЕРЕЗ АККАУНТ (без локального broadcast).
///
/// Устройства одного GitHub-аккаунта публикуют свой адрес в приватный Gist
/// и находят друг друга через него — GitHub служит точкой встречи, свой сервер
/// не нужен. В одной сети соединяются напрямую по опубликованному IP.
class Discovery extends ChangeNotifier {
  static const _gistDescription = 'TexFi files — реестр устройств (не удалять)';
  static const _registryMarker = 'texfi-registry.json';

  final Settings settings;
  final int Function() httpPortProvider;
  final AuthService auth;
  Discovery(this.settings, this.httpPortProvider, this.auth);

  final Map<String, Peer> _peers = {};
  Timer? _timer;
  String? _gistId;
  bool _busy = false;

  List<Peer> get peers {
    final list = _peers.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${auth.token}',
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'TexFi-files',
      };

  Future<void> start() async {
    await stop();
    if (!auth.isLoggedIn || auth.token == null) {
      // Вышли из аккаунта — очищаем список (кроме добавленных вручную).
      _peers.removeWhere((id, p) => p.accountId != 'manual');
      notifyListeners();
      return;
    }
    _sync();
    _timer = Timer.periodic(const Duration(seconds: 12), (_) => _sync());
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _sync() async {
    if (_busy || auth.token == null) return;
    _busy = true;
    try {
      await _ensureGist();
      if (_gistId == null) return;
      await _publishSelf();
      await _fetchPeers();
    } catch (e) {
      debugPrint('Discovery(gist): $e');
    } finally {
      _busy = false;
    }
  }

  /// Найти или создать приватный gist-реестр.
  Future<void> _ensureGist() async {
    if (_gistId != null) return;
    // Ищем среди своих гистов.
    final list = await http.get(
      Uri.parse('https://api.github.com/gists?per_page=100'),
      headers: _headers,
    );
    if (list.statusCode == 200) {
      final arr = jsonDecode(list.body) as List<dynamic>;
      for (final g in arr) {
        final files = (g['files'] as Map<String, dynamic>?) ?? {};
        if (g['description'] == _gistDescription ||
            files.containsKey(_registryMarker)) {
          _gistId = g['id'] as String?;
          if (_gistId != null) return;
        }
      }
    }
    // Не нашли — создаём.
    final create = await http.post(
      Uri.parse('https://api.github.com/gists'),
      headers: _headers,
      body: jsonEncode({
        'description': _gistDescription,
        'public': false,
        'files': {
          _registryMarker: {'content': '{"app":"texfi-files"}'},
        },
      }),
    );
    if (create.statusCode == 201) {
      _gistId = (jsonDecode(create.body) as Map<String, dynamic>)['id']
          as String?;
    }
  }

  Future<String?> _localIp() async {
    try {
      final ifs = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final i in ifs) {
        for (final a in i.addresses) {
          if (!a.isLoopback) return a.address;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Опубликовать свой адрес в реестр.
  Future<void> _publishSelf() async {
    final ip = await _localIp();
    if (ip == null) return;
    final content = jsonEncode({
      'id': settings.deviceId,
      'name': settings.deviceName,
      'platform': Platform.isAndroid ? 'android' : 'linux',
      'ip': ip,
      'port': httpPortProvider(),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
    await http.patch(
      Uri.parse('https://api.github.com/gists/$_gistId'),
      headers: _headers,
      body: jsonEncode({
        'files': {
          'device-${settings.deviceId}.json': {'content': content},
        },
      }),
    );
  }

  /// Прочитать реестр и собрать список пиров.
  Future<void> _fetchPeers() async {
    final resp = await http.get(
      Uri.parse('https://api.github.com/gists/$_gistId'),
      headers: _headers,
    );
    if (resp.statusCode != 200) return;
    final files =
        (jsonDecode(resp.body) as Map<String, dynamic>)['files'] as Map;
    var changed = false;
    final seen = <String>{};
    for (final entry in files.entries) {
      final fname = entry.key as String;
      if (!fname.startsWith('device-')) continue;
      try {
        final content = (entry.value as Map)['content'] as String;
        final j = jsonDecode(content) as Map<String, dynamic>;
        final id = j['id'] as String?;
        if (id == null || id == settings.deviceId) continue; // не считаем себя
        final updated =
            DateTime.tryParse(j['updatedAt'] as String? ?? '')?.toLocal();
        // Отсеиваем давно неактивные (>5 мин).
        if (updated != null &&
            DateTime.now().difference(updated) > const Duration(minutes: 5)) {
          continue;
        }
        seen.add(id);
        final peer = Peer(
          id: id,
          name: (j['name'] as String?) ?? 'Устройство',
          platform: (j['platform'] as String?) ?? '?',
          address: (j['ip'] as String?) ?? '',
          httpPort: (j['port'] as num?)?.toInt() ?? 0,
          accountId: auth.accountId, // все из реестра — свой аккаунт
          lastSeen: updated ?? DateTime.now(),
        );
        // Сравниваем с тем, что уже знаем. lastSeen в сравнение не входит:
        // он меняется на каждом опросе, и по нему «изменилось» было бы
        // истинно всегда — ради этого поля перерисовывать экран незачем.
        final prev = _peers[id];
        if (prev == null ||
            prev.name != peer.name ||
            prev.platform != peer.platform ||
            prev.address != peer.address ||
            prev.httpPort != peer.httpPort ||
            prev.online != peer.online) {
          changed = true;
        }
        _peers[id] = peer;
      } catch (_) {}
    }
    // Убираем исчезнувшие (кроме добавленных вручную).
    final before = _peers.length;
    _peers.removeWhere(
        (id, p) => !seen.contains(id) && p.accountId != 'manual');
    // Уведомляем один раз и только если список действительно изменился.
    // Раньше здесь стояли два вызова подряд, второй — безусловный: опрос
    // идёт каждые 12 секунд, и каждый его цикл перестраивал весь главный
    // экран (фон, шапку, всю ленту) даже когда ничего не менялось.
    if (changed || _peers.length != before) notifyListeners();
  }

  /// Ручное подключение по IP (fallback, handshake /info).
  Future<String?> addManual(String host, int port) async {
    try {
      final resp = await http
          .get(Uri.parse('http://$host:$port/info'))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) return null;
      final j = jsonDecode(resp.body) as Map<String, dynamic>;
      final id = j['id'] as String? ?? '$host:$port';
      if (id == settings.deviceId) return null;
      _peers[id] = Peer(
        id: id,
        name: (j['name'] as String?) ?? host,
        platform: (j['platform'] as String?) ?? '?',
        address: host,
        httpPort: port,
        accountId: 'manual',
        lastSeen: DateTime.now(),
      );
      notifyListeners();
      return _peers[id]!.name;
    } catch (e) {
      debugPrint('addManual err: $e');
      return null;
    }
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
