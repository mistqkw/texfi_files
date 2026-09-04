import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:texfi_files/ui/pixel/pixel_icons.dart';

void main() {
  group('Реестр пиксельных глифов', () {
    // Имена глифов — строки, поэтому опечатка в вызове не ловится
    // компилятором и молча рисует пустое место. Этот тест ловит обратную
    // ошибку: кривую сетку в самом реестре.
    // Единая сетка — то, за счёт чего набор выглядит нарисованным, а не
    // собранным из разных источников. Инвариант держится тестом, потому
    // что нарушить его правкой одной иконки слишком легко.
    test('весь интерфейсный набор — на сетке gridSize x gridSize', () {
      expect(PixelGlyphs.all, isNotEmpty);
      PixelGlyphs.all.forEach((name, rows) {
        expect(
          rows.length,
          PixelGlyphs.gridSize,
          reason: 'глиф $name: ${rows.length} строк вместо '
              '${PixelGlyphs.gridSize}',
        );
        for (final row in rows) {
          expect(
            row.length,
            PixelGlyphs.gridSize,
            reason: 'глиф $name: строка "$row" не той длины',
          );
        }
      });
    });

    test('крупный знак приложения — квадратный', () {
      expect(PixelGlyphs.mark, isNotEmpty);
      for (final row in PixelGlyphs.mark) {
        expect(row.length, PixelGlyphs.mark.length);
      }
    });

    test('интерфейсные глифы — одноцветные', () {
      // 'o' (светлая вставка) есть только у крупного знака: внутри иконки
      // размером 20px второй тон превращается в грязь.
      PixelGlyphs.all.forEach((name, rows) {
        for (final row in rows) {
          expect(
            RegExp(r'^[.#]+$').hasMatch(row),
            isTrue,
            reason: 'глиф $name: недопустимый символ в "$row"',
          );
        }
      });
    });

    test('иконки, на которые ссылается интерфейс, существуют', () {
      // Имена глифов — строки, поэтому опечатка не ловится компилятором и
      // молча рисует пустое место.
      const used = [
        'send', 'attach', 'mic', 'plus', 'close', 'check', 'back', 'chevron',
        'search', 'trash', 'copy', 'share', 'download', 'file', 'folder',
        'image', 'video', 'note', 'text', 'phone', 'laptop', 'device', 'star',
        'gear', 'wifi', 'shield', 'lock', 'globe', 'contrast', 'clock', 'qr',
        'warn', 'exchange', 'node',
      ];
      for (final name in used) {
        expect(
          PixelGlyphs.all.containsKey(name),
          isTrue,
          reason: 'глиф "$name" отсутствует в реестре',
        );
      }
    });
  });

  testWidgets('PixelIcon рисуется и занимает заданный размер', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: PixelIcon('mark', size: 48, color: Color(0xFF4A7DFB)),
        ),
      ),
    );
    expect(tester.getSize(find.byType(PixelIcon)), const Size(48, 48));
  });
}
