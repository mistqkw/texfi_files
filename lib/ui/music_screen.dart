import 'package:flutter/material.dart';
import '../app.dart';
import '../core/models.dart';
import 'audio_player_screen.dart';
import 'format.dart';
import '../l10n/app_strings.dart';

/// Экран «Музыка»: вся аудио-музыка из ленты как плейлист.
class MusicScreen extends StatelessWidget {
  const MusicScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = tr(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.music)),
      body: ListenableBuilder(
        listenable: Listenable.merge([app.store, app.player]),
        builder: (context, _) {
          final tracks = app.store.items
              .where((e) => e.kind == ItemKind.audio && e.filePath != null)
              .toList()
              .reversed
              .toList();
          if (tracks.isEmpty) {
            return Center(
              child: Text(t.noMusic,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    FilledButton.icon(
                      onPressed: () => app.player.playQueue(tracks, 0,
                          volume: app.settings.playerVolume),
                      icon: const Icon(Icons.playlist_play_rounded),
                      label: Text(t.playAll),
                    ),
                    const SizedBox(width: 12),
                    Text('${tracks.length}',
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: tracks.length,
                  itemBuilder: (context, i) {
                    final it = tracks[i];
                    final isCur = app.player.current?.id == it.id;
                    final cs = Theme.of(context).colorScheme;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            isCur ? cs.primary : cs.surfaceContainerHighest,
                        child: Icon(
                          isCur && app.player.playing
                              ? Icons.equalizer_rounded
                              : Icons.music_note_rounded,
                          color: isCur ? cs.onPrimary : cs.onSurfaceVariant,
                        ),
                      ),
                      title: Text(it.fileName ?? t.audioWord,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight:
                                  isCur ? FontWeight.w700 : FontWeight.w400)),
                      subtitle: Text(humanSize(it.fileSize)),
                      onTap: () {
                        app.player.playQueue(tracks, i,
                            volume: app.settings.playerVolume);
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const AudioPlayerScreen()));
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
