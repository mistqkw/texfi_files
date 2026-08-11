import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import '../app.dart';
import '../core/models.dart';
import 'audio_player_screen.dart';
import 'format.dart';
import 'player_page.dart';

class ItemBubble extends StatelessWidget {
  final SavedItem item;
  final VoidCallback onDelete;
  const ItemBubble({super.key, required this.item, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = AppScope.of(context).settings;
    final align = item.outgoing ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor =
        item.outgoing ? cs.primaryContainer : cs.surfaceContainerHighest;
    final r = s.bubbleRadius;
    final tail = r * 0.28;
    final vMargin = s.compact ? 2.0 : 4.0;

    return Align(
      alignment: align,
      child: ConstraintsBox(
        child: GestureDetector(
          onLongPress: () => _menu(context),
          child: Container(
            margin: EdgeInsets.symmetric(vertical: vMargin, horizontal: 12),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(r),
                topRight: Radius.circular(r),
                bottomLeft: Radius.circular(item.outgoing ? r : tail),
                bottomRight: Radius.circular(item.outgoing ? tail : r),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: _content(context, cs),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, ColorScheme cs) {
    switch (item.kind) {
      case ItemKind.text:
        return _textContent(context, cs);
      case ItemKind.image:
        return _imageContent(context, cs);
      case ItemKind.audio:
      case ItemKind.video:
        return _mediaContent(context, cs);
      case ItemKind.file:
        return _fileContent(context, cs);
    }
  }

  Widget _footer(ColorScheme cs) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!item.outgoing && item.fromName != null) ...[
              Icon(Icons.smartphone_rounded,
                  size: 12, color: cs.onSurfaceVariant),
              const SizedBox(width: 3),
              Text(item.fromName!,
                  style:
                      TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              const SizedBox(width: 8),
            ],
            Text(clockTime(item.createdAt),
                style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.8))),
            if (item.group != null) ...[
              const SizedBox(width: 6),
              Icon(Icons.folder_rounded, size: 11, color: cs.onSurfaceVariant),
            ],
            if (item.pinned) ...[
              const SizedBox(width: 4),
              Icon(Icons.push_pin, size: 11, color: cs.primary),
            ],
          ],
        ),
      );

  Widget _textContent(BuildContext context, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SelectableText(item.text ?? '',
              style: const TextStyle(fontSize: 15, height: 1.3)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => _copy(context),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.copy_rounded,
                      size: 15, color: cs.onSurfaceVariant),
                ),
              ),
              const Spacer(),
              _footer(cs),
            ],
          ),
        ],
      ),
    );
  }

  Widget _imageContent(BuildContext context, ColorScheme cs) {
    final path = item.filePath;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (path != null && File(path).existsSync())
          GestureDetector(
            onTap: () => _openImage(context, path),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: Image.file(File(path), fit: BoxFit.cover),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(item.fileName ?? 'Изображение',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              _footer(cs),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mediaContent(BuildContext context, ColorScheme cs) {
    final isVideo = item.kind == ItemKind.video;
    return InkWell(
      onTap: () {
        if (isVideo) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => PlayerPage(item: item)),
          );
        } else {
          // Аудио — через глобальный плеер (мини-плеер + фон).
          final app = AppScope.of(context);
          app.player.playItem(item, volume: app.settings.playerVolume);
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AudioPlayerScreen()),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [cs.primary, cs.tertiary]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                  isVideo
                      ? Icons.play_arrow_rounded
                      : Icons.music_note_rounded,
                  color: cs.onPrimary,
                  size: 30),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(item.fileName ?? (isVideo ? 'Видео' : 'Аудио'),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    '${isVideo ? 'Видео' : 'Аудио'} · ${humanSize(item.fileSize)}',
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                  _footer(cs),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fileContent(BuildContext context, ColorScheme cs) {
    return InkWell(
      onTap: () {
        if (item.filePath != null) OpenFilex.open(item.filePath!);
      },
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: cs.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.insert_drive_file_rounded,
                  color: cs.onSecondaryContainer),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(item.fileName ?? 'Файл',
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(humanSize(item.fileSize),
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant)),
                  _footer(cs),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Сохранить',
              icon: const Icon(Icons.download_rounded),
              onPressed: () => _saveAs(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAs(BuildContext context) async {
    final src = item.filePath;
    if (src == null || !File(src).existsSync()) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (Platform.isAndroid) {
        // На Android сохраняем через системный диалог с байтами.
        final bytes = await File(src).readAsBytes();
        final path = await FilePicker.platform.saveFile(
          dialogTitle: 'Сохранить файл',
          fileName: item.fileName ?? 'file',
          bytes: bytes,
        );
        messenger.showSnackBar(SnackBar(
            content: Text(path != null ? 'Сохранено' : 'Отменено')));
      } else {
        // Desktop: выбираем путь и копируем файл.
        final path = await FilePicker.platform.saveFile(
          dialogTitle: 'Сохранить файл',
          fileName: item.fileName ?? 'file',
        );
        if (path == null) {
          messenger.showSnackBar(const SnackBar(content: Text('Отменено')));
          return;
        }
        await File(src).copy(path);
        messenger.showSnackBar(SnackBar(content: Text('Сохранено: $path')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Ошибка сохранения: $e')));
    }
  }

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: item.text ?? ''));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Скопировано'), duration: Duration(seconds: 1)),
    );
  }

  void _openImage(BuildContext context, String path) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: InteractiveViewer(
            maxScale: 5,
            child: Image.file(File(path)),
          ),
        ),
      ),
    ));
  }

  void _groupDialog(BuildContext context) {
    final store = AppScope.of(context).store;
    final groups = store.groups;
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final g in groups)
              ListTile(
                leading: const Icon(Icons.folder_rounded),
                title: Text(g),
                trailing: item.group == g ? const Icon(Icons.check) : null,
                onTap: () {
                  store.setGroup(item, g);
                  Navigator.pop(context);
                },
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        hintText: 'Новая группа…',
                        prefixIcon: Icon(Icons.create_new_folder_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      final name = controller.text.trim();
                      if (name.isNotEmpty) store.setGroup(item, name);
                      Navigator.pop(context);
                    },
                    child: const Text('OK'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _menu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.kind == ItemKind.text)
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Копировать'),
                onTap: () {
                  Navigator.pop(context);
                  _copy(context);
                },
              ),
            if (item.filePath != null)
              ListTile(
                leading: const Icon(Icons.open_in_new_rounded),
                title: const Text('Открыть'),
                onTap: () {
                  Navigator.pop(context);
                  OpenFilex.open(item.filePath!);
                },
              ),
            if (item.filePath != null)
              ListTile(
                leading: const Icon(Icons.download_rounded),
                title: const Text('Сохранить как…'),
                onTap: () {
                  Navigator.pop(context);
                  _saveAs(context);
                },
              ),
            ListTile(
              leading: Icon(item.pinned
                  ? Icons.push_pin
                  : Icons.push_pin_outlined),
              title: Text(item.pinned ? 'Открепить' : 'Закрепить'),
              onTap: () {
                Navigator.pop(context);
                AppScope.of(context).store.togglePin(item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(item.group == null
                  ? 'Добавить в группу…'
                  : 'Группа: ${item.group}'),
              onTap: () {
                Navigator.pop(context);
                _groupDialog(context);
              },
            ),
            if (item.group != null)
              ListTile(
                leading: const Icon(Icons.folder_off_outlined),
                title: const Text('Убрать из группы'),
                onTap: () {
                  Navigator.pop(context);
                  AppScope.of(context).store.setGroup(item, null);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Удалить'),
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ConstraintsBox extends StatelessWidget {
  final Widget child;
  const ConstraintsBox({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: w > 700 ? 520 : w * 0.82),
      child: child,
    );
  }
}
