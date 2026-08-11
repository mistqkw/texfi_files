import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../app.dart';
import '../app_state.dart';
import '../core/models.dart';
import 'format.dart';
import 'item_bubble.dart';
import 'peers_page.dart';
import 'remote_keyboard_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final Set<String> _seen = {}; // элементы, уже проигравшие анимацию появления
  Peer? _target; // null = сохранить локально

  late AppState _app;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _app = AppScope.of(context);
    if (_seen.isEmpty) {
      // Историю при первом открытии не анимируем — только новые сообщения.
      for (final it in _app.store.items) {
        _seen.add(it.id);
      }
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut);
      }
    });
  }

  Future<void> _sendText() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    if (_target != null) {
      final ok = await _app.sendTextTo(_target!, text);
      if (!ok && mounted) {
        _toast('Не удалось отправить на ${_target!.name}');
      }
    } else {
      await _app.saveTextLocal(text);
    }
    _scrollToBottom();
  }

  Future<void> _pickAndSendFiles() async {
    final res = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (res == null) return;
    for (final f in res.files) {
      if (f.path == null) continue;
      final file = File(f.path!);
      if (_target != null) {
        _showFileProgress(file);
      } else {
        // Локальное сохранение: копируем в хранилище.
        await _saveFileLocal(file);
      }
    }
    _scrollToBottom();
  }

  Future<void> _saveFileLocal(File file) async {
    final name = file.uri.pathSegments.last;
    final target = _app.store.newFileFor(name);
    await file.copy(target.path);
    final size = await target.length();
    await _app.store.add(SavedItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      kind: kindFromMime(null, name),
      filePath: target.path,
      fileName: name,
      fileSize: size,
      createdAt: DateTime.now(),
      outgoing: true,
    ));
  }

  void _showFileProgress(File file) {
    final peer = _target!;
    final name = file.uri.pathSegments.last;
    final progress = ValueNotifier<double>(0);
    final entry = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(minutes: 10),
        content: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (_, v, __) => Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('→ $name (${(v * 100).toStringAsFixed(0)}%)'),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(value: v == 0 ? null : v),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    _app.sendFileTo(peer, file).listen(
      (p) => progress.value = p,
      onDone: () {
        entry.close();
        _toast('Отправлено: $name');
        // Записываем в свою ленту как исходящее.
        _app.store.add(SavedItem(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          kind: kindFromMime(null, name),
          fileName: name,
          fileSize: file.lengthSync(),
          createdAt: DateTime.now(),
          outgoing: true,
          fromName: peer.name,
        ));
      },
      onError: (e) {
        entry.close();
        _toast('Ошибка отправки $name');
      },
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_app, _app.store, _app.discovery]),
      builder: (context, _) {
        // авто-выбор адресата
        _target ??= _app.preferredPeer;
        if (_target != null &&
            !_app.peers.any((p) => p.id == _target!.id && p.online)) {
          _target = _app.preferredPeer;
        }
        final items = _app.store.items;
        final cs = Theme.of(context).colorScheme;
        final gradient = _app.settings.chatBackground == 1
            ? BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    cs.primary.withValues(alpha: 0.06),
                    cs.surface,
                    cs.tertiary.withValues(alpha: 0.05),
                  ],
                ),
              )
            : null;
        return Scaffold(
          appBar: _appBar(context),
          body: Column(
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: gradient ?? const BoxDecoration(),
                  child: items.isEmpty ? _empty(context) : _timeline(items),
                ),
              ),
              _inputBar(context),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _appBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final online = _app.peers.where((p) => p.online).length;
    return AppBar(
      titleSpacing: 16,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TexFi files',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
          Text(
            online > 0 ? '$online устройств рядом' : 'Ищу устройства…',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Клавиатура на ПК',
          icon: const Icon(Icons.keyboard_alt_outlined),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const RemoteKeyboardPage())),
        ),
        IconButton(
          tooltip: 'Устройства',
          icon: Badge(
            isLabelVisible: online > 0,
            label: Text('$online'),
            child: const Icon(Icons.devices_rounded),
          ),
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const PeersPage())),
        ),
        IconButton(
          tooltip: 'Настройки',
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const SettingsPage())),
        ),
      ],
    );
  }

  Widget _empty(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bookmark_rounded, size: 72, color: cs.primary),
          const SizedBox(height: 16),
          const Text('Ваше «Избранное»',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Отправляйте сюда текст и файлы любого размера. '
              'Выберите устройство рядом или сохраните локально.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeline(List<SavedItem> items) {
    // items идут от новых к старым (store.items = reversed). Развернём для ленты.
    final ordered = items.reversed.toList();
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(vertical: 10),
      itemCount: ordered.length,
      itemBuilder: (context, i) {
        final item = ordered[i];
        final showDay = i == 0 ||
            !_sameDay(ordered[i - 1].createdAt, item.createdAt);
        final animate = _app.settings.animations && !_seen.contains(item.id);
        _seen.add(item.id);
        final row = Column(
          key: ValueKey(item.id),
          children: [
            if (showDay) _dayChip(context, item.createdAt),
            ItemBubble(
              item: item,
              onDelete: () => _app.store.remove(item),
            ),
          ],
        );
        return animate ? _Entrance(child: row) : row;
      },
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _dayChip(BuildContext context, DateTime dt) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(daySeparator(dt),
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      ),
    );
  }

  Widget _inputBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outlineVariant, width: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _targetSelector(context),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file_rounded),
                  onPressed: _pickAndSendFiles,
                ),
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      hintText: 'Сообщение или текст для копирования…',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                FloatingActionButton.small(
                  elevation: 0,
                  onPressed: _sendText,
                  child: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _targetSelector(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final peers = _app.peers.where((p) => p.online).toList();
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _targetChip(
            context,
            label: 'Сохранить здесь',
            icon: Icons.bookmark_border_rounded,
            selected: _target == null,
            onTap: () => setState(() => _target = null),
            color: cs,
          ),
          for (final p in peers)
            _targetChip(
              context,
              label: p.name,
              icon: p.platform == 'android'
                  ? Icons.smartphone_rounded
                  : Icons.laptop_rounded,
              selected: _target?.id == p.id,
              onTap: () => setState(() => _target = p),
              color: cs,
            ),
        ],
      ),
    );
  }

  Widget _targetChip(BuildContext context,
      {required String label,
      required IconData icon,
      required bool selected,
      required VoidCallback onTap,
      required ColorScheme color}) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: ChoiceChip(
        avatar: Icon(icon,
            size: 16,
            color: selected ? color.onSecondaryContainer : color.onSurface),
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

/// Плавное появление нового элемента ленты: fade + лёгкий подъём.
class _Entrance extends StatefulWidget {
  final Widget child;
  const _Entrance({required this.child});

  @override
  State<_Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<_Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  )..forward();
  late final Animation<double> _fade =
      CurvedAnimation(parent: _c, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.12),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
