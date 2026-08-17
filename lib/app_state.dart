import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/auth_service.dart';
import 'core/cloud_sync.dart';
import 'core/device_history.dart';
import 'core/models.dart';
import 'core/offline_queue.dart';
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
  late final CloudSync cloud;
  late final OfflineQueue queue;
  late final DeviceHistory deviceHistory;
  final PlayerService player = PlayerService();

  /// Последнее событие приёма — для показа снекбара.
  SavedItem? lastReceived;
  Timer? _purgeTimer;

  AppState(this.settings, this.store, this.auth) {
    server = ReceiveServer(settings, store);
    discovery = Discovery(settings, () => server.port, auth);
    client = SendClient(settings.deviceName, settings.deviceId);
    cloud = CloudSync(auth, store, settings);
    // Локально добавленный элемент → отправить в облако аккаунта.
    store.onItemAdded = (item) => cloud.maybePush(item);
    // Локальное удаление облачного элемента → удалить и из общего индекса
    // аккаунта, чтобы сообщение исчезло на всех устройствах.
    store.onItemRemoved = (item) => cloud.remove(item);
    // Пин/архив/группа изменились локально → обновить запись в общем
    // индексе, иначе изменение не долетало бы до других устройств.
    store.onItemChanged = (item) => cloud.updateMeta(item);
    // Вход/выход из аккаунта → перезапустить поиск и облако.
    auth.addListener(() {
      discovery.start();
      cloud.start();
    });
    server.onReceived = (item) {
      lastReceived = item;
      notifyListeners();
    };
    settings.addListener(_onSettingsChanged);
  }

  Future<void> startNetwork() async {
    await server.start();
    await discovery.start();
    cloud.start();
    final prefs = await SharedPreferences.getInstance();
    queue = OfflineQueue(prefs, client, discovery, (item) => store.add(item));
    deviceHistory = DeviceHistory(prefs);
    server.onDeviceActivity = (id, name, bytes) =>
        deviceHistory.recordReceived(id, name, bytes);
    // Самоуничтожающиеся сообщения: чистим раз в минуту.
    await store.purgeExpired();
    _purgeTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => store.purgeExpired(),
    );
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

  Future<bool> sendTextTo(Peer peer, String text, {int? ttlSeconds}) async {
    final ok = await client.sendText(peer, text, ttlSeconds: ttlSeconds);
    if (ok) {
      await store.add(
        SavedItem(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          kind: ItemKind.text,
          text: text,
          createdAt: DateTime.now(),
          outgoing: true,
          fromName: peer.name,
          expiresAt: ttlSeconds != null
              ? DateTime.now().add(Duration(seconds: ttlSeconds))
              : null,
        ),
      );
      deviceHistory.recordSent(peer.id, peer.name, text.length);
    }
    return ok;
  }

  /// Локально сохранить текст без отправки (личное «Избранное»).
  Future<void> saveTextLocal(String text, {int? ttlSeconds}) async {
    await store.add(
      SavedItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        kind: ItemKind.text,
        text: text,
        createdAt: DateTime.now(),
        outgoing: true,
        expiresAt: ttlSeconds != null
            ? DateTime.now().add(Duration(seconds: ttlSeconds))
            : null,
      ),
    );
  }

  Stream<double> sendFileTo(Peer peer, File file, {int? ttlSeconds}) async* {
    yield* client.sendFile(peer, file, ttlSeconds: ttlSeconds);
    deviceHistory.recordSent(peer.id, peer.name, await file.length());
  }

  @override
  void dispose() {
    settings.removeListener(_onSettingsChanged);
    _purgeTimer?.cancel();
    discovery.dispose();
    queue.dispose();
    deviceHistory.dispose();
    cloud.stop();
    server.stop();
    client.close();
    player.dispose();
    super.dispose();
  }
}
