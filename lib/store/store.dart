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

  /// Лента от новых к старым.
  ///
  /// Раньше здесь на каждом обращении собирался новый список
  /// (`List.unmodifiable(_items.reversed)`), а главный экран обращается к
  /// нему несколько раз за перерисовку — и сам перерисовывается на каждое
  /// уведомление store и discovery. Теперь список собирается один раз после
  /// изменения и переиспользуется.
  List<SavedItem>? _view;

  List<SavedItem> get items =>
      _view ??= List.unmodifiable(_items.reversed);

  /// Сбрасывает кэш ленты. Вызывается из [_touch] вместе с уведомлением,
  /// чтобы порядок «сначала инвалидировать, потом уведомить» нельзя было
  /// перепутать в одном из полутора десятка мест, где меняется список.
  /// Та же лента в хронологическом порядке (старые сверху) — в этом виде
  /// её рисует главный экран.
  ///
  /// Отдельный кэш вместо `items.reversed` на месте: экран разворачивал уже
  /// развёрнутый список на каждой перерисовке, то есть делал двойную работу
  /// ради исходного порядка.
  List<SavedItem>? _chronological;

  List<SavedItem> get itemsChronological =>
      _chronological ??= List.unmodifiable(_items);

  void _invalidate() {
    _view = null;
    _chronological = null;
  }

  /// Инвалидация + уведомление одним вызовом.
  void _touch() {
    _invalidate();
    super.notifyListeners();
  }
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
    _touch();
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
    _touch();
  }

  /// Обновить прогресс приёма (вызывается часто — без записи на диск).
  void updateReceivedBytes(SavedItem item, int bytes) {
    item.fileSize = bytes;
    _touch();
  }

  /// Приём завершён: фиксируем размер, персистим и запускаем облачную синхронизацию.
  Future<void> finishReceiving(SavedItem item, int finalSize) async {
    item.receiving = false;
    item.fileSize = finalSize;
    _touch();
    await _persist();
    onItemAdded?.call(item);
  }

  /// Приём прервался — убираем плейсхолдер из ленты.
  Future<void> cancelReceiving(SavedItem item) async {
    _items.removeWhere((e) => e.id == item.id);
    _touch();
  }

  Future<void> add(SavedItem item) async {
    _items.add(item);
    _touch();
    await _persist();
    onItemAdded?.call(item);
  }

  /// Добавить элемент, пришедший из облака (без повторной отправки в облако).
  Future<void> addRemote(SavedItem item) async {
    if (has(item.id) || _tombstones.contains(item.id)) return;
    _items.add(item);
    _items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _touch();
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
    _touch();
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
    _touch();
    await _persist();
    onItemChanged?.call(item);
  }

  /// После отложенной загрузки (избирательная синхронизация) — проставить
  /// локальный путь скачанного файла.
  Future<void> updateFilePath(SavedItem item, String path) async {
    item.filePath = path;
    _touch();
    await _persist();
  }

  Future<void> toggleArchive(SavedItem item) async {
    item.archived = !item.archived;
    _touch();
    await _persist();
    onItemChanged?.call(item);
  }

  Future<void> setGroup(SavedItem item, String? group) async {
    item.group = (group != null && group.trim().isEmpty) ? null : group?.trim();
    _touch();
    await _persist();
    onItemChanged?.call(item);
  }

  /// Переложить сразу несколько элементов в папку (или вынуть из неё).
  ///
  /// Отдельно от [setGroup] ради одной записи на диск и одного уведомления
  /// на всю пачку: при выделении из полусотни элементов поштучный вызов
  /// означал бы полсотни перезаписей индекса.
  Future<void> setGroupAll(Iterable<SavedItem> items, String? group) async {
    final value = (group != null && group.trim().isEmpty) ? null : group?.trim();
    var changed = false;
    for (final item in items) {
      if (item.group == value) continue;
      item.group = value;
      changed = true;
    }
    if (!changed) return;
    _touch();
    await _persist();
    for (final item in items) {
      onItemChanged?.call(item);
    }
  }

  /// Поставить или снять метку.
  Future<void> toggleLabel(SavedItem item, String label) async {
    final tag = label.trim();
    if (tag.isEmpty) return;
    if (!item.labels.remove(tag)) item.labels.add(tag);
    _touch();
    await _persist();
    onItemChanged?.call(item);
  }

  /// Поставить метку сразу на несколько элементов.
  ///
  /// Если метка уже стоит у всех выделенных — снимаем её. Так одна и та же
  /// кнопка и ставит, и снимает, и результат предсказуем.
  Future<void> toggleLabelAll(Iterable<SavedItem> items, String label) async {
    final tag = label.trim();
    if (tag.isEmpty) return;
    final list = items.toList();
    if (list.isEmpty) return;
    final everyone = list.every((e) => e.labels.contains(tag));
    for (final item in list) {
      if (everyone) {
        item.labels.remove(tag);
      } else {
        item.labels.add(tag);
      }
    }
    _touch();
    await _persist();
    for (final item in list) {
      onItemChanged?.call(item);
    }
  }

  /// Удалить сразу несколько элементов.
  Future<void> removeAll(Iterable<SavedItem> items) async {
    for (final item in items.toList()) {
      await remove(item);
    }
  }

  /// Все метки, встречающиеся в ленте (по алфавиту).
  List<String> get labels {
    final set = <String>{};
    for (final it in _items) {
      set.addAll(it.labels);
    }
    final list = set.toList()..sort();
    return list;
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
    _touch();
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
    _touch();
    await _persist();
    return true;
  }

  Future<void> clearAll() async {
    _items.clear();
    _touch();
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
