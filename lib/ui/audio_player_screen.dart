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
              IconButton(
                iconSize: 36,
                onPressed: () => p.nudge(-10),
                icon: const Icon(Icons.replay_10_rounded),
              ),
              const SizedBox(width: 12),
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
              const SizedBox(width: 12),
              IconButton(
                iconSize: 36,
                onPressed: () => p.nudge(10),
                icon: const Icon(Icons.forward_10_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Мини-плеер: компактная плашка внизу ленты, пока играет аудио.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = AppScope.of(context).player;
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        if (player.current == null) return const SizedBox.shrink();
        final max = player.dur.inMilliseconds.toDouble();
        final value =
            player.pos.inMilliseconds.clamp(0, max <= 0 ? 1 : max).toDouble();
        return Material(
          color: cs.surfaceContainerHighest,
          child: InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const AudioPlayerScreen())),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: max <= 0 ? null : value / max,
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
                  child: Row(
                    children: [
                      _thumb(player, cs),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(player.title ?? tr(context).audioWord,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            if (player.artist != null &&
                                player.artist!.trim().isNotEmpty)
                              Text(player.artist!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: player.toggle,
                        icon: Icon(player.playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded),
                      ),
                      IconButton(
                        onPressed: player.stop,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _thumb(PlayerService p, ColorScheme cs) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: p.art == null
            ? LinearGradient(colors: [cs.primary, cs.tertiary])
            : null,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: p.art != null
          ? Image.memory(p.art!, fit: BoxFit.cover)
          : Icon(Icons.music_note_rounded, color: cs.onPrimary, size: 22),
    );
  }
}
