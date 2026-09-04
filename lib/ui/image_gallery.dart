import 'dart:io';
import 'package:flutter/material.dart';
import 'file_check.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../core/models.dart';
import '../l10n/app_strings.dart';

/// Просмотр изображений: свайпы между всеми картинками ленты, зум, а также
/// свайп вниз для закрытия (фон плавно затемняется/светлеет по ходу жеста).
class ImageGallery extends StatefulWidget {
  final List<SavedItem> images;
  final int initialIndex;
  const ImageGallery({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  State<ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<ImageGallery> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  // Вертикальное смещение при свайпе-вниз-для-закрытия и производная от него
  // прозрачность фона/хрома.
  double _dragDy = 0;
  bool _chromeVisible = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    setState(() => _dragDy += d.delta.dy);
  }

  void _onDragEnd(DragEndDetails d) {
    if (_dragDy.abs() > 120 || d.primaryVelocity != null && d.primaryVelocity!.abs() > 800) {
      Navigator.of(context).pop();
    } else {
      setState(() => _dragDy = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.images[_index];
    final t = tr(context);
    // Чем дальше утащили картинку вниз, тем прозрачнее фон — эффект «отрыва».
    final bgOpacity = (1 - (_dragDy.abs() / 400)).clamp(0.35, 1.0);

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: bgOpacity),
      extendBodyBehindAppBar: true,
      appBar: _chromeVisible
          ? AppBar(
              backgroundColor: Colors.black.withValues(alpha: 0.25),
              foregroundColor: Colors.white,
              elevation: 0,
              title: Text(
                '${_index + 1} / ${widget.images.length}',
                style: const TextStyle(fontSize: 15),
              ),
              actions: [
                IconButton(
                  tooltip: t.share,
                  icon: const Icon(Icons.ios_share_rounded),
                  onPressed: () => _shareCurrent(item),
                ),
                IconButton(
                  tooltip: t.open,
                  icon: const Icon(Icons.open_in_new_rounded),
                  onPressed: () {
                    if (item.filePath != null) OpenFilex.open(item.filePath!);
                  },
                ),
              ],
            )
          : null,
      body: GestureDetector(
        onTap: () => setState(() => _chromeVisible = !_chromeVisible),
        onVerticalDragUpdate: _onDragUpdate,
        onVerticalDragEnd: _onDragEnd,
        child: Transform.translate(
          offset: Offset(0, _dragDy),
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final path = widget.images[i].filePath;
              if (path == null || !FileCheck.exists(path)) {
                return const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 64,
                  ),
                );
              }
              return _ZoomableImage(path: path);
            },
          ),
        ),
      ),
      bottomNavigationBar: (_chromeVisible && item.fileName != null)
          ? Container(
              color: Colors.black.withValues(alpha: 0.25),
              padding: const EdgeInsets.only(bottom: 24, top: 10),
              child: Text(
                item.fileName!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            )
          : null,
    );
  }

  Future<void> _shareCurrent(SavedItem item) async {
    if (item.filePath == null) return;
    try {
      await Share.shareXFiles([XFile(item.filePath!)]);
    } catch (_) {}
  }
}

class _ZoomableImage extends StatefulWidget {
  final String path;
  const _ZoomableImage({required this.path});

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  final _tc = TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  // Двойной тап: если не увеличено — зумим в точку тапа ×2.5, иначе сброс.
  void _handleDoubleTap() {
    if (_tc.value != Matrix4.identity()) {
      _tc.value = Matrix4.identity();
    } else {
      final p = _doubleTapDetails!.localPosition;
      _tc.value = Matrix4.identity()
        ..translateByDouble(-p.dx * 1.5, -p.dy * 1.5, 0, 1)
        ..scaleByDouble(2.5, 2.5, 2.5, 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (d) => _doubleTapDetails = d,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _tc,
        minScale: 1,
        maxScale: 6,
        child: Center(
          child: Hero(
            tag: widget.path,
            child: Image.file(File(widget.path), fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
