import 'package:flutter/material.dart';
import '../app.dart';
import '../core/player_service.dart';
import '../l10n/app_strings.dart';

String _fmt(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  final h = d.inHours;
  return h > 0 ? '${h.toString().padLeft(2, '0')}:$m:$s' : '$m:$s';
}

/// Полноэкранный аудио-плеер, привязанный к глобальному PlayerService.
class AudioPlayerScreen extends StatelessWidget {
  const AudioPlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final player = AppScope.of(context).player;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr(context).nowPlaying)),
      body: ListenableBuilder(
        listenable: player,
        builder: (context, _) {
          if (player.current == null) {
            return Center(child: Text(tr(context).nothingPlaying));
          }
          return Column(
            children: [
              Expanded(child: Center(child: _art(context, player, cs))),
              _controls(context, player, cs),
            ],
          );
        },
      ),
    );
  }

  Widget _art(BuildContext context, PlayerService p, ColorScheme cs) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedScale(
          scale: p.playing ? 1.0 : 0.94,
          duration: const Duration(milliseconds: 300),
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              gradient: p.art == null
                  ? LinearGradient(
                      colors: [cs.primary, cs.tertiary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight)
                  : null,
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                    color: cs.primary.withValues(alpha: 0.4),
                    blurRadius: 48,
                    spreadRadius: 4),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: p.art != null
                ? Image.memory(p.art!, fit: BoxFit.cover)
                : Icon(Icons.music_note_rounded,
                    size: 120, color: cs.onPrimary),
          ),
        ),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(p.title ?? tr(context).audioWord,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        ),
        if (p.artist != null && p.artist!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(p.artist!,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15)),
          ),
      ],
    );
  }

  Widget _controls(BuildContext context, PlayerService p, ColorScheme cs) {
    final max = p.dur.inMilliseconds.toDouble();
    final value = p.pos.inMilliseconds.clamp(0, max <= 0 ? 1 : max).toDouble();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
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
              onChanged: (v) => p.seek(Duration(milliseconds: v.toInt())),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_fmt(p.pos),
                    style: TextStyle(color: cs.onSurfaceVariant)),
                Text(_fmt(p.dur),
                    style: TextStyle(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (p.queue.isNotEmpty)
                IconButton(
                  iconSize: 32,
                  onPressed: p.previous,
                  icon: const Icon(Icons.skip_previous_rounded),
                ),
              IconButton(
                iconSize: 36,
                onPressed: () => p.nudge(-10),
                icon: const Icon(Icons.replay_10_rounded),
              ),
              const SizedBox(width: 8),
              Container(
                decoration:
                    BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                child: IconButton(
                  iconSize: 44,
                  color: cs.onPrimary,
                  onPressed: p.toggle,
                  icon: Icon(p.playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                iconSize: 36,
                onPressed: () => p.nudge(10),
                icon: const Icon(Icons.forward_10_rounded),
              ),
              if (p.queue.isNotEmpty)
                IconButton(
                  iconSize: 32,
                  onPressed: p.next,
                  icon: const Icon(Icons.skip_next_rounded),
                ),
            ],
          ),
          if (p.queue.length > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: tr(context).shuffle,
                  icon: Icon(
                    Icons.shuffle_rounded,
                    color: p.shuffle ? cs.primary : cs.onSurfaceVariant,
                  ),
                  onPressed: p.toggleShuffle,
                ),
                const SizedBox(width: 12),
                IconButton(
                  tooltip: switch (p.repeatMode) {
                    PlayerRepeatMode.off => tr(context).repeatOff,
                    PlayerRepeatMode.all => tr(context).repeatAll,
                    PlayerRepeatMode.one => tr(context).repeatOne,
                  },
                  icon: Icon(
                    p.repeatMode == PlayerRepeatMode.one
                        ? Icons.repeat_one_rounded
                        : Icons.repeat_rounded,
                    color: p.repeatMode == PlayerRepeatMode.off
                        ? cs.onSurfaceVariant
                        : cs.primary,
                  ),
                  onPressed: p.cycleRepeat,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
