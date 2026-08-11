import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../core/models.dart';
import 'format.dart';

/// Превью видео: на Android/iOS показывает кадр из видео с кнопкой play,
/// на десктопе — аккуратную плашку (генерация кадра там недоступна).
class VideoThumb extends StatefulWidget {
  final SavedItem item;
  final VoidCallback onOpen;
  const VideoThumb({super.key, required this.item, required this.onOpen});

  @override
  State<VideoThumb> createState() => _VideoThumbState();
}

class _VideoThumbState extends State<VideoThumb> {
  String? _thumbPath;
  bool _tried = false;

  bool get _canThumb => Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();
    if (_canThumb) _generate();
  }

  Future<void> _generate() async {
    final path = widget.item.filePath;
    if (path == null || !File(path).existsSync()) return;
    try {
      final dir = await getTemporaryDirectory();
      final out = '${dir.path}/thumb_${widget.item.id}.jpg';
      if (File(out).existsSync()) {
        if (mounted) setState(() => _thumbPath = out);
        return;
      }
      final res = await VideoThumbnail.thumbnailFile(
        video: path,
        thumbnailPath: out,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 400,
        quality: 70,
      );
      if (mounted) setState(() => _thumbPath = res);
    } catch (_) {
      if (mounted) setState(() => _tried = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_thumbPath != null && File(_thumbPath!).existsSync()) {
      return GestureDetector(
        onTap: widget.onOpen,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: Image.file(File(_thumbPath!), fit: BoxFit.cover),
            ),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 34),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(humanSize(widget.item.fileSize),
                    style:
                        const TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ),
          ],
        ),
      );
    }
    // Фолбэк-плашка (десктоп или пока превью не готово).
    return InkWell(
      onTap: widget.onOpen,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [cs.primary, cs.tertiary]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.play_arrow_rounded,
                  color: cs.onPrimary, size: 30),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.item.fileName ?? 'Video',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(humanSize(widget.item.fileSize),
                      style:
                          TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
