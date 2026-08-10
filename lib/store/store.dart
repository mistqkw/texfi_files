import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../core/models.dart';

/// Персистентное хранилище ленты «Избранное».
/// Индекс — JSON-файл, полученные файлы лежат в подпапке files/.
class Store extends ChangeNotifier {
  final List<SavedItem> _items = [];
  late final Directory _root;
  late final Directory _filesDir;
  late final File _index;
  bool _ready = false;

  List<SavedItem> get items => List.unmodifiable(_items.reversed);
  bool get ready => _ready;
  Directory get filesDir => _filesDir;

  Future<void> init() async {
    final base = await getApplicationSupportDirectory();
    _root = Directory('${base.path}/texfi');
    _filesDir = Directory('${_root.path}/files');
    if (!_filesDir.existsSync()) _filesDir.createSync(recursive: true);
    _index = File('${_root.path}/index.json');
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
    _ready = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    await _index.writeAsString(SavedItem.listToJson(_items));
  }

  Future<void> add(SavedItem item) async {
    _items.add(item);
    notifyListeners();
    await _persist();
  }

  Future<void> remove(SavedItem item) async {
    _items.removeWhere((e) => e.id == item.id);
    notifyListeners();
    // Удаляем локальный файл, если он в нашей папке.
    if (item.filePath != null && item.filePath!.startsWith(_filesDir.path)) {
      try {
        final f = File(item.filePath!);
        if (f.existsSync()) await f.delete();
      } catch (_) {}
    }
    await _persist();
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
