import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../app.dart';
import '../core/models.dart';
import 'format.dart';

/// Красивый встроенный плеер для аудио и видео.
class PlayerPage extends StatefulWidget {
  final SavedItem item;
  const PlayerPage({super.key, required this.item});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final Player _player;
  VideoController? _video;
  final _subs = <StreamSubscription>[];

  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  bool _playing = false;

  bool get _isVideo => widget.item.kind == ItemKind.video;

  @override
  void initState() {
    super.initState();
    _player = Player();
    if (_isVideo) _video = VideoController(_player);
    _subs.add(_player.stream.position.listen((p) {
      if (mounted) setState(() => _pos = p);
    }));
    _subs.add(_player.stream.duration.listen((d) {
      if (mounted) setState(() => _dur = d);
    }));
    _subs.add(_player.stream.playing.listen((p) {
      if (mounted) setState(() => _playing = p);
    }));
  }

  bool _opened = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opened) return;
    _opened = true;
    // Доступ к AppScope безопасен здесь (после initState).
    final s = AppScope.of(context).settings;
    _player.setVolume(s.playerVolume);
    _player.open(Media('file://${widget.item.filePath}'), play: true);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '${h.toString().padLeft(2, '0')}:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = widget.item.fileName ?? 'Медиа';
    return Scaffold(
      backgroundColor: _isVideo ? Colors.black : cs.surface,
      appBar: AppBar(
        backgroundColor: _isVideo ? Colors.black : null,
        foregroundColor: _isVideo ? Colors.white : null,
        title: Text(title, overflow: TextOverflow.ellipsis),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _isVideo && _video != null
                  ? Video(controller: _video!, controls: NoVideoControls)
                  : _AudioArt(title: title, playing: _playing, color: cs),
            ),
          ),
          _controls(cs),
        ],
      ),
    );
  }

  Widget _controls(ColorScheme cs) {
    final onColor = _isVideo ? Colors.white : cs.onSurface;
    final max = _dur.inMilliseconds.toDouble();
    final value = _pos.inMilliseconds.clamp(0, max <= 0 ? 1 : max).toDouble();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      color: _isVideo ? Colors.black : cs.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              overlayShape: SliderComponentShape.noOverlay,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: value,
              max: max <= 0 ? 1 : max,
              activeColor: cs.primary,
              inactiveColor: onColor.withValues(alpha: 0.2),
              onChanged: (v) =>
                  _player.seek(Duration(milliseconds: v.toInt())),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_fmt(_pos),
                    style: TextStyle(color: onColor.withValues(alpha: 0.7))),
                Text(_fmt(_dur),
                    style: TextStyle(color: onColor.withValues(alpha: 0.7))),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 34,
                color: onColor,
                onPressed: () => _player.seek(
                    _pos - const Duration(seconds: 10)),
                icon: const Icon(Icons.replay_10_rounded),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  iconSize: 40,
                  color: cs.onPrimary,
                  onPressed: () => _player.playOrPause(),
                  icon: Icon(_playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                iconSize: 34,
                color: onColor,
                onPressed: () => _player.seek(
                    _pos + const Duration(seconds: 10)),
                icon: const Icon(Icons.forward_10_rounded),
              ),
            ],
          ),
          if (widget.item.fileSize > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(humanSize(widget.item.fileSize),
                  style: TextStyle(
                      color: onColor.withValues(alpha: 0.5), fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

class _AudioArt extends StatelessWidget {
  final String title;
  final bool playing;
  final ColorScheme color;
  const _AudioArt(
      {required this.title, required this.playing, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedScale(
          scale: playing ? 1.0 : 0.94,
          duration: const Duration(milliseconds: 300),
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.primary, color.tertiary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(36),
              boxShadow: [
                BoxShadow(
                  color: color.primary.withValues(alpha: 0.4),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(Icons.music_note_rounded,
                size: 96, color: color.onPrimary),
          ),
        ),
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
