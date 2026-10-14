@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:texfi_files/core/theme/app_spacing.dart';
import 'package:texfi_files/core/theme/app_theme.dart';
import 'package:texfi_files/ui/hair/hair_button.dart';
import 'package:texfi_files/ui/hair/hair_card.dart';
import 'package:texfi_files/ui/hair/hair_controls.dart';
import 'package:texfi_files/ui/hair/hair_icons.dart';
import 'package:texfi_files/ui/hair/hair_progress.dart';
import 'package:texfi_files/ui/hair/hair_seekbar.dart';
import 'package:texfi_files/ui/hair/hair_wordmark.dart';
import 'package:texfi_files/core/theme/app_colors_ext.dart';

/// Витрина набора виджетов для визуальной проверки: `flutter test
/// test/goldens --update-goldens`, снимки лежат в `test/goldens/shots`.
Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
    }
    await loader.load();
  }

  await load('Unbounded', ['assets/fonts/Unbounded-SemiBold.ttf', 'assets/fonts/Unbounded-ExtraBold.ttf']);
  await load('JetBrainsMono', ['assets/fonts/JetBrainsMono-Medium.ttf']);
  await load('Inter', [
    'assets/fonts/Inter-Regular.ttf',
    'assets/fonts/Inter-Medium.ttf',
    'assets/fonts/Inter-SemiBold.ttf',
  ]);
  final root = Platform.environment['FLUTTER_ROOT'] ??
      '${Platform.environment['HOME']}/.local/share/flutter';
  final icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) await load('MaterialIcons', [icons.path]);
}

class _Kit extends StatelessWidget {
  const _Kit();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.screen,
          children: [
            const HairWordmark(size: 26, leading: 1.1),
            AppSpacing.gapLg,
            const HairSectionHeader(title: 'Устройства рядом'),
            HairTile(icon: 'laptop', title: 'Рабочий ноутбук', subtitle: '192.168.1.24', trailing: HairIcon('chevron', color: colors.textTertiary)),
            AppSpacing.gapSm,
            HairTile(icon: 'phone', title: 'Pixel 9a', subtitle: 'Только что', onTap: () {}),
            AppSpacing.gapLg,
            const HairCard(accent: true, child: _Transfer()),
            AppSpacing.gapLg,
            HairButton(label: 'Отправить файл', icon: 'send', onPressed: () {}),
            AppSpacing.gapSm,
            HairButton(label: 'Выбрать устройство', primary: false, onPressed: () {}),
            AppSpacing.gapLg,
            Row(
              children: [
                HairCheckbox(value: true, onChanged: (_) {}),
                AppSpacing.wGapLg,
                HairCheckbox(value: false, onChanged: (_) {}),
                AppSpacing.wGapLg,
                HairSwitch(value: true, onChanged: (_) {}),
                AppSpacing.wGapLg,
                HairSwitch(value: false, onChanged: (_) {}),
                AppSpacing.wGapLg,
                HairRadio(selected: true, onTap: () {}),
                AppSpacing.wGapMd,
                HairRadio(selected: false, onTap: () {}),
              ],
            ),
            AppSpacing.gapLg,
            HairSeekBar(position: const Duration(seconds: 70), duration: const Duration(minutes: 3), onSeek: (_) {}),
            AppSpacing.gapLg,
            const HairProgress(value: null),
            AppSpacing.gapLg,
            Row(
              children: [
                for (final n in ['mark', 'send', 'folder', 'qr', 'wifi', 'gear'])
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: HairIcon(n, size: n == 'mark' ? 40 : 24, color: colors.accent),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Transfer extends StatelessWidget {
  const _Transfer();

  @override
  Widget build(BuildContext context) =>
      const HairTransferRow(title: 'отпуск_2026.zip', value: 0.62);
}

void main() {
  setUpAll(_loadFonts);

  for (final b in [Brightness.dark, Brightness.light]) {
    testWidgets('kit ${b.name}', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(brightness: b),
        home: const _Kit(),
      ));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/kit_${b.name}.png'));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
