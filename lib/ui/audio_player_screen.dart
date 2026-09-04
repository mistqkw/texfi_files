import 'package:flutter/material.dart';

import '../app.dart';
import '../core/haptics.dart';
import '../core/player_service.dart';
import '../core/theme/app_colors_ext.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles_ext.dart';
import '../l10n/app_strings.dart';
import 'pixel/pixel_card.dart';
import 'pixel/pixel_icons.dart';
import 'pixel/pixel_seekbar.dart';

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
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(tr(context).nowPlaying, style: context.text.screenTitle),
      ),
      body: ListenableBuilder(
        listenable: player,
        builder: (context, _) {
          if (player.current == null) {
            return Center(
              child: Text(
                tr(context).nothingPlaying,
                style: context.text.bodySmall,
              ),
            );
          }
          return Column(
            children: [
              Expanded(child: Center(child: _art(context, player))),
              _controls(context, player),
            ],
          );
        },
      ),
    );
  }

  Widget _art(BuildContext context, PlayerService p) {
    final colors = context.colors;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Обложка чуть «оседает» на паузе — единственная анимация на
        // экране, и она сообщает состояние, а не украшает.
        AnimatedScale(
          scale: p.playing ? 1.0 : 0.95,
          duration: const Duration(milliseconds: 220),
          child: PixelCard(
            padding: const EdgeInsets.all(AppSpacing.sm),
            accent: p.playing,
            child: SizedBox(
              width: 260,
              height: 260,
              child: p.art != null
                  ? Image.memory(
                      p.art!,
                      fit: BoxFit.cover,
                      // Обложка декодируется под свой размер на экране, а
                      // не в полном разрешении тега.
                      cacheHeight: 520,
                      gaplessPlayback: true,
                    )
                  : ColoredBox(
                      color: colors.surfaceVariant,
                      child: Center(
                        child: PixelIcon(
                          'note',
                          size: 96,
                          color: colors.accent,
                        ),
                      ),
                    ),
            ),
          ),
        ),
        AppSpacing.gapXl,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Text(
            p.title ?? tr(context).audioWord,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            // Название трека читают — оно набирается гротеском, а не
            // пиксельным шрифтом.
            style: context.text.bodyLarge.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        if (p.artist != null && p.artist!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(p.artist!, style: context.text.bodySmall),
          ),
      ],
    );
  }

  Widget _controls(BuildContext context, PlayerService p) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PixelSeekBar(
            position: p.pos,
            duration: p.dur,
            onSeek: p.seek,
          ),
          AppSpacing.gapSm,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Табличные цифры: иначе строка времени дёргается по ширине
              // на каждой секунде.
              Text(_fmt(p.pos), style: context.text.statSmall),
              Text(_fmt(p.dur), style: context.text.statSmall),
            ],
          ),
          AppSpacing.gapLg,
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (p.queue.isNotEmpty)
                PixelIconButton(icon: 'prev', size: 20, onPressed: p.previous),
              PixelIconButton(
                icon: 'back',
                size: 18,
                tooltip: '-10s',
                onPressed: () => p.nudge(-10),
              ),
              AppSpacing.wGapSm,
              _PlayButton(playing: p.playing, onTap: p.toggle),
              AppSpacing.wGapSm,
              PixelIconButton(
                icon: 'send',
                size: 18,
                tooltip: '+10s',
                onPressed: () => p.nudge(10),
              ),
              if (p.queue.isNotEmpty)
                PixelIconButton(icon: 'next', size: 20, onPressed: p.next),
            ],
          ),
          if (p.queue.length > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PixelIconButton(
                  icon: 'shuffle',
                  size: 17,
                  tooltip: tr(context).shuffle,
                  color: p.shuffle ? colors.accent : colors.textTertiary,
                  onPressed: p.toggleShuffle,
                ),
                AppSpacing.wGapMd,
                PixelIconButton(
                  icon: p.repeatMode == PlayerRepeatMode.one
                      ? 'repeatone'
                      : 'repeat',
                  size: 17,
                  tooltip: switch (p.repeatMode) {
                    PlayerRepeatMode.off => tr(context).repeatOff,
                    PlayerRepeatMode.all => tr(context).repeatAll,
                    PlayerRepeatMode.one => tr(context).repeatOne,
                  },
                  color: p.repeatMode == PlayerRepeatMode.off
                      ? colors.textTertiary
                      : colors.accent,
                  onPressed: p.cycleRepeat,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Главная кнопка транспорта. Квадратная и с офсетной тенью — как все
/// остальные кнопки приложения, а не круглая материаловская.
class _PlayButton extends StatefulWidget {
  const _PlayButton({required this.playing, required this.onTap});

  final bool playing;
  final VoidCallback onTap;

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        Haptics.tap();
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        width: 64,
        height: 64,
        alignment: Alignment.center,
        transform: Matrix4.translationValues(
          _pressed ? AppRadius.pixelShadowOffset : 0,
          _pressed ? AppRadius.pixelShadowOffset : 0,
          0,
        ),
        decoration: BoxDecoration(
          color: colors.accent,
          borderRadius: AppRadius.controlSmallAll,
          border: Border.all(
            color: colors.accent,
            width: AppRadius.pixelBorder,
          ),
          boxShadow: _pressed
              ? const []
              : [
                  BoxShadow(
                    color: colors.accentShadow,
                    offset: const Offset(
                      AppRadius.pixelShadowOffset,
                      AppRadius.pixelShadowOffset,
                    ),
                  ),
                ],
        ),
        child: PixelIcon(
          widget.playing ? 'pause' : 'play',
          size: 26,
          color: colors.onAccent,
        ),
      ),
    );
  }
}
