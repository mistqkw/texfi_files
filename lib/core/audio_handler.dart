import 'package:audio_service/audio_service.dart';
import 'player_service.dart';

/// Мост между PlayerService (media_kit) и системой: превращает состояние
/// плеера в медиа-уведомление (шторка, экран блокировки, гарнитура).
/// PlayerService остаётся единственным источником истины — этот класс только
/// зеркалит его состояние наружу и транслирует системные команды обратно.
class TexFiAudioHandler extends BaseAudioHandler with SeekHandler {
  final PlayerService _player;
  String? _lastItemId;

  TexFiAudioHandler(this._player) {
    _player.addListener(_sync);
    _sync();
  }

  void _sync() {
    final item = _player.current;
    if (item == null) {
      _lastItemId = null;
      mediaItem.add(null);
    } else {
      final dur = _player.dur == Duration.zero ? null : _player.dur;
      if (item.id != _lastItemId) {
        _lastItemId = item.id;
        mediaItem.add(
          MediaItem(
            id: item.id,
            title: _player.title?.trim().isNotEmpty == true
                ? _player.title!
                : (item.fileName ?? 'Audio'),
            artist: _player.artist?.trim().isNotEmpty == true
                ? _player.artist
                : null,
            duration: dur,
          ),
        );
      } else if (mediaItem.value?.duration != dur) {
        mediaItem.add(mediaItem.value?.copyWith(duration: dur));
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
