import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_config.dart';
import 'auth_service.dart';
import 'crypto_util.dart';
import 'models.dart';
import 'settings.dart';
import '../store/store.dart';

/// Облачное хранилище аккаунта на приватном GitHub-репозитории.
///
/// Гибрид: текст и файлы до [AuthConfig.cloudMaxBytes] уходят в репозиторий
/// (доступны с любого устройства/сети). Большие файлы остаются локальными.
/// Маршрутизация облако/P2P управляется [Settings.cloudMode]; одинаковые
/// файлы (по SHA-256) переиспользуют уже загруженную копию (дедупликация).
class CloudSync extends ChangeNotifier {
  final AuthService auth;
  final Store store;
  final Settings settings;
  CloudSync(this.auth, this.store, this.settings);

  static const _indexPath = 'index.json';
  static const _api = 'https://api.github.com';

  Timer? _timer;
  bool _busy = false;
  bool _repoReady = false;
  String? lastError;
  bool syncing = false;
  bool needsReauth = false; // токен без права repo → нужен повторный вход

  // Сколько пуллов подряд элемент отсутствовал в удалённом индексе, прежде
  // чем мы поверим, что его удалили на другом устройстве, а не что это
  // сетевой сбой/гонка с maybePush. Без этого один неполный/неудачный ответ
  // GitHub стирал (и надгробил — без возврата) всю облачную ленту локально.
  final Map<String, int> _missingStreak = {};

  // Индекс в облаке (index.json) обновляется через optimistic-concurrency по
  // sha: параллельные записи, стартовавшие с одного sha, конфликтуют (409).
  // Когда быстро отправляется много сообщений, каждое `maybePush` дёргает
  // `_appendIndex` одновременно → лавина конфликтов, и часть сообщений вообще
  // не сохранялась в облако. Сериализуем ВСЕ мутации индекса одной цепочкой
  // Future, чтобы они шли строго по очереди (файлы при этом грузятся
  // параллельно — они пишутся по уникальным путям и не конфликтуют).
  Future<void> _indexGate = Future.value();

  /// Выполнить [action] эксклюзивно относительно других мутаций индекса.
  Future<T> _lockIndex<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _indexGate = _indexGate.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  bool get available => auth.isLoggedIn && auth.token != null;
  String? get _owner => auth.account?.login;

  Map<String, String> get _headers => {
    'Authorization': 'Bearer ${auth.token}',
    'Accept': 'application/vnd.github+json',
    'User-Agent': 'TexFi-files',
  };

  String get _repoBase => '$_api/repos/$_owner/${AuthConfig.storageRepo}';

  void start() {
    stop();
    needsReauth = false;
    _repoReady = false;
    if (!available) return;
    pull();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => pull());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  // ── Отправка нового элемента в облако ──
  Future<void> maybePush(SavedItem item) async {
    if (!available || item.cloud) return;
    // Режим «только P2P» — файлы в облако не уходят вовсе (текст всё равно
    // синхронизируем, иначе кросс-сетевая лента вообще не работает для него).
    final filesAllowed = settings.cloudMode != 2;
    try {
      await _ensureRepo();
      if (item.kind == ItemKind.text) {
        await _appendIndex(_entryOf(item));
        item.cloud = true;
        await store.persist();
      } else if (filesAllowed &&
          item.filePath != null &&
          item.fileSize > 0 &&
          item.fileSize <= AuthConfig.cloudMaxBytes) {
        final raw = await File(item.filePath!).readAsBytes();
        final hash = await sha256Hex(raw);
        item.fileHash = hash;

        // Дедупликация: если файл с таким же хэшем уже в облаке — переиспользуем.
        final dup = await _findByHash(hash);
        if (dup != null) {
          item.remotePath = dup.remotePath;
          item.encrypted = dup.encrypted;
        } else {
          final safe = (item.fileName ?? 'file').replaceAll(
            RegExp(r'[^\w.\-]'),
            '_',
          );
          final remote = 'files/${hash.substring(0, 16)}__$safe';
          final toUpload = settings.encryptCloud
              ? await CryptoUtil.encrypt(raw)
              : raw;
          await _putFile(remote, toUpload);
          item.remotePath = remote;
          item.encrypted = settings.encryptCloud;
        }
        await _appendIndex(_entryOf(item));
        item.cloud = true;
        await store.persist();
      }
      // Большие файлы / режим «только P2P» — остаются только локальными.
      notifyListeners();
    } catch (e) {
      lastError = '$e';
      debugPrint('CloudSync push: $e');
    }
  }

  // ── Удаление элемента из общего индекса аккаунта ──
  // Так удаление распространяется на все устройства аккаунта: следующий
  // pull() на другом устройстве обнаружит, что запись пропала из индекса,
  // и уберёт элемент локально (см. pull()).
  Future<void> remove(SavedItem item) async {
    if (!available) return;
    try {
      await _ensureRepo();
      await _removeFromIndex(item.id);
    } catch (e) {
      lastError = '$e';
      debugPrint('CloudSync remove: $e');
    }
  }

  Future<void> _removeFromIndex(String id) => _lockIndex(() async {
    for (var attempt = 0; attempt < 8; attempt++) {
      final (list, sha) = await _getIndex();
      final before = list.length;
      list.removeWhere((e) => e['id'] == id);
      if (list.length == before) return; // уже удалено
      final content = base64.encode(utf8.encode(jsonEncode(list)));
      final resp = await http.put(
        Uri.parse('$_repoBase/contents/$_indexPath'),
        headers: _headers,
        body: jsonEncode({
          'message': 'remove $id',
          'content': content,
          if (sha != null) 'sha': sha,
        }),
      );
      if (resp.statusCode == 200 || resp.statusCode == 201) return;
      if (resp.statusCode == 409 || resp.statusCode == 422) {
        await Future.delayed(Duration(milliseconds: 250 + attempt * 250));
        continue; // конфликт версий — перечитаем и повторим
      }
      throw Exception('index put ${resp.statusCode}: ${resp.body}');
    }
    throw Exception('index remove: не удалось после повторов');
  });

  /// Ищет в уже загруженном индексе запись с тем же хэшем файла (дедуп).
  Future<SavedItem?> _findByHash(String hash) async {
    try {
      final (list, _) = await _getIndex();
      for (final e in list) {
        if (e['fileHash'] == hash && e['remotePath'] != null) {
          return SavedItem(
            id: 'dup',
            kind: ItemKind.file,
            remotePath: e['remotePath'] as String,
            encrypted: e['encrypted'] as bool? ?? false,
            createdAt: DateTime.now(),
          );
        }
      }
    } catch (_) {}
    return null;
  }

  Map<String, dynamic> _entryOf(SavedItem it) => {
    'id': it.id,
    'kind': it.kind.name,
    'text': it.text,
    'fileName': it.fileName,
    'fileSize': it.fileSize,
    'mime': it.mime,
    'createdAt': it.createdAt.toIso8601String(),
    'pinned': it.pinned,
    'group': it.group,
    'remotePath': it.remotePath,
    'fileHash': it.fileHash,
    'encrypted': it.encrypted,
    'expiresAt': it.expiresAt?.toIso8601String(),
  };

  // ── Забрать ленту из облака ──
  Future<void> pull() async {
    if (_busy || !available || needsReauth) return;
    _busy = true;
    syncing = true;
    notifyListeners();
    try {
      await _ensureRepo();
      final idx = await _getIndex();
      final entries = idx.$1;
      for (final e in entries) {
        final id = e['id'] as String?;
        if (id == null || store.has(id)) continue;
        await _materialize(e);
      }
      // Удаления с других устройств: если элемент был получен из облака,
      // но его больше нет в общем индексе — убираем и здесь.
      //
      // Пустой список записей почти наверняка означает сбой/неполный ответ
      // при чтении индекса, а не то, что пользователь и правда всё удалил —
      // в этом случае просто пропускаем цикл сверки, ничего не трогая.
      final hasCloudItems = store.items.any((it) => it.cloud);
      if (entries.isEmpty && hasCloudItems) {
        lastError = null;
        return;
      }
      final remoteIds = entries
          .map((e) => e['id'] as String?)
          .whereType<String>()
          .toSet();
      // Элемент, только что отправленный этим же устройством, может ещё не
      // попасть в индекс из-за гонки с maybePush — не считаем это удалением.
      _missingStreak.removeWhere((id, _) => remoteIds.contains(id));
      final goneLocally = <SavedItem>[];
      for (final it in store.items.where((it) => it.cloud)) {
        if (remoteIds.contains(it.id)) continue;
        final streak = (_missingStreak[it.id] ?? 0) + 1;
        _missingStreak[it.id] = streak;
        // Требуем несколько пуллов подряд без элемента, прежде чем поверить
        // в удаление — один неудачный/неполный ответ не должен стирать ленту.
        if (streak >= 3) goneLocally.add(it);
      }
      for (final it in goneLocally) {
        await store.remove(it, notifyCloud: false);
        _missingStreak.remove(it.id);
      }
      lastError = null;
    } catch (e) {
      lastError = '$e';
      debugPrint('CloudSync pull: $e');
    } finally {
      _busy = false;
      syncing = false;
      notifyListeners();
    }
    // Самовосстановление: если прошлый maybePush не смог сохранить элемент в
    // облако (сеть/лимиты), он навсегда оставался cloud=false и не появлялся
    // на других устройствах. Раз в цикл пуллинга досылаем такие «зависшие»
    // локальные элементы. maybePush идемпотентен и дёшев для того, что и так
    // не должно уходить в облако (большие файлы).
    await _repushPending();
  }

  Future<void> _repushPending() async {
    if (!available) return;
    final pending = store.items
        .where(
          (it) =>
              !it.cloud &&
              it.outgoing &&
              !it.receiving &&
              (it.kind == ItemKind.text || it.filePath != null),
        )
        .toList();
    for (final it in pending) {
      await maybePush(it);
    }
  }

  Future<void> _materialize(Map<String, dynamic> e) async {
    final kind = ItemKind.values.firstWhere(
      (k) => k.name == e['kind'],
      orElse: () => ItemKind.text,
    );
    final expiresAt = e['expiresAt'] != null
        ? DateTime.tryParse(e['expiresAt'] as String)
        : null;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
      return; // самоуничтожившееся сообщение — не материализуем
    }
    final remote = e['remotePath'] as String?;
    final encrypted = e['encrypted'] as bool? ?? false;
    String? filePath;
    // Избирательная синхронизация: медиа/файлы не тянем автоматически —
    // элемент появится в ленте с облачным remotePath, скачивание по тапу.
    final skipDownload =
        settings.selectiveSync && kind != ItemKind.text && remote != null;
    if (remote != null && !skipDownload) {
      var bytes = await _getFile(remote);
      if (bytes == null) return;
      if (encrypted) {
        try {
          bytes = await CryptoUtil.decrypt(bytes);
        } catch (err) {
          debugPrint('CloudSync decrypt failed: $err');
          return;
        }
      }
      final target = store.newFileFor(e['fileName'] as String? ?? 'file');
      await target.writeAsBytes(bytes);
      filePath = target.path;
    }
    await store.addRemote(
      SavedItem(
        id: e['id'] as String,
        kind: kind,
        text: e['text'] as String?,
        filePath: filePath,
        fileName: e['fileName'] as String?,
        fileSize: (e['fileSize'] as num?)?.toInt() ?? 0,
        mime: e['mime'] as String?,
        createdAt:
            DateTime.tryParse(e['createdAt'] as String? ?? '') ??
            DateTime.now(),
        outgoing: false,
        fromName: 'Аккаунт',
        pinned: e['pinned'] as bool? ?? false,
        group: e['group'] as String?,
        cloud: true,
        remotePath: remote,
        fileHash: e['fileHash'] as String?,
        encrypted: encrypted,
        expiresAt: expiresAt,
      ),
    );
  }

  /// Скачать содержимое элемента, который был пропущен избирательной
  /// синхронизацией (кнопка «Скачать» в UI).
  Future<bool> downloadNow(SavedItem item) async {
    if (item.remotePath == null || item.filePath != null) return false;
    try {
      var bytes = await _getFile(item.remotePath!);
      if (bytes == null) return false;
      if (item.encrypted) bytes = await CryptoUtil.decrypt(bytes);
      final target = store.newFileFor(item.fileName ?? 'file');
      await target.writeAsBytes(bytes);
      await store.updateFilePath(item, target.path);
      return true;
    } catch (e) {
      lastError = '$e';
      return false;
    }
  }

  // ── GitHub REST helpers ──
  Future<void> _ensureRepo() async {
    if (_repoReady) return;
    final get = await http.get(Uri.parse(_repoBase), headers: _headers);
    if (get.statusCode == 200) {
      _repoReady = true;
      return;
    }
    // Создаём приватный репозиторий.
    final create = await http.post(
      Uri.parse('$_api/user/repos'),
      headers: _headers,
      body: jsonEncode({
        'name': AuthConfig.storageRepo,
        'private': true,
        'auto_init': true,
        'description': 'TexFi files — личное облако (не трогать вручную)',
      }),
    );
    if (create.statusCode == 201 || create.statusCode == 422) {
      _repoReady = true;
    } else if (create.statusCode == 403 ||
        create.statusCode == 404 ||
        create.statusCode == 401) {
      // Токен без права repo — нужен повторный вход.
      needsReauth = true;
      lastError = 'Нужен повторный вход для доступа к облаку (право repo)';
      notifyListeners();
      throw Exception('repo scope missing (${create.statusCode})');
    } else {
      throw Exception('repo ${create.statusCode}: ${create.body}');
    }
  }

  /// Возвращает (список записей, sha индекса|null).
  Future<(List<Map<String, dynamic>>, String?)> _getIndex() async {
    final resp = await http.get(
      Uri.parse('$_repoBase/contents/$_indexPath'),
      headers: _headers,
    );
    if (resp.statusCode == 404) return (<Map<String, dynamic>>[], null);
    if (resp.statusCode != 200) {
      throw Exception('index ${resp.statusCode}');
    }
    final j = jsonDecode(resp.body) as Map<String, dynamic>;
    final sha = j['sha'] as String?;
    final content = (j['content'] as String? ?? '').replaceAll('\n', '');
    if (content.isEmpty) return (<Map<String, dynamic>>[], sha);
    final decoded = utf8.decode(base64.decode(content));
    final list = (jsonDecode(decoded) as List).cast<Map<String, dynamic>>();
    return (list, sha);
  }

  Future<void> _appendIndex(Map<String, dynamic> entry) => _lockIndex(() async {
    // 8 попыток с растущей задержкой — на случай, если параллельно пишет
    // ДРУГОЕ устройство того же аккаунта (наш собственный поток уже
    // сериализован _lockIndex).
    for (var attempt = 0; attempt < 8; attempt++) {
      final (list, sha) = await _getIndex();
      if (list.any((e) => e['id'] == entry['id'])) return; // уже есть
      list.add(entry);
      final content = base64.encode(utf8.encode(jsonEncode(list)));
      final resp = await http.put(
        Uri.parse('$_repoBase/contents/$_indexPath'),
        headers: _headers,
        body: jsonEncode({
          'message': 'add ${entry['id']}',
          'content': content,
          if (sha != null) 'sha': sha,
        }),
      );
      if (resp.statusCode == 200 || resp.statusCode == 201) return;
      if (resp.statusCode == 409 || resp.statusCode == 422) {
        await Future.delayed(Duration(milliseconds: 250 + attempt * 250));
        continue; // конфликт версий — перечитаем и повторим
      }
      throw Exception('index put ${resp.statusCode}: ${resp.body}');
    }
    throw Exception('index put: не удалось после повторов');
  });

  Future<void> _putFile(String path, List<int> bytes) async {
    final resp = await http.put(
      Uri.parse('$_repoBase/contents/$path'),
      headers: _headers,
      body: jsonEncode({
        'message': 'upload $path',
        'content': base64.encode(bytes),
      }),
    );
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception('file put ${resp.statusCode}: ${resp.body}');
    }
  }

  Future<List<int>?> _getFile(String path) async {
    // Для файлов до 100МБ contents API отдаёт base64; берём download_url.
    final resp = await http.get(
      Uri.parse('$_repoBase/contents/$path'),
      headers: _headers,
    );
    if (resp.statusCode != 200) return null;
    final j = jsonDecode(resp.body) as Map<String, dynamic>;
    final url = j['download_url'] as String?;
    if (url != null) {
      final f = await http.get(Uri.parse(url), headers: _headers);
      if (f.statusCode == 200) return f.bodyBytes;
    }
    final content = (j['content'] as String? ?? '').replaceAll('\n', '');
    if (content.isNotEmpty) return base64.decode(content);
    return null;
  }
}
