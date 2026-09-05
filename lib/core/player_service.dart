import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'models.dart';

/// Режим повтора плейлиста.
enum PlayerRepeatMode { off, one, all }

/// Чтение тегов трека в фоновом изоляте (title/artist/обложка) — синхронный
/// парсинг на UI-потоке подлагивал при каждом старте трека.
Map<String, dynamic> _readTrackMeta(String path) {
  final out = <String, dynamic>{};
  try {
    final meta = readMetadata(File(path), getImage: true);
    if (meta.title != null && meta.title!.trim().isNotEmpty) {
      out['title'] = meta.title;
    }
    if (meta.artist != null && meta.artist!.trim().isNotEmpty) {
      out['artist'] = meta.artist;
    }
    if (meta.pictures.isNotEmpty) out['art'] = meta.pictures.first.bytes;
  } catch (_) {}
  return out;
}

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

  // Плейлист (для экрана «Музыка»).
  List<SavedItem> queue = [];
  int qIndex = 0;
  double _volume = 100;
  bool shuffle = false;
  PlayerRepeatMode repeatMode = PlayerRepeatMode.off;
  final _rand = Random();

  Player get raw => _player;

  /// Громкость 0..100. Публичный геттер существует ради MPRIS (там шкала
  /// 0..1) — внутри плеера всё и так обращается к приватному полю.
  double get volume => _volume;

  /// Вызывается на каждый явный переход позиции (перемотка слайдером,
  /// +10/-10, MPRIS Seek/SetPosition) — но не на обычное продвижение
  /// плеера во время воспроизведения. MPRIS-мост слушает это, чтобы
  /// отправить сигнал `Seeked`: обычные проигрыватели вроде GNOME Shell
  /// используют его, чтобы не принять скачок позиции за рассинхронизацию.
  void Function(Duration)? onSeek;

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
    // Автопереход к следующему треку.
    _subs.add(_player.stream.completed.listen((done) {
      if (!done) return;
      if (repeatMode == PlayerRepeatMode.one) {
        _player.seek(Duration.zero);
        _player.play();
        return;
      }
      if (queue.isNotEmpty) next();
    }));
  }

  void toggleShuffle() {
    shuffle = !shuffle;
    notifyListeners();
  }

  void cycleRepeat() {
    repeatMode = switch (repeatMode) {
      PlayerRepeatMode.off => PlayerRepeatMode.all,
      PlayerRepeatMode.all => PlayerRepeatMode.one,
      PlayerRepeatMode.one => PlayerRepeatMode.off,
    };
    notifyListeners();
  }

  /// Задать режим повтора напрямую (а не по циклу) — нужен MPRIS, где
  /// клиент присылает конкретное значение `LoopStatus`, а не «переключи
  /// на следующее».
  void setRepeatMode(PlayerRepeatMode mode) {
    if (mode == repeatMode) return;
    repeatMode = mode;
    notifyListeners();
  }

  /// Проиграть плейлист начиная с index.
  Future<void> playQueue(List<SavedItem> list, int index,
      {double volume = 100}) async {
    queue = List.of(list);
    qIndex = index.clamp(0, list.length - 1);
    await playItem(queue[qIndex], volume: volume, keepQueue: true);
  }

  Future<void> next() async {
    if (queue.isEmpty) return;
    if (shuffle && queue.length > 1) {
      int idx;
      do {
        idx = _rand.nextInt(queue.length);
      } while (idx == qIndex);
      qIndex = idx;
      await playItem(queue[qIndex], volume: _volume, keepQueue: true);
      return;
    }
    if (qIndex < queue.length - 1) {
      qIndex++;
      await playItem(queue[qIndex], volume: _volume, keepQueue: true);
    } else if (repeatMode == PlayerRepeatMode.all) {
      qIndex = 0;
      await playItem(queue[qIndex], volume: _volume, keepQueue: true);
    }
  }

  Future<void> previous() async {
    if (queue.isEmpty) return;
    if (pos.inSeconds > 3) {
      seek(Duration.zero);
      return;
    }
    if (shuffle && queue.length > 1) {
      int idx;
      do {
        idx = _rand.nextInt(queue.length);
      } while (idx == qIndex);
      qIndex = idx;
      await playItem(queue[qIndex], volume: _volume, keepQueue: true);
      return;
    }
    if (qIndex > 0) {
      qIndex--;
      await playItem(queue[qIndex], volume: _volume, keepQueue: true);
    } else if (repeatMode == PlayerRepeatMode.all) {
      qIndex = queue.length - 1;
      await playItem(queue[qIndex], volume: _volume, keepQueue: true);
    }
  }

  Future<void> playItem(SavedItem item,
      {double volume = 100, bool keepQueue = false}) async {
    if (!keepQueue) queue = [];
    _volume = volume;
    current = item;
    art = null;
    title = item.fileName;
    artist = null;
    notifyListeners();
    _loadArt(item);
    await _player.setVolume(volume);
    await _player.open(Media('file://${item.filePath}'), play: true);
  }

  Future<void> _loadArt(SavedItem item) async {
    final path = item.filePath;
    if (path == null) return;
    try {
      final meta = await compute(_readTrackMeta, path);
      // Пока читали теги в фоне, пользователь мог переключить трек.
      if (current?.id != item.id) return;
      if (meta['art'] is Uint8List) art = meta['art'] as Uint8List;
      if (meta['title'] is String) title = meta['title'] as String;
      if (meta['artist'] is String) artist = meta['artist'] as String;
      notifyListeners();
    } catch (_) {}
  }

  void toggle() => _player.playOrPause();
  void play() => _player.play();
  void pause() => _player.pause();

  void seek(Duration d) {
    _player.seek(d);
    onSeek?.call(d);
  }

  void nudge(int seconds) {
    final d = pos + Duration(seconds: seconds);
    _player.seek(d);
    onSeek?.call(d);
  }

  void setVolume(double v) {
    _volume = v;
    _player.setVolume(v);
  }

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
