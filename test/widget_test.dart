import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:texfi_files/ui/pixel/pixel_icons.dart';

void main() {
  group('Реестр пиксельных глифов', () {
    // Имена глифов — строки, поэтому опечатка в вызове не ловится
    // компилятором и молча рисует пустое место. Этот тест ловит обратную
    // ошибку: кривую сетку в самом реестре.
    test('каждый глиф — квадратная сетка из строк одинаковой длины', () {
      expect(PixelGlyphs.all, isNotEmpty);
      PixelGlyphs.all.forEach((name, rows) {
        expect(rows, isNotEmpty, reason: 'глиф $name пуст');
        final width = rows.first.length;
        for (final row in rows) {
          expect(
            row.length,
            width,
            reason: 'глиф $name: строка "$row" не совпадает по длине',
          );
        }
        expect(
          rows.length,
          width,
          reason: 'глиф $name не квадратный: ${rows.length}x$width',
        );
      });
    });

    test('в сетке только символы ".", "#" и "o"', () {
      PixelGlyphs.all.forEach((name, rows) {
        for (final row in rows) {
          expect(
            RegExp(r'^[.#o]+$').hasMatch(row),
            isTrue,
            reason: 'глиф $name: недопустимый символ в "$row"',
          );
        }
      });
    });

    test('символ приложения на месте', () {
      expect(PixelGlyphs.all.containsKey('node'), isTrue);
    });
  });

  testWidgets('PixelIcon рисуется и занимает заданный размер', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: PixelIcon('node', size: 48, color: Color(0xFF4A7DFB)),
        ),
      ),
    );
    expect(tester.getSize(find.byType(PixelIcon)), const Size(48, 48));
  });
}
