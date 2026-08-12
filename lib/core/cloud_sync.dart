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

  bool get available => auth.isLoggedIn && auth.token != null;
  String? get _owner => auth.account?.login;

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${auth.token}',
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'TexFi-files',
      };

  String get _repoBase =>
      '$_api/repos/$_owner/${AuthConfig.storageRepo}';

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
          final safe =
              (item.fileName ?? 'file').replaceAll(RegExp(r'[^\w.\-]'), '_');
          final remote = 'files/${hash.substring(0, 16)}__$safe';
          final toUpload =
              settings.encryptCloud ? await CryptoUtil.encrypt(raw) : raw;
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
      lastError = null;
    } catch (e) {
      lastError = '$e';
      debugPrint('CloudSync pull: $e');
    } finally {
      _busy = false;
      syncing = false;
      notifyListeners();
    }
  }

  Future<void> _materialize(Map<String, dynamic> e) async {
    final kind = ItemKind.values
        .firstWhere((k) => k.name == e['kind'], orElse: () => ItemKind.text);
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
    await store.addRemote(SavedItem(
      id: e['id'] as String,
      kind: kind,
      text: e['text'] as String?,
      filePath: filePath,
      fileName: e['fileName'] as String?,
      fileSize: (e['fileSize'] as num?)?.toInt() ?? 0,
      mime: e['mime'] as String?,
      createdAt:
          DateTime.tryParse(e['createdAt'] as String? ?? '') ?? DateTime.now(),
      outgoing: false,
      fromName: 'Аккаунт',
      pinned: e['pinned'] as bool? ?? false,
      group: e['group'] as String?,
      cloud: true,
      remotePath: remote,
      fileHash: e['fileHash'] as String?,
      encrypted: encrypted,
      expiresAt: expiresAt,
    ));
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
    final list = (jsonDecode(decoded) as List)
        .cast<Map<String, dynamic>>();
    return (list, sha);
  }

  Future<void> _appendIndex(Map<String, dynamic> entry) async {
    for (var attempt = 0; attempt < 4; attempt++) {
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
        await Future.delayed(const Duration(milliseconds: 400));
        continue; // конфликт версий — перечитаем и повторим
      }
      throw Exception('index put ${resp.statusCode}: ${resp.body}');
    }
    throw Exception('index put: не удалось после повторов');
  }

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
