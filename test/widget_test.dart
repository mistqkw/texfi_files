import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:texfi_files/ui/pixel/pixel_icons.dart';

/// Иконки адресуются строкой (`PixelIcon('search')`), поэтому опечатка в
/// имени не ломает сборку — виджет молча рисует запасной квадрат, и это
/// замечаешь только глазами на конкретном экране. Тест проходит по всем
/// вызовам в исходниках и проверяет, что каждое имя есть в реестре.
void main() {
  test('every PixelIcon name used in lib/ exists in the registry', () {
    final dir = Directory('lib');
    expect(dir.existsSync(), isTrue, reason: 'запускать из корня проекта');

    final call = RegExp(r"""PixelIcon\(\s*'([^']+)'""");
    final missing = <String>{};
    var checked = 0;

    for (final f in dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      for (final m in call.allMatches(f.readAsStringSync())) {
        final name = m.group(1)!;
        checked++;
        if (PixelIcons.byName(name) == null) {
          missing.add('$name (${f.path})');
        }
      }
    }

    expect(checked, greaterThan(0), reason: 'вызовы PixelIcon не найдены');
    expect(missing, isEmpty, reason: 'нет таких иконок в реестре: $missing');
  });

  test('every glyph is a 12x12 grid of . and #', () {
    // Painter рисует ровно 12x12; более короткая строка молча обрежет
    // рисунок, более длинная — потеряет правый край.
    for (final name in PixelIcons.names) {
      final glyph = PixelIcons.byName(name)!;
      expect(glyph.rows.length, 12, reason: '$name: строк != 12');
      for (final row in glyph.rows) {
        expect(row.length, 12, reason: '$name: длина строки != 12 ("$row")');
        expect(RegExp(r'^[.#]+$').hasMatch(row), isTrue,
            reason: '$name: недопустимые символы в "$row"');
      }
    }
  });
}
