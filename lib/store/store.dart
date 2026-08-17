import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../core/models.dart';

/// Персистентное хранилище ленты «Избранное».
/// Индекс — JSON-файл, полученные файлы лежат в подпапке files/.
class Store extends ChangeNotifier {
  final List<SavedItem> _items = [];
  final Set<String> _tombstones = {};
  late final Directory _root;
  late final Directory _filesDir;
  late final File _index;
  late final File _tombstoneFile;
  bool _ready = false;

  List<SavedItem> get items => List.unmodifiable(_items.reversed);
  bool get ready => _ready;
  Directory get filesDir => _filesDir;

  /// Вызывается при локальном добавлении (для отправки в облако).
  void Function(SavedItem item)? onItemAdded;

  /// Вызывается при удалении элемента, который был в облаке (для удаления
  /// записи из общего индекса аккаунта).
  void Function(SavedItem item)? onItemRemoved;

  /// Вызывается при изменении метаданных элемента (пин/архив/группа), чтобы
  /// отправить обновление в общий облачный индекс — без этого такие
  /// изменения оставались только локальными и не появлялись на других
  /// устройствах того же аккаунта.
  void Function(SavedItem item)? onItemChanged;

  bool has(String id) => _items.any((e) => e.id == id);

  SavedItem? byId(String id) {
    for (final it in _items) {
      if (it.id == id) return it;
    }
    return null;
  }

  /// Был ли элемент с таким id удалён (чтобы не воскрешать его из облака).
  bool isDeleted(String id) => _tombstones.contains(id);

  Future<void> init() async {
    final base = await getApplicationSupportDirectory();
    _root = Directory('${base.path}/texfi');
    _filesDir = Directory('${_root.path}/files');
    if (!_filesDir.existsSync()) _filesDir.createSync(recursive: true);
    _index = File('${_root.path}/index.json');
    _tombstoneFile = File('${_root.path}/deleted.json');
    if (_index.existsSync()) {
      try {
        _items
          ..clear()
          ..addAll(SavedItem.listFromJson(await _index.readAsString()));
        _items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      } catch (e) {
        debugPrint('Store: не смог прочитать индекс: $e');
      }
    }
    if (_tombstoneFile.existsSync()) {
      try {
        final list = (jsonDecode(await _tombstoneFile.readAsString()) as List)
            .cast<String>();
        _tombstones
          ..clear()
          ..addAll(list);
      } catch (e) {
        debugPrint('Store: не смог прочитать deleted.json: $e');
      }
    }
    _ready = true;
    notifyListeners();
  }

  Future<void> _persistTombstones() =>
      _tombstoneFile.writeAsString(jsonEncode(_tombstones.toList()));

  Future<void> _persist() async {
    await _index.writeAsString(SavedItem.listToJson(_items));
  }

  /// Добавить «в процессе приёма» плейсхолдер — не персистится и не уходит
  /// в облако, пока приём не завершится (см. [finishReceiving]).
  Future<void> addReceiving(SavedItem item) async {
    _items.add(item);
    notifyListeners();
  }

  /// Обновить прогресс приёма (вызывается часто — без записи на диск).
  void updateReceivedBytes(SavedItem item, int bytes) {
    item.fileSize = bytes;
    notifyListeners();
  }

  /// Приём завершён: фиксируем размер, персистим и запускаем облачную синхронизацию.
  Future<void> finishReceiving(SavedItem item, int finalSize) async {
    item.receiving = false;
    item.fileSize = finalSize;
    notifyListeners();
    await _persist();
    onItemAdded?.call(item);
  }

  /// Приём прервался — убираем плейсхолдер из ленты.
  Future<void> cancelReceiving(SavedItem item) async {
    _items.removeWhere((e) => e.id == item.id);
    notifyListeners();
  }

  Future<void> add(SavedItem item) async {
    _items.add(item);
    notifyListeners();
    await _persist();
    onItemAdded?.call(item);
  }

  /// Добавить элемент, пришедший из облака (без повторной отправки в облако).
  Future<void> addRemote(SavedItem item) async {
    if (has(item.id) || _tombstones.contains(item.id)) return;
    _items.add(item);
    _items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    notifyListeners();
    await _persist();
  }

  /// Сохранить изменения (например, после пометки cloud=true).
  Future<void> persist() => _persist();

  /// Удалить элемент. [notifyCloud] управляет тем, будет ли вызван
  /// [onItemRemoved] (отключается при удалении, пришедшем уже из облака,
  /// чтобы не слать в GitHub лишний запрос на то, что там уже удалено).
  Future<void> remove(SavedItem item, {bool notifyCloud = true}) async {
    _items.removeWhere((e) => e.id == item.id);
    if (item.cloud) {
      // Ставим «надгробие», чтобы ближайший periodic pull() из облака
      // (индекс ещё может содержать запись, пока идёт запрос на удаление)
      // не воскресил только что удалённый элемент обратно в ленту.
      _tombstones.add(item.id);
      await _persistTombstones();
    }
    notifyListeners();
    // Удаляем локальный файл, если он в нашей папке.
    if (item.filePath != null && item.filePath!.startsWith(_filesDir.path)) {
      try {
        final f = File(item.filePath!);
        if (f.existsSync()) await f.delete();
      } catch (_) {}
    }
    await _persist();
    if (notifyCloud && item.cloud) onItemRemoved?.call(item);
  }

  Future<void> togglePin(SavedItem item) async {
    item.pinned = !item.pinned;
    notifyListeners();
    await _persist();
    onItemChanged?.call(item);
  }

  /// После отложенной загрузки (избирательная синхронизация) — проставить
  /// локальный путь скачанного файла.
  Future<void> updateFilePath(SavedItem item, String path) async {
    item.filePath = path;
    notifyListeners();
    await _persist();
  }

  Future<void> toggleArchive(SavedItem item) async {
    item.archived = !item.archived;
    notifyListeners();
    await _persist();
    onItemChanged?.call(item);
  }

  Future<void> setGroup(SavedItem item, String? group) async {
    item.group = (group != null && group.trim().isEmpty) ? null : group?.trim();
    notifyListeners();
    await _persist();
    onItemChanged?.call(item);
  }

  /// Применяет пин/архив/группу, пришедшие из общего облачного индекса с
  /// другого устройства, к уже существующему локальному элементу. Отдельно
  /// от toggle*/setGroup, чтобы не вызывать onItemChanged и не зациклить
  /// pull() → updateMeta() → pull() между устройствами.
  Future<void> applyRemoteMeta(
    SavedItem item, {
    required bool pinned,
    required bool archived,
    required String? group,
  }) async {
    if (item.pinned == pinned &&
        item.archived == archived &&
        item.group == group) {
      return;
    }
    item.pinned = pinned;
    item.archived = archived;
    item.group = group;
    notifyListeners();
    await _persist();
  }

  /// Список всех групп (по алфавиту).
  List<String> get groups {
    final set = <String>{};
    for (final it in _items) {
      if (it.group != null && it.group!.isNotEmpty) set.add(it.group!);
    }
    final list = set.toList()..sort();
    return list;
  }

  /// Удаляет элементы с истёкшим TTL (самоуничтожение). Возвращает, были ли
  /// изменения (чтобы вызывающий мог не персистить впустую).
  Future<bool> purgeExpired() async {
    final now = DateTime.now();
    final expired = _items
        .where((e) => e.expiresAt != null && now.isAfter(e.expiresAt!))
        .toList();
    if (expired.isEmpty) return false;
    for (final e in expired) {
      _items.remove(e);
      if (e.filePath != null && e.filePath!.startsWith(_filesDir.path)) {
        try {
          final f = File(e.filePath!);
          if (f.existsSync()) await f.delete();
        } catch (_) {}
      }
    }
    notifyListeners();
    await _persist();
    return true;
  }

  Future<void> clearAll() async {
    _items.clear();
    notifyListeners();
    try {
      if (_filesDir.existsSync()) {
        for (final f in _filesDir.listSync()) {
          f.deleteSync(recursive: true);
        }
      }
    } catch (_) {}
    await _persist();
  }

  /// Уникальный путь под входящий файл, чтобы не перетирать одноимённые.
  File newFileFor(String name) {
    final safe = name.replaceAll(RegExp(r'[/\\]'), '_');
    var target = File('${_filesDir.path}/$safe');
    var i = 1;
    while (target.existsSync()) {
      final dot = safe.lastIndexOf('.');
      final base = dot > 0 ? safe.substring(0, dot) : safe;
      final ext = dot > 0 ? safe.substring(dot) : '';
      target = File('${_filesDir.path}/${base}_$i$ext');
      i++;
    }
    return target;
  }
}
