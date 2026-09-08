import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../store/store.dart';
import 'models.dart';
import 'settings.dart';
import 'texfi_account.dart';
import 'texfi_config.dart';

/// Мгновенная синхронизация «Избранного» через аккаунт TexFi.
///
/// Чем это отличается от [CloudSync]. Тот опрашивает GitHub Contents API
/// раз в 20 секунд, а GitHub отдаёт ответ с `Cache-Control: s-maxage=60` —
/// то есть даже опрос раз в секунду упирался бы в минутный серверный кэш.
/// Отправленное с телефона доходило до компьютера за минуты, и подкрутить
/// это было нельзя: дело не в частоте опроса, а в том, что опрос — не тот
/// механизм.
///
/// Здесь сервер сам толкает изменение в открытый websocket сразу после
/// коммита транзакции. Никакого ожидания следующего тика и никакого кэша
/// между устройствами.
///
/// Выключено по умолчанию. Приложение офлайновое, и данные лежат на
/// устройстве, — отправлять их на сервер можно только по прямому решению
/// человека, а не потому, что так удобнее разработчику.
class RealtimeSync extends ChangeNotifier {
  RealtimeSync(this.account, this.store, this.settings);

  final TexfiAccount account;
  final Store store;
  final Settings settings;

  RealtimeChannel? _channel;
  bool _running = false;

  /// Последняя ошибка — показывается в настройках. Молча падать нельзя:
  /// человек должен видеть, что синхронизация не работает, а не гадать,
  /// почему файл не пришёл.
  String? error;

  bool get running => _running;

  SupabaseClient get _db => account.client;

  /// Подпись этого устройства. Нужна, чтобы не принимать обратно то, что
  /// сам же и отправил: сервер рассылает событие всем подписчикам, включая
  /// автора.
  String get _device => settings.deviceId;

  Future<void> start() async {
    if (_running) return;
    if (!account.isSignedIn || !settings.texfiSyncEnabled) return;
    _running = true;
    error = null;
    notifyListeners();
    try {
      await pull();
      _subscribe();
    } catch (e) {
      error = '$e';
      _running = false;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    if (_channel != null) {
      await _db.removeChannel(_channel!);
      _channel = null;
    }
    _running = false;
    notifyListeners();
  }

  /// Подписка на изменения своей ленты.
  ///
  /// Фильтр по `user_id` стоит не ради безопасности — её обеспечивает RLS,
  /// и чужую строку сервер не пришлёт в любом случае. Он ради трафика: без
  /// него сервер проверял бы каждое изменение таблицы для каждого
  /// подписчика.
  void _subscribe() {
    final uid = account.userId;
    if (uid == null) return;
    _channel = _db
        .channel('files_items:$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: TexfiConfig.table,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: uid,
          ),
          callback: (payload) => _onInsert(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: TexfiConfig.table,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: uid,
          ),
          // Строка приходит целиком благодаря `replica identity full`
          // (см. supabase/realtime.sql): иначе в событии удаления был бы
          // только ключ.
          callback: (payload) => _onDelete(payload.oldRecord),
        )
        .subscribe();
  }

  /// Первичная выборка при запуске: то, что пришло, пока приложение было
  /// закрыто. Подписка приносит только новое, поэтому без этого шага
  /// устройство навсегда осталось бы без прошлого.
  Future<void> pull() async {
    final uid = account.userId;
    if (uid == null) return;
    final rows = await _db
        .from(TexfiConfig.table)
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(500);
    for (final row in rows) {
      await _accept(row);
    }
  }

  Future<void> _onInsert(Map<String, dynamic> row) async {
    try {
      await _accept(row);
    } catch (e) {
      debugPrint('RealtimeSync insert failed: $e');
    }
  }

  Future<void> _onDelete(Map<String, dynamic> row) async {
    final id = row['id'] as String?;
    if (id == null) return;
    final local = store.byId(id);
    if (local != null) await store.remove(local, notifyCloud: false);
  }

  /// Принять серверную строку в локальную ленту.
  ///
  /// Три причины отказаться, и все три обязательны: своё эхо, уже
  /// имеющееся, и удалённое человеком раньше (иначе удалённый элемент
  /// возвращался бы при каждом запуске — «зомби», самая раздражающая
  /// болезнь синхронизаций).
  Future<void> _accept(Map<String, dynamic> row) async {
    final id = row['id'] as String?;
    if (id == null) return;
    if (row['from_device'] == _device) return;
    if (store.has(id) || store.isDeleted(id)) return;

    final kindName = row['kind'] as String? ?? 'file';
    final kind = ItemKind.values.firstWhere(
      (k) => k.name == kindName,
      orElse: () => ItemKind.file,
    );

    // Файл сам по себе не скачивается: в ленте появляется запись, а
    // содержимое подтягивается по требованию ([download]). Иначе всякий
    // новый телефон немедленно тянул бы к себе всю историю целиком.
    await store.addRemote(
      SavedItem(
        id: id,
        kind: kind,
        text: row['body'] as String?,
        fileName: row['file_name'] as String?,
        fileSize: (row['size_bytes'] as num?)?.toInt() ?? 0,
        mime: row['mime'] as String?,
        createdAt:
            DateTime.tryParse(row['created_at'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
        outgoing: false,
        fromName: 'Аккаунт',
        archived: row['archived'] as bool? ?? false,
        group: row['folder'] as String?,
        cloud: true,
        remotePath: row['object_path'] as String?,
      ),
    );
  }

  /// Отправить элемент в аккаунт. Возвращает `false`, если отправка не
  /// состоялась, — вызывающая сторона показывает это человеку, а не делает
  /// вид, что всё ушло.
  Future<bool> push(SavedItem item) async {
    final uid = account.userId;
    if (uid == null || !settings.texfiSyncEnabled) return false;
    try {
      String? objectPath;

      if (item.kind != ItemKind.text) {
        final path = item.filePath;
        if (path == null) return false;
        final file = File(path);
        if (!await file.exists()) return false;
        final size = await file.length();
        if (size > TexfiConfig.cloudMaxBytes) {
          error = 'Файл больше 90 МБ — такие идут только напрямую по сети';
          notifyListeners();
          return false;
        }
        // Путь начинается с идентификатора владельца: правила Storage
        // сверяют именно первую часть пути, подделать её нельзя.
        objectPath = '$uid/${item.id}_${item.fileName ?? 'file'}';
        await _db.storage.from(TexfiConfig.bucket).upload(
              objectPath,
              file,
              fileOptions: FileOptions(contentType: item.mime, upsert: true),
            );
      }

      await _db.from(TexfiConfig.table).insert({
        'id': item.id,
        'user_id': uid,
        'kind': item.kind.name,
        if (item.kind == ItemKind.text) 'body': item.text,
        'file_name': item.fileName,
        'mime': item.mime,
        'size_bytes': item.fileSize,
        'object_path': objectPath,
        'folder': item.group,
        'archived': item.archived,
        'from_device': _device,
        'created_at': item.createdAt.toUtc().toIso8601String(),
      });

      item.cloud = true;
      item.remotePath = objectPath;
      await store.persist();
      error = null;
      notifyListeners();
      return true;
    } catch (e) {
      error = '$e';
      notifyListeners();
      return false;
    }
  }

  /// Скачать содержимое элемента, который пришёл как запись без файла.
  Future<bool> download(SavedItem item) async {
    final path = item.remotePath;
    if (path == null) return false;
    try {
      final bytes = await _db.storage.from(TexfiConfig.bucket).download(path);
      final target = store.newFileFor(item.fileName ?? 'file');
      await target.writeAsBytes(bytes);
      await store.updateFilePath(item, target.path);
      return true;
    } catch (e) {
      error = '$e';
      notifyListeners();
      return false;
    }
  }

  /// Убрать элемент из аккаунта — и строку, и объект в хранилище.
  Future<void> removeRemote(SavedItem item) async {
    if (!item.cloud) return;
    try {
      final path = item.remotePath;
      if (path != null) {
        await _db.storage.from(TexfiConfig.bucket).remove([path]);
      }
      await _db.from(TexfiConfig.table).delete().eq('id', item.id);
    } catch (e) {
      debugPrint('RealtimeSync remove failed: $e');
    }
  }

  @override
  void dispose() {
    if (_channel != null) _db.removeChannel(_channel!);
    super.dispose();
  }
}
