import 'dart:io';

/// Кэш проверки «файл на месте».
///
/// `File.existsSync()` — синхронный системный вызов. В `build()` элемента
/// ленты он выполнялся для каждой картинки и каждого видео **на каждой
/// перерисовке**, а лента перерисовывается и на каждый кадр прокрутки
/// (`ListView.builder` пересобирает видимые элементы), и на каждое
/// уведомление store/discovery. Десяток медиа-сообщений на экране — десяток
/// обращений к диску за кадр; это и есть основной источник подтормаживаний
/// при скролле.
///
/// Результат живёт [_ttl] и затем перепроверяется: файл может исчезнуть
/// (очистка кеша, удаление из галереи), и залипший «да» оставил бы на
/// экране битую картинку навсегда. Виджеты всё равно рисуют
/// `errorBuilder`, так что окно неточности безопасно.
abstract final class FileCheck {
  static const Duration _ttl = Duration(seconds: 30);

  static final Map<String, _Entry> _cache = {};

  static bool exists(String? path) {
    if (path == null || path.isEmpty) return false;
    final now = DateTime.now();
    final hit = _cache[path];
    if (hit != null && now.difference(hit.at) < _ttl) return hit.value;
    final value = File(path).existsSync();
    _cache[path] = _Entry(value, now);
    // Кэш не должен расти бесконечно в длинной ленте: при переполнении
    // выбрасываем всё разом — это дешевле, чем поддерживать LRU ради
    // проверки, которая и так стоит один syscall.
    if (_cache.length > 512) {
      _cache.removeWhere((_, e) => now.difference(e.at) >= _ttl);
      if (_cache.length > 512) _cache.clear();
    }
    return value;
  }

  /// Сбросить запись — после удаления или сохранения файла, когда ждать
  /// истечения TTL не нужно.
  static void invalidate(String? path) {
    if (path != null) _cache.remove(path);
  }

  static void clear() => _cache.clear();
}

class _Entry {
  const _Entry(this.value, this.at);
  final bool value;
  final DateTime at;
}
