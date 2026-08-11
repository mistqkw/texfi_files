import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import '../app.dart';
import '../core/models.dart';
import '../l10n/app_strings.dart';
import 'audio_player_screen.dart';
import 'format.dart';
import 'image_gallery.dart';
import 'player_page.dart';
import 'video_thumb.dart';

class ItemBubble extends StatelessWidget {
  final SavedItem item;
  final VoidCallback onDelete;
  const ItemBubble({super.key, required this.item, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = AppScope.of(context).settings;
    final align = item.outgoing ? Alignment.centerRight : Alignment.centerLeft;
    final override = item.outgoing ? s.msgOutColor : s.msgInColor;
    final bubbleColor = override != -1
        ? Color(override)
        : (item.outgoing ? cs.primaryContainer : cs.surfaceContainerHighest);
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
            const SizedBox(width: 4),
            Icon(
              item.cloud ? Icons.cloud_done_rounded : Icons.smartphone_rounded,
              size: 11,
              color: item.cloud
                  ? cs.primary
                  : cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
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
              child: Hero(
                tag: path,
                child: Image.file(File(path), fit: BoxFit.cover),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(item.fileName ?? tr(context).imageWord,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              _footer(cs),
            ],
          ),
        ),
      ],
    );
  }

  void _openMedia(BuildContext context, bool isVideo) {
    if (isVideo) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PlayerPage(item: item)),
      );
    } else {
      final app = AppScope.of(context);
      app.player.playItem(item, volume: app.settings.playerVolume);
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AudioPlayerScreen()),
      );
    }
  }

  Widget _mediaContent(BuildContext context, ColorScheme cs) {
    final isVideo = item.kind == ItemKind.video;
    // Видео — с превью-кадром.
    if (isVideo) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          VideoThumb(item: item, onOpen: () => _openMedia(context, true)),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(item.fileName ?? tr(context).videoWord,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                _footer(cs),
              ],
            ),
          ),
        ],
      );
    }
    return InkWell(
      onTap: () => _openMedia(context, false),
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
                  Text(item.fileName ?? (isVideo ? tr(context).videoWord : tr(context).audioWord),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    '${isVideo ? tr(context).videoWord : tr(context).audioWord} · ${humanSize(item.fileSize)}',
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
                  Text(item.fileName ?? tr(context).fileWord,
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
              tooltip: tr(context).save,
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
          dialogTitle: tr(context).saveTitle,
          fileName: item.fileName ?? 'file',
          bytes: bytes,
        );
        messenger.showSnackBar(SnackBar(
            content: Text(path != null ? tr(context).saved : tr(context).cancelled)));
      } else {
        // Desktop: выбираем путь и копируем файл.
        final path = await FilePicker.platform.saveFile(
          dialogTitle: tr(context).saveTitle,
          fileName: item.fileName ?? 'file',
        );
        if (path == null) {
          messenger.showSnackBar(SnackBar(content: Text(tr(context).cancelled)));
          return;
        }
        await File(src).copy(path);
        messenger.showSnackBar(SnackBar(content: Text(tr(context).savedTo(path))));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(tr(context).saveError2('$e'))));
    }
  }

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: item.text ?? ''));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(tr(context).copied), duration: const Duration(seconds: 1)),
    );
  }

  void _openImage(BuildContext context, String path) {
    // Собираем все картинки ленты для свайпа между ними.
    final all = AppScope.of(context)
        .store
        .items
        .where((e) => e.kind == ItemKind.image && e.filePath != null)
        .toList()
        .reversed
        .toList();
    final idx = all.indexWhere((e) => e.id == item.id);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ImageGallery(
        images: all.isEmpty ? [item] : all,
        initialIndex: idx < 0 ? 0 : idx,
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
                      decoration: InputDecoration(
                        hintText: tr(context).newGroup,
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
                title: Text(tr(context).copy),
                onTap: () {
                  Navigator.pop(context);
                  _copy(context);
                },
              ),
            if (item.filePath != null)
              ListTile(
                leading: const Icon(Icons.open_in_new_rounded),
                title: Text(tr(context).open),
                onTap: () {
                  Navigator.pop(context);
                  OpenFilex.open(item.filePath!);
                },
              ),
            if (item.filePath != null)
              ListTile(
                leading: const Icon(Icons.download_rounded),
                title: Text(tr(context).saveAs),
                onTap: () {
                  Navigator.pop(context);
                  _saveAs(context);
                },
              ),
            ListTile(
              leading: Icon(item.pinned
                  ? Icons.push_pin
                  : Icons.push_pin_outlined),
              title: Text(item.pinned ? tr(context).unpin : tr(context).pin),
              onTap: () {
                Navigator.pop(context);
                AppScope.of(context).store.togglePin(item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(item.group == null
                  ? tr(context).addToGroup
                  : tr(context).groupName(item.group!)),
              onTap: () {
                Navigator.pop(context);
                _groupDialog(context);
              },
            ),
            if (item.group != null)
              ListTile(
                leading: const Icon(Icons.folder_off_outlined),
                title: Text(tr(context).removeFromGroup),
                onTap: () {
                  Navigator.pop(context);
                  AppScope.of(context).store.setGroup(item, null);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: Text(tr(context).delete),
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
