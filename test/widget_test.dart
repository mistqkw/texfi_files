import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:texfi_files/ui/pixel/pixel_icons.dart';
import 'package:texfi_files/core/theme/app_theme.dart';
import 'package:texfi_files/ui/selection_paint.dart';
import 'package:texfi_files/ui/pixel/pixel_progress.dart';

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
        'send', 'mic', 'plus', 'close', 'check', 'back', 'chevron',
        'search', 'trash', 'copy', 'share', 'download', 'file', 'folder',
        'image', 'video', 'note', 'text', 'phone', 'laptop', 'device', 'star',
        'gear', 'wifi', 'shield', 'lock', 'globe', 'contrast', 'clock', 'qr',
        'warn', 'exchange', 'node', 'label', 'archive', 'pdf', 'code',
        'play', 'pause', 'next', 'prev', 'shuffle', 'repeat', 'repeatone',
        'rewind', 'forward', 'info',
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

  group('Полоса передачи', () {
    // Неопределённое состояние крутит бегущую волну, определённое — нет.
    // Ошибиться тут легко: контроллер, забытый в repeat(), тикает всё
    // время, пока виджет на экране.
    testWidgets('в неопределённом состоянии анимируется, в известном — нет',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 200, child: PixelProgress(value: null)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 200, child: PixelProgress(value: 0.4)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('строка передачи показывает округлённый процент',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: PixelTransferRow(title: 'holiday.zip', value: 0.426),
            ),
          ),
        ),
      );
      expect(find.text('holiday.zip'), findsOneWidget);
      expect(find.text('43%'), findsOneWidget);
    });
  });

  group('Иконка по типу файла', () {
    test('узнаваемые расширения получают свой глиф', () {
      expect(fileGlyphFor('backup.zip'), 'archive');
      expect(fileGlyphFor('manual.PDF'), 'pdf');
      expect(fileGlyphFor('main.dart'), 'code');
      expect(fileGlyphFor('notes.md'), 'text');
    });

    test('незнакомое и безымянное падают на общий лист', () {
      expect(fileGlyphFor('archive.bin'), 'file');
      expect(fileGlyphFor('без_расширения'), 'file');
      expect(fileGlyphFor(null), 'file');
    });

    test('каждый выбранный глиф есть в реестре', () {
      for (final name in const [
        'backup.zip', 'manual.pdf', 'main.dart', 'notes.md', 'x.bin',
      ]) {
        expect(PixelGlyphs.all.containsKey(fileGlyphFor(name)), isTrue);
      }
    });
  });

  group('Закраска выделения протяжкой', () {
    final ids = List.generate(10, (i) => 'id$i');

    test('закрашивает весь отрезок между замерами, а не одну строку', () {
      // Это и был баг «выделил много, а в папку добавилось несколько»:
      // события движения приходят раз в кадр, и строки между двумя
      // замерами пропускались.
      final selected = <String>{};
      applySelectionPaint(
        selected: selected,
        ids: ids,
        from: 2,
        to: 7,
        value: true,
      );
      expect(selected, {'id2', 'id3', 'id4', 'id5', 'id6', 'id7'});
    });

    test('направление протяжки не важно', () {
      final up = <String>{};
      final down = <String>{};
      applySelectionPaint(
          selected: up, ids: ids, from: 7, to: 2, value: true);
      applySelectionPaint(
          selected: down, ids: ids, from: 2, to: 7, value: true);
      expect(up, down);
    });

    test('снимает выделение тем же отрезком', () {
      final selected = {...ids};
      applySelectionPaint(
          selected: selected, ids: ids, from: 0, to: 4, value: false);
      expect(selected, {'id5', 'id6', 'id7', 'id8', 'id9'});
    });

    test('сообщает, изменилось ли что-нибудь', () {
      final selected = <String>{'id3'};
      expect(
        applySelectionPaint(
            selected: selected, ids: ids, from: 3, to: 3, value: true),
        isFalse,
        reason: 'повторная закраска той же строки ничего не меняет',
      );
      expect(
        applySelectionPaint(
            selected: selected, ids: ids, from: 3, to: 4, value: true),
        isTrue,
      );
    });

    test('индексы за пределами ленты обрезаются, а не роняют', () {
      final selected = <String>{};
      // Лента могла измениться между двумя замерами пальца.
      expect(
        applySelectionPaint(
            selected: selected, ids: ids, from: -5, to: 2, value: true),
        isTrue,
      );
      expect(selected, {'id0', 'id1', 'id2'});

      expect(
        applySelectionPaint(
            selected: selected, ids: ids, from: 50, to: 80, value: true),
        isFalse,
      );
      expect(
        applySelectionPaint(
            selected: selected, ids: const [], from: 0, to: 3, value: true),
        isFalse,
      );
    });
  });

  group('Пиксельный ползунок', () {
    // Кастомные SliderTrackShape/ComponentShape падают уже на отрисовке,
    // а живут они в настройках, куда в тестах не дойти иначе.
    testWidgets('рисуется в обеих темах и на краях диапазона',
        (tester) async {
      for (final brightness in Brightness.values) {
        for (final value in const [0.0, 0.5, 1.0]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.build(brightness: brightness),
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 240,
                    child: Slider(value: value, onChanged: (_) {}),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      }
    });

    testWidgets('ползунок нулевой ширины не роняет отрисовку',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(brightness: Brightness.dark),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 0,
                child: Slider(value: 0.5, onChanged: (_) {}),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
