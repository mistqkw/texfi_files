import 'package:flutter/material.dart';
import '../app.dart';
import '../app_state.dart';
import '../core/models.dart';
import '../core/player_service.dart';
import '../core/settings.dart';
import 'album_art.dart';
import 'audio_player_screen.dart';
import 'format.dart';
import 'terminal.dart';
import '../l10n/app_strings.dart';

/// Экран «Музыка»: вся аудио-музыка из ленты, с плейлистами по группам.
/// (Голосовые сообщения сюда не попадают — отдельный тип элемента.)
class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  String? _playlist; // null = все треки

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = tr(context);
    final s = app.settings;
    final terminal = s.terminalBubbles;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: terminal ? Colors.black : null,
      appBar: AppBar(
        backgroundColor: terminal ? Colors.black : null,
        title: terminal
            ? Text(
                t.music,
                style: monoStyle(color: cs.onSurface, size: 18, weight: FontWeight.w700),
              )
            : Text(t.music),
        actions: [
          ListenableBuilder(
            listenable: app.player,
            builder: (context, _) => IconButton(
              tooltip: t.shuffle,
              icon: Icon(
                Icons.shuffle_rounded,
                color: app.player.shuffle ? cs.primary : null,
              ),
              onPressed: app.player.toggleShuffle,
            ),
          ),
          ListenableBuilder(
            listenable: app.player,
            builder: (context, _) {
              final mode = app.player.repeatMode;
              return IconButton(
                tooltip: switch (mode) {
                  PlayerRepeatMode.off => t.repeatOff,
                  PlayerRepeatMode.all => t.repeatAll,
                  PlayerRepeatMode.one => t.repeatOne,
                },
                icon: Icon(
                  mode == PlayerRepeatMode.one
                      ? Icons.repeat_one_rounded
                      : Icons.repeat_rounded,
                  color: mode == PlayerRepeatMode.off ? null : cs.primary,
                ),
                onPressed: app.player.cycleRepeat,
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([app.store, app.player]),
        builder: (context, _) {
          final allTracks = app.store.items
              .where((e) => e.kind == ItemKind.audio && e.filePath != null)
              .toList()
              .reversed
              .toList();
          if (allTracks.isEmpty) {
            return Center(
              child: Text(
                t.noMusic,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            );
          }
          final playlists = <String>{
            for (final tr in allTracks)
              if (tr.group != null && tr.group!.isNotEmpty) tr.group!,
          }.toList()..sort();
          final tracks = _playlist == null
              ? allTracks
              : allTracks.where((e) => e.group == _playlist).toList();
          return Column(
            children: [
              if (playlists.isNotEmpty)
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(t.all),
                          selected: _playlist == null,
                          onSelected: (_) => setState(() => _playlist = null),
                        ),
                      ),
                      for (final p in playlists)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(p),
                            selected: _playlist == p,
                            onSelected: (_) => setState(() => _playlist = p),
                          ),
                        ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Row(
                  children: [
                    FilledButton.icon(
                      onPressed: tracks.isEmpty
                          ? null
                          : () => app.player.playQueue(
                              tracks,
                              0,
                              volume: app.settings.playerVolume,
                            ),
                      icon: const Icon(Icons.playlist_play_rounded),
                      label: Text(t.playAll),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${tracks.length}',
                      style: terminal
                          ? monoStyle(color: cs.onSurfaceVariant, size: 13)
                          : TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.only(bottom: 8, top: terminal ? 0 : 4),
                  itemCount: tracks.length,
                  itemBuilder: (context, i) {
                    final it = tracks[i];
                    final isCur = app.player.current?.id == it.id;
                    return terminal
                        ? _terminalTile(context, app, it, tracks, i, isCur, s, cs, t)
                        : _classicTile(context, app, it, tracks, i, isCur, cs, t);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _terminalTile(
    BuildContext context,
    AppState app,
    SavedItem it,
    List<SavedItem> tracks,
    int i,
    bool isCur,
    Settings s,
    ColorScheme cs,
    AppStrings t,
  ) {
    final accent = isCur ? cs.primary : Colors.white;
    final alpha = isCur ? 0.85 : s.borderOpacity;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: TerminalBox(
        label: '${i + 1}',
        borderColor: accent.withValues(alpha: alpha),
        labelColor: isCur ? cs.primary : cs.onSurfaceVariant,
        padding: EdgeInsets.zero,
        child: ListTile(
          leading: AlbumArtThumb(
            filePath: it.filePath,
            size: 46,
            radius: 3,
            fallback: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                border: Border.all(color: cs.primary.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Icon(
                isCur && app.player.playing
                    ? Icons.graphic_eq_rounded
                    : Icons.music_note_rounded,
                color: cs.primary,
                size: 22,
              ),
            ),
          ),
          title: Text(
            it.fileName ?? t.audioWord,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: isCur ? FontWeight.w700 : FontWeight.w400,
              color: isCur ? cs.primary : null,
            ),
          ),
          subtitle: Text(
            humanSize(it.fileSize),
            style: monoStyle(color: cs.onSurfaceVariant, size: 11),
          ),
          trailing: isCur && app.player.playing
              ? Icon(Icons.graphic_eq_rounded, color: cs.primary, size: 20)
              : null,
          onTap: () {
            app.player.playQueue(tracks, i, volume: app.settings.playerVolume);
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AudioPlayerScreen()),
            );
          },
        ),
      ),
    );
  }

  Widget _classicTile(
    BuildContext context,
    AppState app,
    SavedItem it,
    List<SavedItem> tracks,
    int i,
    bool isCur,
    ColorScheme cs,
    AppStrings t,
  ) {
    return ListTile(
      leading: AlbumArtThumb(
        filePath: it.filePath,
        size: 44,
        radius: 12,
        fallback: CircleAvatar(
          backgroundColor: isCur ? cs.primary : cs.surfaceContainerHighest,
          child: Icon(
            isCur && app.player.playing
                ? Icons.equalizer_rounded
                : Icons.music_note_rounded,
            color: isCur ? cs.onPrimary : cs.onSurfaceVariant,
          ),
        ),
      ),
      title: Text(
        it.fileName ?? t.audioWord,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: isCur ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      subtitle: Text(humanSize(it.fileSize)),
      onTap: () {
        app.player.playQueue(tracks, i, volume: app.settings.playerVolume);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AudioPlayerScreen()),
        );
      },
    );
  }
}
