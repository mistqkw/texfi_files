import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import '../core/models.dart';

/// Просмотр изображений: свайпы между всеми картинками ленты + зум.
class ImageGallery extends StatefulWidget {
  final List<SavedItem> images;
  final int initialIndex;
  const ImageGallery(
      {super.key, required this.images, required this.initialIndex});

  @override
  State<ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<ImageGallery> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.images[_index];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_index + 1} / ${widget.images.length}',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: () {
              if (item.filePath != null) OpenFilex.open(item.filePath!);
            },
          ),
        ],
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) {
          final path = widget.images[i].filePath;
          if (path == null || !File(path).existsSync()) {
            return const Center(
              child: Icon(Icons.broken_image_outlined,
                  color: Colors.white54, size: 64),
            );
          }
          return _ZoomableImage(path: path);
        },
      ),
      bottomNavigationBar: item.fileName != null
          ? Container(
              color: Colors.black,
              padding: const EdgeInsets.only(bottom: 20, top: 8),
              child: Text(
                item.fileName!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            )
          : null,
    );
  }
}

class _ZoomableImage extends StatelessWidget {
  final String path;
  const _ZoomableImage({required this.path});

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 1,
      maxScale: 6,
      child: Center(
        child: Hero(
          tag: path,
          child: Image.file(File(path), fit: BoxFit.contain),
        ),
      ),
    );
  }
}
