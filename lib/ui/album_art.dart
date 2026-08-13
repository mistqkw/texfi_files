import 'dart:io';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';

/// Обложка аудиотрека из тегов файла. Результат кэшируется по пути,
/// чтобы не перечитывать метаданные при каждой перестройке ленты.
class AlbumArtThumb extends StatefulWidget {
  final String? filePath;
  final double size;
  final double radius;

  /// Заглушка, если обложки нет.
  final Widget fallback;

  const AlbumArtThumb({
    super.key,
    required this.filePath,
    required this.fallback,
    this.size = 52,
    this.radius = 3,
  });

  static final Map<String, Uint8List?> _cache = {};

  @override
  State<AlbumArtThumb> createState() => _AlbumArtThumbState();
}

class _AlbumArtThumbState extends State<AlbumArtThumb> {
  Uint8List? _art;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(AlbumArtThumb old) {
    super.didUpdateWidget(old);
    if (old.filePath != widget.filePath) _load();
  }

  Future<void> _load() async {
    final path = widget.filePath;
    if (path == null) return;
    if (AlbumArtThumb._cache.containsKey(path)) {
      setState(() => _art = AlbumArtThumb._cache[path]);
      return;
    }
    Uint8List? bytes;
    try {
      // Чтение тегов синхронное, поэтому уводим его с первого кадра.
      await Future<void>.delayed(Duration.zero);
      final f = File(path);
      if (f.existsSync()) {
        final meta = readMetadata(f, getImage: true);
        if (meta.pictures.isNotEmpty) bytes = meta.pictures.first.bytes;
      }
    } catch (_) {
      // нет метаданных — останется заглушка
    }
    AlbumArtThumb._cache[path] = bytes;
    if (mounted) setState(() => _art = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final art = _art;
    if (art == null) return widget.fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: Image.memory(
        art,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => widget.fallback,
      ),
    );
  }
}
