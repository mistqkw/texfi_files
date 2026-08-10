import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/models.dart';
import '../core/settings.dart';

/// Авто-поиск устройств в локальной сети через UDP-broadcast.
///
/// Каждое устройство периодически рассылает анонс со своим id/именем/портом
/// HTTP-сервера и слушает анонсы других. Пиры с давним lastSeen отсеиваются.
class Discovery extends ChangeNotifier {
  static final _group = InternetAddress('239.255.42.99');

  final Settings settings;
  final int Function() httpPortProvider;
  Discovery(this.settings, this.httpPortProvider);

  RawDatagramSocket? _socket;
  Timer? _announceTimer;
  Timer? _reapTimer;
  final Map<String, Peer> _peers = {};

  List<Peer> get peers {
    final list = _peers.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Future<void> start() async {
    await stop();
    if (!settings.autoDiscovery) return;
    final port = settings.discoveryPort;
    try {
      try {
        _socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          port,
          reuseAddress: true,
          reusePort: true,
        );
      } catch (_) {
        // Windows не поддерживает reusePort — пробуем без него.
        _socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          port,
          reuseAddress: true,
        );
      }
      _socket!.broadcastEnabled = true;
      _socket!.multicastLoopback = true;
      try {
        _socket!.joinMulticast(_group);
      } catch (e) {
        debugPrint('Discovery: joinMulticast — $e');
      }
      _socket!.listen(_onEvent);
    } catch (e) {
      debugPrint('Discovery: не смог открыть сокет :$port — $e');
      return;
    }
    _announce();
    _announceTimer =
        Timer.periodic(const Duration(seconds: 3), (_) => _announce());
    _reapTimer = Timer.periodic(const Duration(seconds: 4), (_) => _reap());
  }

  Future<void> stop() async {
    _announceTimer?.cancel();
    _reapTimer?.cancel();
    _socket?.close();
    _socket = null;
  }

  void _onEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final dg = _socket?.receive();
    if (dg == null) return;
    try {
      final msg = jsonDecode(utf8.decode(dg.data)) as Map<String, dynamic>;
      if (msg['t'] != 'texfi') return;
      final id = msg['id'] as String?;
      if (id == null || id == settings.deviceId) return; // не считаем себя
      final peer = Peer(
        id: id,
        name: (msg['name'] as String?) ?? 'Устройство',
        platform: (msg['platform'] as String?) ?? '?',
        address: dg.address.address,
        httpPort: (msg['httpPort'] as num?)?.toInt() ?? 0,
        lastSeen: DateTime.now(),
      );
      final existed = _peers.containsKey(id);
      _peers[id] = peer;
      if (!existed) notifyListeners();
    } catch (_) {
      // мусорный пакет — игнор
    }
  }

  /// Ручное добавление устройства по IP (handshake /info).
  /// Возвращает имя устройства при успехе, иначе null.
  Future<String?> addManual(String host, int port) async {
    try {
      final resp = await http
          .get(Uri.parse('http://$host:$port/info'))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) return null;
      final j = jsonDecode(resp.body) as Map<String, dynamic>;
      final id = j['id'] as String? ?? '$host:$port';
      if (id == settings.deviceId) return null; // это мы сами
      _peers[id] = Peer(
        id: id,
        name: (j['name'] as String?) ?? host,
        platform: (j['platform'] as String?) ?? '?',
        address: host,
        httpPort: port,
        lastSeen: DateTime.now(),
      );
      notifyListeners();
      return _peers[id]!.name;
    } catch (e) {
      debugPrint('addManual err: $e');
      return null;
    }
  }

  void _announce() {
    final sock = _socket;
    if (sock == null) return;
    final payload = utf8.encode(jsonEncode({
      't': 'texfi',
      'id': settings.deviceId,
      'name': settings.deviceName,
      'platform': Platform.isAndroid ? 'android' : 'linux',
      'httpPort': httpPortProvider(),
    }));
    try {
      sock.send(payload, _group, settings.discoveryPort);
      // Дублируем limited broadcast — на случай сетей без multicast.
      sock.send(payload, InternetAddress('255.255.255.255'),
          settings.discoveryPort);
    } catch (e) {
      debugPrint('Discovery: анонс не ушёл — $e');
    }
  }

  void _reap() {
    final before = _peers.length;
    _peers.removeWhere((_, p) =>
        DateTime.now().difference(p.lastSeen) > const Duration(seconds: 15));
    if (_peers.length != before) notifyListeners();
    // Периодически обновляем «online» индикаторы.
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
