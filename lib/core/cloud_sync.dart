import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_config.dart';
import 'auth_service.dart';
import 'models.dart';
import '../store/store.dart';

/// Облачное хранилище аккаунта на приватном GitHub-репозитории.
///
/// Гибрид: текст и файлы до [AuthConfig.cloudMaxBytes] уходят в репозиторий
/// (доступны с любого устройства/сети). Большие файлы остаются локальными.
class CloudSync extends ChangeNotifier {
  final AuthService auth;
  final Store store;
  CloudSync(this.auth, this.store);

  static const _indexPath = 'index.json';
  static const _api = 'https://api.github.com';

  Timer? _timer;
  bool _busy = false;
  bool _repoReady = false;
  String? lastError;
  bool syncing = false;

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
    try {
      await _ensureRepo();
      if (item.kind == ItemKind.text) {
        await _appendIndex(_entryOf(item));
        item.cloud = true;
        await store.persist();
      } else if (item.filePath != null &&
          item.fileSize > 0 &&
          item.fileSize <= AuthConfig.cloudMaxBytes) {
        final safe =
            (item.fileName ?? 'file').replaceAll(RegExp(r'[^\w.\-]'), '_');
        final remote = 'files/${item.id}__$safe';
        final bytes = await File(item.filePath!).readAsBytes();
        await _putFile(remote, bytes);
        item.remotePath = remote;
        await _appendIndex(_entryOf(item));
        item.cloud = true;
        await store.persist();
      }
      // Большие файлы не трогаем — остаются локальными.
      notifyListeners();
    } catch (e) {
      lastError = '$e';
      debugPrint('CloudSync push: $e');
    }
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
      };

  // ── Забрать ленту из облака ──
  Future<void> pull() async {
    if (_busy || !available) return;
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
    String? filePath;
    final remote = e['remotePath'] as String?;
    if (remote != null) {
      final bytes = await _getFile(remote);
      if (bytes == null) return;
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
    ));
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
