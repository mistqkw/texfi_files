import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import '../app.dart';
import 'album_art.dart';
import 'audio_player_screen.dart';
import 'pixel/pixel_icons.dart';
import 'pixel/pixel_theme.dart';

/// Плеер поверх ленты — маленький квадратик с обложкой трека, который можно
/// перетащить в любое место экрана (а не панель на всю ширину внизу).
/// Тап открывает полноэкранный плеер, долгое нажатие — останавливает трек.
class FloatingMiniPlayer extends StatefulWidget {
  const FloatingMiniPlayer({super.key});

  @override
  State<FloatingMiniPlayer> createState() => _FloatingMiniPlayerState();
}

class _FloatingMiniPlayerState extends State<FloatingMiniPlayer> {
  static const double _size = 64;

  // null — ещё не размещали, подставим позицию по умолчанию при первой
  // сборке (нужны размеры экрана, которых нет в initState).
  Offset? _pos;

  Offset _clamped(Offset p, Size screen, EdgeInsets safe) {
    final minX = 8.0;
    final maxX = screen.width - _size - 8;
    final minY = safe.top + 8;
    final maxY = screen.height - safe.bottom - _size - 8;
    return Offset(
      p.dx.clamp(minX, maxX < minX ? minX : maxX),
      p.dy.clamp(minY, maxY < minY ? minY : maxY),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ListenableBuilder(
      listenable: app.player,
      builder: (context, _) {
        final player = app.player;
        if (player.current == null) return const SizedBox.shrink();

        final screen = MediaQuery.sizeOf(context);
        final safe = MediaQuery.paddingOf(context);
        _pos ??= Offset(
          screen.width - _size - 16,
          // Над панелью ввода с запасом.
          screen.height - safe.bottom - _size - 150,
        );
        final pos = _clamped(_pos!, screen, safe);

        final cs = Theme.of(context).colorScheme;
        final maxMs = player.dur.inMilliseconds;
        final progress = maxMs <= 0
            ? 0.0
            : (player.pos.inMilliseconds / maxMs).clamp(0.0, 1.0);

        return Positioned(
          left: pos.dx,
          top: pos.dy,
          child: GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AudioPlayerScreen()),
            ),
            onLongPress: () {
              HapticFeedback.mediumImpact();
              player.stop();
            },
            onPanUpdate: (d) => setState(() => _pos = _pos! + d.delta),
            onPanEnd: (_) =>
                setState(() => _pos = _clamped(_pos!, screen, safe)),
            child: Container(
              width: _size,
              height: _size,
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(
                  color: Colors.white.withValues(
                    alpha: app.settings.borderOpacity,
                  ),
                  width: PixelTheme.borderWidth,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  AlbumArtThumb(
                    filePath: player.current!.filePath,
                    size: _size,
                    radius: 0,
                    fallback: Container(
                      width: _size,
                      height: _size,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [cs.primary, cs.tertiary],
                        ),
                      ),
                      child: PixelIcon('note',
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                  if (!player.playing)
                    Container(
                      width: _size,
                      height: _size,
                      color: Colors.black45,
                      child: PixelIcon('pause',
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: SizedBox(
                      height: 2,
                      child: LinearProgressIndicator(
                        value: progress == 0 ? null : progress,
                        minHeight: 2,
                        backgroundColor: Colors.white24,
                        valueColor: AlwaysStoppedAnimation(cs.primary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
