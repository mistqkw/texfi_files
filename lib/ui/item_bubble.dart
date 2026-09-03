import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../app.dart';
import '../core/models.dart';
import '../core/settings.dart';
import '../l10n/app_strings.dart';
import 'album_art.dart';
import 'audio_player_screen.dart';
import 'format.dart';
import 'image_gallery.dart';
import 'pixel/pixel_icons.dart';
import 'player_page.dart';
import 'terminal.dart';
import 'video_thumb.dart';

class ItemBubble extends StatelessWidget {
  final SavedItem item;
  final VoidCallback onDelete;
  const ItemBubble({super.key, required this.item, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = AppScope.of(context).settings;
    // Пиксель-карточка: чёрный блок с белой рамкой и врезанной подписью.
    return Container(
      // Тянемся на всю ширину: внешний Column ленты центрирует детей, и без
      // этого блоки вставали бы по центру вместо краёв.
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: s.compact ? 4 : 7,
        horizontal: 12,
      ),
      child: Column(
        crossAxisAlignment: item.outgoing
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstraintsBox(
            child: IntrinsicWidth(
              child: GestureDetector(
                onLongPressStart: (d) => _menu(context, d.globalPosition),
                onSecondaryTapUp: (d) => _menu(context, d.globalPosition),
                child: TerminalBox(
                  label: _prefixLabel(s),
                  // Белая обводка на чёрном блоке — основа стиля.
                  borderColor: Colors.white.withValues(
                    alpha: s.borderOpacity,
                  ),
                  labelColor: item.outgoing
                      ? cs.primary
                      : cs.onSurfaceVariant,
                  padding: _framePadding,
                  child: _content(context, cs),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 5, left: 3, right: 3),
            child: _meta(context, cs),
          ),
        ],
      ),
    );
  }

  /// Превью аудио: настоящая обложка из тегов, если она есть, иначе
  /// заглушка — тонкая рамка с иконкой.
  Widget _mediaThumb(BuildContext context, ColorScheme cs, bool isVideo) {
    final name = isVideo ? 'play' : 'volume';
    final fallback = Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        border: Border.all(color: cs.primary.withValues(alpha: 0.5)),
      ),
      child: Center(child: PixelIcon(name, size: 26, color: cs.primary)),
    );
    if (isVideo) return fallback;
    return AlbumArtThumb(
      filePath: item.filePath,
      size: 52,
      radius: 0,
      fallback: fallback,
    );
  }

  /// Медиа занимает всю ширину блока — внутренних отступов почти не даём.
  EdgeInsets get _framePadding =>
      (item.kind == ItemKind.image || item.kind == ItemKind.video)
      ? const EdgeInsets.all(4)
      // Отступы даёт само содержимое — иначе у текста был бы двойной.
      : EdgeInsets.zero;

  /// Содержимое врезки в верхней линии рамки: устройство · тип · размер · время.
  String _prefixLabel(Settings s) {
    final parts = <String>[];
    if (s.prefixDevice) {
      final name = item.fromName ?? (item.outgoing ? s.deviceName : null);
      if (name != null && name.trim().isNotEmpty) {
        parts.add(name.trim().toLowerCase());
      }
    }
    if (s.prefixType) parts.add(_typeTag);
    if (s.prefixSize && item.fileSize > 0) parts.add(humanSize(item.fileSize));
    if (s.prefixTime) parts.add(clockTime(item.createdAt));
    return parts.join(' · ');
  }

  String get _typeTag => switch (item.kind) {
    ItemKind.text => 'txt',
    ItemKind.image => 'img',
    ItemKind.audio => 'aud',
    ItemKind.video => 'vid',
    ItemKind.voice => 'voc',
    ItemKind.file => 'file',
  };

  /// Служебная строка под блоком: время и статусные иконки, моноширинно.
  Widget _meta(BuildContext context, ColorScheme cs) {
    final dim = cs.onSurfaceVariant.withValues(alpha: 0.7);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(clockTime(item.createdAt), style: monoStyle(color: dim, size: 10)),
        if (item.group != null) ...[
          const SizedBox(width: 6),
          PixelIcon('link', size: 11, color: dim),
        ],
        if (item.pinned) ...[
          const SizedBox(width: 6),
          PixelIcon('drop', size: 11, color: cs.primary),
        ],
        if (item.archived) ...[
          const SizedBox(width: 6),
          PixelIcon('picture', size: 11, color: dim),
        ],
        const SizedBox(width: 6),
        PixelIcon(item.cloud ? 'cloud' : 'devices', size: 11, color: item.cloud ? cs.primary : dim),
        if (item.expiresAt != null) ...[
          const SizedBox(width: 6),
          PixelIcon('clock', size: 11, color: cs.error),
          const SizedBox(width: 2),
          Text(_ttlLeft(item.expiresAt!),
              style: monoStyle(color: cs.error, size: 10)),
        ],
        _moreButton(context, dim),
      ],
    );
  }

  /// Явная точка входа в меню (архив/группа/пин/удаление), не завязанная на
  /// долгое нажатие — на строке сообщения оно конкурирует с горизонтальным
  /// свайпом-удалением/пересылкой в одной и той же жестовой арене Flutter
  /// (оба висят на одной и той же области), из-за чего долгий тап иногда
  /// не срабатывает. Обычный короткий тап по этой иконке — надёжен всегда.
  Widget _moreButton(BuildContext context, Color color) {
    return GestureDetector(
      onTapUp: (d) => _menu(context, d.globalPosition),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(left: 6),
        child: PixelIcon('menu', size: 14, color: color),
      ),
    );
  }

  Widget _content(BuildContext context, ColorScheme cs) {
    if (item.receiving) return _receivingContent(context, cs);
    if (item.cloud && item.filePath == null && item.remotePath != null) {
      return _notDownloadedContent(context, cs);
    }
    switch (item.kind) {
      case ItemKind.text:
        return _textContent(context, cs);
      case ItemKind.image:
        return _imageContent(context, cs);
      case ItemKind.audio:
      case ItemKind.video:
        return _mediaContent(context, cs);
      case ItemKind.voice:
        return _voiceContent(context, cs);
      case ItemKind.file:
        return _fileContent(context, cs);
    }
  }

  Widget _notDownloadedContent(BuildContext context, ColorScheme cs) {
    final t = tr(context);
    return _DownloadTile(item: item, cs: cs, t: t);
  }

  Widget _receivingContent(BuildContext context, ColorScheme cs) {
    final t = tr(context);
    final expected = item.expectedSize;
    final progress = expected > 0
        ? (item.fileSize / expected).clamp(0.0, 1.0)
        : null;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(value: progress, strokeWidth: 3),
                PixelIcon('sync', size: 18, color: cs.primary),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.fileName ?? t.fileWord,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  expected > 0
                      ? '${humanSize(item.fileSize)} / ${humanSize(expected)}'
                      : '${humanSize(item.fileSize)} · ${t.receivingLabel}',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _ttlLeft(DateTime at) {
    final left = at.difference(DateTime.now());
    if (left.isNegative) return '0s';
    if (left.inDays > 0) return '${left.inDays}d';
    if (left.inHours > 0) return '${left.inHours}h';
    if (left.inMinutes > 0) return '${left.inMinutes}m';
    return '${left.inSeconds}s';
  }

  Widget _textContent(BuildContext context, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SelectableText(
            item.text ?? '',
            style: const TextStyle(fontSize: 15, height: 1.3),
          ),
          _textActions(context, cs),
        ],
      ),
    );
  }

  /// Кнопки «копировать/переслать» под текстом — проявляются при наведении
  /// мышью, на телефоне скрыты (там есть долгое нажатие и свайп).
  Widget _textActions(BuildContext context, ColorScheme cs) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => _copy(context),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: PixelIcon('copy', size: 13, color: cs.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: 2),
        InkWell(
          onTap: _share,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: PixelIcon('send', size: 13, color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
    return Align(
      alignment: Alignment.centerLeft,
      child: _HoverReveal(child: row),
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
                child: Text(
                  item.fileName ?? tr(context).imageWord,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openMedia(BuildContext context, bool isVideo) {
    if (isVideo) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => PlayerPage(item: item)));
    } else {
      final app = AppScope.of(context);
      app.player.playItem(item, volume: app.settings.playerVolume);
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const AudioPlayerScreen()));
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
                  child: Text(
                    item.fileName ?? tr(context).videoWord,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
            _mediaThumb(context, cs, isVideo),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.fileName ??
                        (isVideo
                            ? tr(context).videoWord
                            : tr(context).audioWord),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${isVideo ? tr(context).videoWord : tr(context).audioWord} · ${humanSize(item.fileSize)}',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _voiceContent(BuildContext context, ColorScheme cs) {
    return InkWell(
      onTap: () {
        final app = AppScope.of(context);
        app.player.playItem(item, volume: app.settings.playerVolume);
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AudioPlayerScreen()));
      },
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.primary,
                shape: BoxShape.circle,
              ),
              child: PixelIcon('mic', color: cs.onPrimary, size: 24),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr(context).voiceMessage,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  humanSize(item.fileSize),
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
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
              child: PixelIcon('file',
                color: cs.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.fileName ?? tr(context).fileWord,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    humanSize(item.fileSize),
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: tr(context).save,
              icon: PixelIcon('sync'),
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
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              path != null ? tr(context).saved : tr(context).cancelled,
            ),
          ),
        );
      } else {
        // Desktop: выбираем путь и копируем файл.
        final path = await FilePicker.platform.saveFile(
          dialogTitle: tr(context).saveTitle,
          fileName: item.fileName ?? 'file',
        );
        if (path == null) {
          messenger.showSnackBar(
            SnackBar(content: Text(tr(context).cancelled)),
          );
          return;
        }
        await File(src).copy(path);
        messenger.showSnackBar(
          SnackBar(content: Text(tr(context).savedTo(path))),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(tr(context).saveError2('$e'))),
      );
    }
  }

  Future<void> _share() => shareItem(item);

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: item.text ?? ''));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr(context).copied),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _openImage(BuildContext context, String path) {
    // Собираем все картинки ленты для свайпа между ними.
    final all = AppScope.of(context).store.items
        .where((e) => e.kind == ItemKind.image && e.filePath != null)
        .toList()
        .reversed
        .toList();
    final idx = all.indexWhere((e) => e.id == item.id);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImageGallery(
          images: all.isEmpty ? [item] : all,
          initialIndex: idx < 0 ? 0 : idx,
        ),
      ),
    );
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
                leading: PixelIcon('folder'),
                title: Text(g),
                trailing: item.group == g ? PixelIcon('check') : null,
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
                        prefixIcon: PixelIcon('folder'),
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

  /// Контекстное меню — маленькое всплывающее окно возле точки нажатия
  /// (долгий тап на мобильном, правый клик на десктопе), с фирменной
  /// scale+fade анимацией самого `showMenu`. Раньше это была полноэкранная
  /// шторка снизу — она перекрывала половину экрана и не «якорилась» к
  /// сообщению.
  Future<void> _menu(BuildContext context, Offset globalPos) async {
    final t = tr(context);
    final store = AppScope.of(context).store;
    final cs = Theme.of(context).colorScheme;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromLTWH(globalPos.dx, globalPos.dy, 40, 40),
      Offset.zero & overlay.size,
    );

    PopupMenuItem<_MenuAction> tile(
      _MenuAction value,
      String icon,
      String label, {
      bool danger = false,
    }) {
      final color = danger ? cs.error : cs.onSurface;
      return PopupMenuItem<_MenuAction>(
        value: value,
        height: 44,
        child: Row(
          children: [
            PixelIcon(icon, size: 16, color: danger ? cs.error : cs.onSurfaceVariant),
            const SizedBox(width: 14),
            Text(label, style: TextStyle(color: color)),
          ],
        ),
      );
    }

    final action = await showMenu<_MenuAction>(
      context: context,
      position: position,
      elevation: 0,
      color: Colors.black,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
      ),
      items: [
        if (item.kind == ItemKind.text)
          tile(_MenuAction.copy, 'copy', t.copy),
        if (item.filePath != null)
          tile(_MenuAction.open, 'link', t.open),
        if (item.filePath != null)
          tile(_MenuAction.saveAs, 'sync', t.saveAs),
        tile(_MenuAction.share, 'send', t.share),
        tile(
          _MenuAction.pin,
          'thumbtack',
          item.pinned ? t.unpin : t.pin,
        ),
        tile(
          _MenuAction.archive,
          'archive',
          item.archived ? t.unarchive : t.archive,
        ),
        tile(
          _MenuAction.group,
          'folder',
          item.group == null ? t.addToGroup : t.groupName(item.group!),
        ),
        if (item.group != null)
          tile(_MenuAction.ungroup, 'folder', t.removeFromGroup),
        tile(_MenuAction.delete, 'trash', t.delete, danger: true),
      ],
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _MenuAction.copy:
        _copy(context);
      case _MenuAction.open:
        if (item.filePath != null) OpenFilex.open(item.filePath!);
      case _MenuAction.saveAs:
        _saveAs(context);
      case _MenuAction.share:
        _share();
      case _MenuAction.pin:
        store.togglePin(item);
      case _MenuAction.archive:
        store.toggleArchive(item);
      case _MenuAction.group:
        _groupDialog(context);
      case _MenuAction.ungroup:
        store.setGroup(item, null);
      case _MenuAction.delete:
        onDelete();
    }
  }
}

enum _MenuAction {
  copy,
  open,
  saveAs,
  share,
  pin,
  archive,
  group,
  ungroup,
  delete,
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

/// Плитка «не скачано» для элементов, пропущенных избирательной
/// синхронизацией — скачивает содержимое из облака по тапу.
class _DownloadTile extends StatefulWidget {
  final SavedItem item;
  final ColorScheme cs;
  final AppStrings t;
  const _DownloadTile({required this.item, required this.cs, required this.t});

  @override
  State<_DownloadTile> createState() => _DownloadTileState();
}

class _DownloadTileState extends State<_DownloadTile> {
  bool _loading = false;

  Future<void> _download(BuildContext context) async {
    setState(() => _loading = true);
    final ok = await AppScope.of(context).cloud.downloadNow(widget.item);
    if (mounted) setState(() => _loading = false);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.t.downloadFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final item = widget.item;
    return InkWell(
      onTap: _loading ? null : () => _download(context),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: _loading
                  ? const CircularProgressIndicator(strokeWidth: 3)
                  : Container(
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: PixelIcon('cloud',
                        color: cs.onPrimaryContainer,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.fileName ?? widget.t.fileWord,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    _loading
                        ? widget.t.downloading
                        : '${humanSize(item.fileSize)} · ${widget.t.download}',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Отправить элемент через системное меню «Поделиться» (шэринг в другие
/// приложения — Telegram и т.д.). Переиспользуется из меню пузыря и из
/// свайп-жеста.
Future<void> shareItem(SavedItem item) async {
  try {
    if (item.kind == ItemKind.text) {
      await Share.share(item.text ?? '');
    } else if (item.filePath != null) {
      await Share.shareXFiles([XFile(item.filePath!)]);
    }
  } catch (_) {}
}

/// Показывает содержимое только при наведении курсора. На сенсорных
/// устройствах события наведения не приходят, поэтому там оно остаётся
/// скрытым — и блок сообщения выглядит чистым.
class _HoverReveal extends StatefulWidget {
  final Widget child;
  const _HoverReveal({required this.child});

  @override
  State<_HoverReveal> createState() => _HoverRevealState();
}

class _HoverRevealState extends State<_HoverReveal> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedOpacity(
        opacity: _hover ? 1 : 0,
        duration: const Duration(milliseconds: 140),
        // IgnorePointer в невидимом состоянии, чтобы скрытые кнопки не ловили
        // случайные нажатия.
        child: IgnorePointer(ignoring: !_hover, child: widget.child),
      ),
    );
  }
}
