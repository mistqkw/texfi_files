import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Чтение обложки в фоновом изоляте — теги парсятся синхронно и на UI-потоке
/// давали заметные фризы при скролле списка треков.
Uint8List? _readArtInIsolate(String path) {
  try {
    final f = File(path);
    if (!f.existsSync()) return null;
    final meta = readMetadata(f, getImage: true);
    if (meta.pictures.isNotEmpty) return meta.pictures.first.bytes;
  } catch (_) {}
  return null;
}

/// Обложка аудиотрека из тегов файла. Результат кэшируется по пути; чтение
/// идёт в фоновом изоляте, одинаковые запросы дедуплицируются, чтобы список
/// не парсил один и тот же файл несколько раз одновременно.
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
  static final Map<String, Future<Uint8List?>> _inFlight = {};

  static Future<Uint8List?> _artFor(String path) {
    if (_cache.containsKey(path)) return Future.value(_cache[path]);
    return _inFlight.putIfAbsent(path, () async {
      final bytes = await compute(_readArtInIsolate, path);
      _cache[path] = bytes;
      _inFlight.remove(path);
      return bytes;
    });
  }

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
    final bytes = await AlbumArtThumb._artFor(path);
    if (mounted && path == widget.filePath) setState(() => _art = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final art = _art;
    if (art == null) return widget.fallback;
    // cacheWidth — декодируем под фактический размер миниатюры (×2 под DPR),
    // а не полноразмерную обложку: меньше памяти и быстрее первый кадр.
    final decodeW = (widget.size * MediaQuery.devicePixelRatioOf(context))
        .round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: Image.memory(
        art,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        cacheWidth: decodeW,
        errorBuilder: (_, __, ___) => widget.fallback,
      ),
    );
  }
}
