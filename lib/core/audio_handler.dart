import 'dart:io';
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart';
import 'package:path_provider/path_provider.dart';
import 'player_service.dart';

/// Мост между PlayerService (media_kit) и системой: превращает состояние
/// плеера в медиа-уведомление (шторка, экран блокировки, гарнитура).
/// PlayerService остаётся единственным источником истины — этот класс только
/// зеркалит его состояние наружу и транслирует системные команды обратно.
class TexFiAudioHandler extends BaseAudioHandler with SeekHandler {
  final PlayerService _player;
  String? _lastItemId;
  // id трека, для которого обложка уже записана в файл и проставлена в
  // MediaItem — чтобы не писать её на каждый тик позиции.
  String? _artWrittenFor;
  Directory? _artDir;

  TexFiAudioHandler(this._player) {
    _player.addListener(_sync);
    _sync();
  }

  Future<Directory> _artCacheDir() async {
    _artDir ??= Directory(
      '${(await getTemporaryDirectory()).path}/media_art',
    )..createSync(recursive: true);
    return _artDir!;
  }

  /// Обложка в шторке Android берётся по artUri (файл/URL), а не из байтов,
  /// поэтому извлечённую из тегов картинку сохраняем во временный файл и
  /// подставляем его как artUri. Делается один раз на трек.
  Future<void> _writeArtAndPublish(String itemId, Uint8List bytes) async {
    try {
      final dir = await _artCacheDir();
      final file = File('${dir.path}/$itemId.img');
      if (!file.existsSync()) {
        await file.writeAsBytes(bytes, flush: true);
      }
      // Пока писали файл, пользователь мог переключить трек — не перетираем.
      if (_player.current?.id != itemId) return;
      final base = mediaItem.value;
      if (base == null || base.id != itemId) return;
      mediaItem.add(base.copyWith(artUri: Uri.file(file.path)));
      _artWrittenFor = itemId;
    } catch (_) {
      // Не критично — уведомление просто останется без обложки.
    }
  }

  void _sync() {
    final item = _player.current;
    if (item == null) {
      _lastItemId = null;
      _artWrittenFor = null;
      mediaItem.add(null);
    } else {
      final dur = _player.dur == Duration.zero ? null : _player.dur;
      if (item.id != _lastItemId) {
        _lastItemId = item.id;
        _artWrittenFor = null;
        mediaItem.add(
          MediaItem(
            id: item.id,
            title: _player.title?.trim().isNotEmpty == true
                ? _player.title!
                : (item.fileName ?? 'Audio'),
            artist: _player.artist?.trim().isNotEmpty == true
                ? _player.artist
                : 'TexFi files',
            duration: dur,
          ),
        );
      } else if (mediaItem.value?.duration != dur) {
        mediaItem.add(mediaItem.value?.copyWith(duration: dur));
      }
      // Обложка приходит асинхронно (после чтения тегов) — публикуем, как
      // только она появилась для текущего трека.
      final art = _player.art;
      if (art != null && _artWrittenFor != item.id) {
        _writeArtAndPublish(item.id, art);
      }
    }

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          _player.playing ? MediaControl.pause : MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: item == null
            ? AudioProcessingState.idle
            : AudioProcessingState.ready,
        playing: _player.playing,
        updatePosition: _player.pos,
        bufferedPosition: _player.pos,
        queueIndex: _player.qIndex,
      ),
    );
  }

  @override
  Future<void> play() async => _player.play();

  @override
  Future<void> pause() async => _player.pause();

  @override
  Future<void> seek(Duration position) async => _player.seek(position);

  @override
  Future<void> skipToNext() async => _player.next();

  @override
  Future<void> skipToPrevious() async => _player.previous();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }
}
