import 'dart:async';
import 'dart:io';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'models.dart';

/// Глобальный аудио-плеер: один на всё приложение, чтобы работал мини-плеер
/// и музыка не останавливалась при уходе с экрана.
class PlayerService extends ChangeNotifier {
  final Player _player = Player();
  final List<StreamSubscription> _subs = [];

  SavedItem? current;
  Duration pos = Duration.zero;
  Duration dur = Duration.zero;
  bool playing = false;
  Uint8List? art;
  String? title;
  String? artist;

  Player get raw => _player;

  PlayerService() {
    _subs.add(_player.stream.position.listen((p) {
      pos = p;
      notifyListeners();
    }));
    _subs.add(_player.stream.duration.listen((d) {
      dur = d;
      notifyListeners();
    }));
    _subs.add(_player.stream.playing.listen((p) {
      playing = p;
      notifyListeners();
    }));
  }

  Future<void> playItem(SavedItem item, {double volume = 100}) async {
    current = item;
    art = null;
    title = item.fileName;
    artist = null;
    notifyListeners();
    _loadArt(item);
    await _player.setVolume(volume);
    await _player.open(Media('file://${item.filePath}'), play: true);
  }

  void _loadArt(SavedItem item) {
    final path = item.filePath;
    if (path == null) return;
    try {
      final meta = readMetadata(File(path), getImage: true);
      if (meta.pictures.isNotEmpty) art = meta.pictures.first.bytes;
      if (meta.title != null && meta.title!.trim().isNotEmpty) {
        title = meta.title;
      }
      artist = meta.artist;
      notifyListeners();
    } catch (_) {}
  }

  void toggle() => _player.playOrPause();
  void seek(Duration d) => _player.seek(d);
  void nudge(int seconds) => _player.seek(pos + Duration(seconds: seconds));
  void setVolume(double v) => _player.setVolume(v);

  Future<void> stop() async {
    await _player.stop();
    current = null;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }
}
