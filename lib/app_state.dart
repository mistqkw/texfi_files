import 'dart:io';
import 'package:flutter/foundation.dart';
import 'core/auth_service.dart';
import 'core/models.dart';
import 'core/player_service.dart';
import 'core/settings.dart';
import 'net/client.dart';
import 'net/discovery.dart';
import 'net/server.dart';
import 'store/store.dart';

/// Центральный узел приложения: владеет всеми сервисами и высокоуровневыми
/// действиями (отправка текста/файла, выбор целевого пира и т.д.).
class AppState extends ChangeNotifier {
  final Settings settings;
  final Store store;
  final AuthService auth;
  late final ReceiveServer server;
  late final Discovery discovery;
  late final SendClient client;
  final PlayerService player = PlayerService();

  /// Последнее событие приёма — для показа снекбара.
  SavedItem? lastReceived;

  AppState(this.settings, this.store, this.auth) {
    server = ReceiveServer(settings, store);
    discovery = Discovery(settings, () => server.port, () => auth.accountId);
    client = SendClient(settings.deviceName);
    // Смена аккаунта → обновить анонсы.
    auth.addListener(() => discovery.notifyListeners());
    server.onReceived = (item) {
      lastReceived = item;
      notifyListeners();
    };
    settings.addListener(_onSettingsChanged);
  }

  Future<void> startNetwork() async {
    await server.start();
    await discovery.start();
    notifyListeners();
  }

  void _onSettingsChanged() {
    // Имя устройства могло измениться — пересоздаём клиент лениво не нужно,
    // но обновим анонсы поиском.
    discovery.notifyListeners();
  }

  List<Peer> get peers => discovery.peers;

  /// Пир доверенный, если он в том же аккаунте, что и мы.
  bool isTrusted(Peer p) =>
      auth.accountId != null && p.accountId == auth.accountId;

  Peer? get preferredPeer {
    final online = peers.where((p) => p.online).toList();
    if (online.isEmpty) return null;
    // Сначала — доверенные устройства своего аккаунта.
    final trusted = online.where(isTrusted).toList();
    return trusted.isNotEmpty ? trusted.first : online.first;
  }

  // --- Отправка ---

  Future<bool> sendTextTo(Peer peer, String text) async {
    final ok = await client.sendText(peer, text);
    if (ok) {
      await store.add(SavedItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        kind: ItemKind.text,
        text: text,
        createdAt: DateTime.now(),
        outgoing: true,
        fromName: peer.name,
      ));
    }
    return ok;
  }

  /// Локально сохранить текст без отправки (личное «Избранное»).
  Future<void> saveTextLocal(String text) async {
    await store.add(SavedItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      kind: ItemKind.text,
      text: text,
      createdAt: DateTime.now(),
      outgoing: true,
    ));
  }

  Stream<double> sendFileTo(Peer peer, File file) => client.sendFile(peer, file);

  @override
  void dispose() {
    settings.removeListener(_onSettingsChanged);
    discovery.dispose();
    server.stop();
    client.close();
    player.dispose();
    super.dispose();
  }
}
