import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/haptics.dart';
import '../../core/theme/app_colors_ext.dart';

/// Линейные иконки интерфейса (дизайн «hairline»): тонкий контур без
/// заливок, штрих 300. Иконка выбирается по имени — те же имена, что
/// использует остальной код.
abstract final class HairGlyphs {
  static const Map<String, IconData> all = {
    'send': Icons.send_rounded,
    'mic': Icons.mic_none_rounded,
    'plus': Icons.add_rounded,
    'close': Icons.close_rounded,
    'check': Icons.check_rounded,
    'back': Icons.arrow_back_rounded,
    'chevron': Icons.chevron_right_rounded,
    'search': Icons.search_rounded,
    'trash': Icons.delete_outline_rounded,
    'copy': Icons.content_copy_rounded,
    'share': Icons.ios_share_rounded,
    'download': Icons.file_download_outlined,
    'label': Icons.label_outline_rounded,
    'archive': Icons.inventory_2_outlined,
    'pdf': Icons.picture_as_pdf_outlined,
    'code': Icons.code_rounded,
    'file': Icons.insert_drive_file_outlined,
    'folder': Icons.folder_outlined,
    'image': Icons.image_outlined,
    'video': Icons.videocam_outlined,
    'play': Icons.play_arrow_rounded,
    'pause': Icons.pause_rounded,
    'next': Icons.skip_next_rounded,
    'prev': Icons.skip_previous_rounded,
    'shuffle': Icons.shuffle_rounded,
    'repeat': Icons.repeat_rounded,
    'repeatone': Icons.repeat_one_rounded,
    'rewind': Icons.fast_rewind_rounded,
    'forward': Icons.fast_forward_rounded,
    'info': Icons.info_outline_rounded,
    'note': Icons.sticky_note_2_outlined,
    'text': Icons.notes_rounded,
    'phone': Icons.smartphone_rounded,
    'laptop': Icons.laptop_mac_rounded,
    'device': Icons.devices_rounded,
    'star': Icons.star_outline_rounded,
    'gear': Icons.tune_rounded,
    'wifi': Icons.wifi_rounded,
    'shield': Icons.shield_outlined,
    'lock': Icons.lock_outline_rounded,
    'globe': Icons.language_rounded,
    'contrast': Icons.contrast_rounded,
    'clock': Icons.schedule_rounded,
    'qr': Icons.qr_code_2_rounded,
    'warn': Icons.warning_amber_rounded,
    'exchange': Icons.swap_horiz_rounded,
  };
}

/// Иконка по имени из [HairGlyphs.all]; `'node'` и `'mark'` — знак
/// приложения (P2P-узел), нарисованный линиями.
class HairIcon extends StatelessWidget {
  const HairIcon(
    this.name, {
    super.key,
    this.size = 20,
    required this.color,
  });

  final String name;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (name == 'node' || name == 'mark') {
      return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: HairMarkPainter(color: color, progress: 1)),
      );
    }
    final icon = HairGlyphs.all[name];
    assert(icon != null, 'Неизвестная иконка: $name');
    return Icon(icon ?? Icons.help_outline_rounded, size: size, color: color, weight: 300);
  }
}

/// Знак приложения: четыре узла по углам, соединённые через центр.
/// [progress] 0..1 прорисовывает линии и узлы по очереди — на заставке.
class HairMarkPainter extends CustomPainter {
  const HairMarkPainter({required this.color, required this.progress, this.stroke});

  final Color color;
  final double progress;

  /// Толщина линии; по умолчанию зависит от размера, но не тоньше 1.2.
  final double? stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final w = stroke ?? math.max(1.2, s / 40);
    final r = s * 0.12;
    final inset = r + w;
    final c = Offset(size.width / 2, size.height / 2);
    final corners = [
      Offset(inset, inset),
      Offset(size.width - inset, inset),
      Offset(inset, size.height - inset),
      Offset(size.width - inset, size.height - inset),
    ];
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..color = color;

    final lines = Curves.easeOutCubic.transform((progress / 0.7).clamp(0.0, 1.0));
    for (final p in corners) {
      final dir = c - p;
      final dist = dir.distance;
      final unit = dir / dist;
      final from = p + unit * r;
      final to = c - unit * (r * 0.9);
      canvas.drawLine(from, Offset.lerp(from, to, lines)!, line);
    }

    final nodes = Curves.easeOutBack.transform(((progress - 0.15) / 0.55).clamp(0.0, 1.0));
    for (final p in corners) {
      canvas.drawCircle(p, r * nodes, line);
    }
    final core = Curves.easeOutBack.transform(((progress - 0.4) / 0.6).clamp(0.0, 1.0));
    canvas.drawCircle(c, r * 0.9 * core, line);
    if (core > 0.5) {
      canvas.drawCircle(c, r * 0.35 * core, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(HairMarkPainter old) =>
      old.progress != progress || old.color != color || old.stroke != stroke;
}

/// Кнопка-иконка с линейным глифом.
class HairIconButton extends StatelessWidget {
  const HairIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 20,
    this.color,
    this.tooltip,
  });

  final String icon;
  final VoidCallback? onPressed;
  final double size;
  final Color? color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final c = color ?? colors.textPrimary;
    final button = GestureDetector(
      onTap: onPressed == null
          ? null
          : () {
              Haptics.tap();
              onPressed!();
            },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        // 44x44 минимальная зона нажатия при иконке 20px.
        padding: const EdgeInsets.all(12),
        child: HairIcon(
          icon,
          size: size,
          color: onPressed == null ? colors.textTertiary : c,
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Иконка для файла по его имени: у узнаваемого типа вместо безликого
/// листа появляется своя. Картинки, звук и видео сюда не попадают — у них
/// свой тип и превью.
String fileGlyphFor(String? fileName) {
  final name = (fileName ?? '').toLowerCase();
  final ext = name.contains('.') ? name.split('.').last : '';
  const archive = {'zip', 'rar', '7z', 'tar', 'gz', 'xz', 'zst', 'apk', 'iso'};
  const document = {'pdf', 'doc', 'docx', 'odt', 'rtf', 'epub', 'djvu'};
  const code = {
    'dart', 'py', 'js', 'ts', 'json', 'yaml', 'yml', 'sh', 'c', 'h', 'cpp',
    'rs', 'go', 'java', 'kt', 'xml', 'html', 'css', 'toml', 'ini', 'conf',
  };
  if (archive.contains(ext)) return 'archive';
  if (document.contains(ext)) return 'pdf';
  if (code.contains(ext)) return 'code';
  if (ext == 'txt' || ext == 'md' || ext == 'log') return 'text';
  return 'file';
}
