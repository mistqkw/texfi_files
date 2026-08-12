import 'dart:io';
import 'dart:ui' as ui;
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../l10n/app_strings.dart';
import 'audio_player_screen.dart';
import 'effects.dart';
import '../app.dart';
import '../app_state.dart';
import '../core/models.dart';
import '../core/offline_queue.dart';
import 'format.dart';
import 'item_bubble.dart';
import 'music_screen.dart';
import 'peers_page.dart';
import 'smooth_scroll.dart';
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
  String? _filter; // null=все, '__pinned__'=закреплённые, '__archive__'=архив, иначе имя группы
  bool _searching = false;
  final _search = TextEditingController();
  String _query = '';

  late AppState _app;
  AppStrings get t => AppStrings(_app.settings.effectiveLanguageCode);

  final _recorder = AudioRecorder();
  bool _recording = false;

  Future<void> _startRecord() async {
    try {
      if (!await _recorder.hasPermission()) {
        _toast(t.micDenied);
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      setState(() => _recording = true);
    } catch (e) {
      _toast(t.failed('$e'));
    }
  }

  Future<void> _stopRecord({bool cancel = false}) async {
    try {
      final path = await _recorder.stop();
      setState(() => _recording = false);
      if (cancel || path == null) return;
      final f = File(path);
      if (f.existsSync() && await f.length() > 0) {
        await _dispatchFile(f);
        _scrollToBottom();
      }
    } catch (e) {
      setState(() => _recording = false);
    }
  }

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
    _search.dispose();
    _recorder.dispose();
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

  // Самоуничтожение: null=выкл, иначе кол-во секунд до удаления.
  int? _ttlSeconds;
  bool _dragHover = false;
  static bool get _dragDropSupported =>
      Platform.isLinux || Platform.isWindows || Platform.isMacOS;

  Future<void> _sendText() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    final ttl = _ttlSeconds;
    if (_target != null) {
      final peer = _target!;
      final ok = await _app.sendTextTo(peer, text, ttlSeconds: ttl);
      if (!ok && mounted) {
        await _app.queue.enqueue(QueuedSend(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          peerId: peer.id,
          peerName: peer.name,
          kind: 'text',
          text: text,
          createdAt: DateTime.now(),
        ));
        _toast(t.queuedOffline(peer.name));
      }
    } else {
      await _app.saveTextLocal(text, ttlSeconds: ttl);
    }
    _scrollToBottom();
  }

  Future<void> _dispatchFile(File file) async {
    if (_target != null) {
      _showFileProgress(file);
    } else {
      await _saveFileLocal(file);
    }
  }

  // Меню вложений: Файлы / Галерея / Камера.
  void _attachMenu() {
    final mobile = Platform.isAndroid || Platform.isIOS;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: Text(t.files),
              onTap: () {
                Navigator.pop(context);
                _pickFiles();
              },
            ),
            if (mobile)
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(t.gallery),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            if (mobile)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(t.camera),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFiles() async {
    final res = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (res == null) return;
    for (final f in res.files) {
      if (f.path == null) continue;
      await _dispatchFile(File(f.path!));
    }
    _scrollToBottom();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final x = await ImagePicker().pickImage(source: source, imageQuality: 95);
      if (x == null) return;
      await _dispatchFile(File(x.path));
      _scrollToBottom();
    } catch (e) {
      _toast(t.failed('$e'));
    }
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
      expiresAt: _ttlSeconds != null
          ? DateTime.now().add(Duration(seconds: _ttlSeconds!))
          : null,
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
    final ttl = _ttlSeconds;
    _app.sendFileTo(peer, file, ttlSeconds: ttl).listen(
      (p) => progress.value = p,
      onDone: () {
        entry.close();
        _toast(t.sentName(name));
        // Записываем в свою ленту как исходящее.
        _app.store.add(SavedItem(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          kind: kindFromMime(null, name),
          fileName: name,
          fileSize: file.lengthSync(),
          createdAt: DateTime.now(),
          outgoing: true,
          fromName: peer.name,
          expiresAt:
              ttl != null ? DateTime.now().add(Duration(seconds: ttl)) : null,
        ));
      },
      onError: (e) async {
        entry.close();
        // Пир пропал во время передачи — сохраняем копию и кладём в очередь.
        try {
          final copy = _app.store.newFileFor(name);
          await file.copy(copy.path);
          await _app.queue.enqueue(QueuedSend(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            peerId: peer.id,
            peerName: peer.name,
            kind: 'file',
            filePath: copy.path,
            createdAt: DateTime.now(),
          ));
          _toast(t.queuedOffline(peer.name));
        } catch (_) {
          _toast(t.sendError(name));
        }
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
      listenable:
          Listenable.merge([_app, _app.store, _app.discovery, _app.auth]),
      builder: (context, _) {
        // авто-выбор адресата
        _target ??= _app.preferredPeer;
        if (_target != null &&
            !_app.peers.any((p) => p.id == _target!.id && p.online)) {
          _target = _app.preferredPeer;
        }
        final all = _app.store.items;
        final items = _applyFilter(all);
        final cs = Theme.of(context).colorScheme;
        final scaffold = Scaffold(
          appBar: _appBar(context),
          body: Column(
            children: [
              if (_searching) _searchBar(context),
              _filterBar(context),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(child: _bgLayer(cs)),
                    // Снег/дождь — ЗА сообщениями (между фоном и лентой).
                    if (_app.settings.weather != 0)
                      Positioned.fill(
                        child: WeatherOverlay(
                          type: _app.settings.weather,
                          sizeScale: _app.settings.weatherSize,
                          density: _app.settings.weatherDensity,
                          speedScale: _app.settings.weatherSpeed,
                        ),
                      ),
                    Positioned.fill(
                      child:
                          items.isEmpty ? _empty(context) : _timeline(items),
                    ),
                    if (_dragHover)
                      Positioned.fill(
                        child: Container(
                          color: cs.primary.withValues(alpha: 0.12),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 16),
                              decoration: BoxDecoration(
                                color: cs.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: cs.primary, width: 2),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.file_download_outlined,
                                      color: cs.primary),
                                  const SizedBox(width: 8),
                                  Text(t.dropFilesHere),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const MiniPlayer(),
              _inputBar(context),
            ],
          ),
        );
        if (!_dragDropSupported) return scaffold;
        return DropTarget(
          onDragEntered: (_) => setState(() => _dragHover = true),
          onDragExited: (_) => setState(() => _dragHover = false),
          onDragDone: (details) async {
            setState(() => _dragHover = false);
            for (final f in details.files) {
              await _dispatchFile(File(f.path));
            }
            _scrollToBottom();
          },
          child: scaffold,
        );
      },
    );
  }

  PreferredSizeWidget _appBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final online = _app.peers.where((p) => p.online).length;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AppBar(
      titleSpacing: 12,
      toolbarHeight: 60,
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(
            dark
                ? 'assets/brand/logo-horizontal-white.png'
                : 'assets/brand/logo-horizontal.png',
            height: 18,
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
            errorBuilder: (_, __, ___) => Image.asset(
                'assets/brand/logo-horizontal-white.png',
                height: 18),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text('files',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurfaceVariant,
                  )),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: t.searchHint,
          icon: const Icon(Icons.search_rounded, size: 22),
          onPressed: () => setState(() => _searching = !_searching),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: t.ttDevices,
          icon: Badge(
            isLabelVisible: online > 0,
            label: Text('$online'),
            child: const Icon(Icons.devices_rounded, size: 22),
          ),
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const PeersPage())),
        ),
        PopupMenuButton<int>(
          tooltip: '',
          icon: const Icon(Icons.more_vert_rounded, size: 22),
          onSelected: (v) {
            final page = switch (v) {
              0 => const MusicScreen(),
              1 => const RemoteKeyboardPage(),
              _ => const SettingsPage(),
            };
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => page));
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 0,
              child: Row(children: [
                const Icon(Icons.library_music_outlined, size: 20),
                const SizedBox(width: 12),
                Text(t.music),
              ]),
            ),
            PopupMenuItem(
              value: 1,
              child: Row(children: [
                const Icon(Icons.keyboard_alt_outlined, size: 20),
                const SizedBox(width: 12),
                Text(t.ttKeyboard),
              ]),
            ),
            PopupMenuItem(
              value: 2,
              child: Row(children: [
                const Icon(Icons.settings_outlined, size: 20),
                const SizedBox(width: 12),
                Text(t.ttSettings),
              ]),
            ),
          ],
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(18),
        child: Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              !_app.auth.isLoggedIn
                  ? t.signInPrompt
                  : online > 0
                      ? t.devicesInAccount(online)
                      : t.searchingDevices,
              style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bgLayer(ColorScheme cs) {
    final s = _app.settings;
    final path = s.chatBgImage;
    if (path != null && File(path).existsSync()) {
      Widget img;
      if (s.bgEffect == 2) {
        // Пиксели: маленький кэш + без сглаживания.
        img = Image.file(File(path),
            fit: BoxFit.cover,
            cacheWidth: 48,
            filterQuality: FilterQuality.none);
      } else {
        img = Image.file(File(path), fit: BoxFit.cover);
        if (s.bgEffect == 1) {
          img = ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: img,
          );
        }
      }
      return Stack(fit: StackFit.expand, children: [
        img,
        Container(color: Colors.black.withValues(alpha: s.bgDim)),
      ]);
    }
    if (s.chatBackground == 1) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              cs.primary.withValues(alpha: 0.06),
              cs.surface,
              cs.tertiary.withValues(alpha: 0.05),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  List<SavedItem> _applyFilter(List<SavedItem> items) {
    List<SavedItem> base;
    if (_filter == '__archive__') {
      base = items.where((e) => e.archived).toList();
    } else if (_filter == '__pinned__') {
      base = items.where((e) => e.pinned && !e.archived).toList();
    } else if (_filter == null) {
      base = items.where((e) => !e.archived).toList();
    } else {
      base = items.where((e) => e.group == _filter && !e.archived).toList();
    }
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return base;
    return base
        .where((e) =>
            (e.text ?? '').toLowerCase().contains(q) ||
            (e.fileName ?? '').toLowerCase().contains(q))
        .toList();
  }

  Widget _searchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      child: TextField(
        controller: _search,
        autofocus: true,
        onChanged: (v) => setState(() => _query = v),
        decoration: InputDecoration(
          isDense: true,
          hintText: t.searchHint,
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => setState(() {
              _searching = false;
              _query = '';
              _search.clear();
            }),
          ),
        ),
      ),
    );
  }

  Widget _filterBar(BuildContext context) {
    final groups = _app.store.groups;
    final hasPinned = _app.store.items.any((e) => e.pinned && !e.archived);
    final hasArchived = _app.store.items.any((e) => e.archived);
    if (groups.isEmpty && !hasPinned && !hasArchived) {
      return const SizedBox.shrink();
    }
    // сбросить фильтр, если группа исчезла
    if (_filter != null &&
        _filter != '__pinned__' &&
        _filter != '__archive__' &&
        !groups.contains(_filter)) {
      _filter = null;
    }
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        children: [
          _filterChip(context, label: t.all, value: null, icon: Icons.apps_rounded),
          if (hasPinned)
            _filterChip(context,
                label: t.pinned,
                value: '__pinned__',
                icon: Icons.push_pin_rounded),
          if (hasArchived)
            _filterChip(context,
                label: t.archived,
                value: '__archive__',
                icon: Icons.archive_rounded),
          for (final g in groups)
            _filterChip(context,
                label: g, value: g, icon: Icons.folder_rounded),
        ],
      ),
    );
  }

  Widget _filterChip(BuildContext context,
      {required String label, required String? value, required IconData icon}) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        avatar: Icon(icon, size: 16),
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = value),
        visualDensity: VisualDensity.compact,
      ),
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
          Text(t.emptyTitle,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              t.emptyText,
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
    return SmoothScroll(
      controller: _scroll,
      builder: (physics) => ListView.builder(
        controller: _scroll,
        physics: physics,
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
            _SwipeRow(
              itemId: item.id,
              onShare: () => shareItem(item),
              onDelete: () => _app.store.remove(item),
              child: ItemBubble(
                item: item,
                onDelete: () => _app.store.remove(item),
              ),
            ),
          ],
        );
        return animate
            ? _Entrance(
                style: _app.settings.animStyle,
                durationMs: _app.settings.animDurationMs,
                child: row)
            : row;
        },
      ),
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
        child: Text(daySeparator(dt, t),
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      ),
    );
  }

  Widget _inputBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
        decoration: BoxDecoration(
          color: cs.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _targetSelector(context),
            const SizedBox(height: 6),
            _recording
                ? _recordingRow(cs)
                : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  onPressed: _attachMenu,
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(24),
                      border: _ttlSeconds != null
                          ? Border.all(color: cs.primary, width: 1.2)
                          : null,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _input,
                            minLines: 1,
                            maxLines: 5,
                            textInputAction: TextInputAction.newline,
                            decoration: InputDecoration(
                              hintText: t.messageHint,
                              filled: false,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.fromLTRB(
                                  18, 12, 4, 12),
                            ),
                          ),
                        ),
                        if (_ttlSeconds != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 4, bottom: 6),
                            child: Icon(Icons.timer_rounded,
                                size: 16, color: cs.primary),
                          ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.mic_rounded),
                          onPressed: _startRecord,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onLongPress: _pickTtl,
                  child: FloatingActionButton.small(
                    elevation: 0,
                    tooltip: t.selfDestruct,
                    backgroundColor:
                        _ttlSeconds != null ? cs.primary : null,
                    onPressed: _sendText,
                    child: const Icon(Icons.send_rounded),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _pickTtl() {
    const options = <int?>[null, 60, 3600, 86400, 604800];
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            for (final v in options)
              ListTile(
                leading: Icon(v == null
                    ? Icons.timer_off_outlined
                    : Icons.timer_outlined),
                title: Text(_ttlLabel(v)),
                trailing: _ttlSeconds == v
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () {
                  setState(() => _ttlSeconds = v);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  String _ttlLabel(int? v) => switch (v) {
        null => t.ttlOff,
        60 => t.ttl1m,
        3600 => t.ttl1h,
        86400 => t.ttl1d,
        604800 => t.ttl1w,
        _ => '$v s',
      };

  Widget _recordingRow(ColorScheme cs) {
    return Row(
      children: [
        const SizedBox(width: 10),
        const _PulsingMic(),
        const SizedBox(width: 12),
        Expanded(
          child: Text(t.recording,
              style: TextStyle(color: cs.onSurfaceVariant)),
        ),
        IconButton(
          tooltip: t.cancel,
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: () => _stopRecord(cancel: true),
        ),
        const SizedBox(width: 4),
        FloatingActionButton.small(
          elevation: 0,
          onPressed: () => _stopRecord(),
          child: const Icon(Icons.send_rounded),
        ),
      ],
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
            label: t.saveHere,
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

/// Пульсирующий красный микрофон при записи голосового.
class _PulsingMic extends StatefulWidget {
  const _PulsingMic();
  @override
  State<_PulsingMic> createState() => _PulsingMicState();
}

class _PulsingMicState extends State<_PulsingMic>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.4, end: 1.0).animate(_c),
      child: const Icon(Icons.mic_rounded, color: Colors.red),
    );
  }
}

/// Плавное появление нового элемента ленты. Стиль и скорость — из настроек.
class _Entrance extends StatefulWidget {
  final Widget child;
  final int style; // 0=fade,1=подъём,2=масштаб,3=подъём+fade
  final int durationMs;
  const _Entrance(
      {required this.child, required this.style, required this.durationMs});

  @override
  State<_Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<_Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.durationMs),
  )..forward();
  late final Animation<double> _curve =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = FadeTransition(opacity: _curve, child: widget.child);
    switch (widget.style) {
      case 0: // только fade
        return fade;
      case 1: // подъём
        return SlideTransition(
          position: Tween(begin: const Offset(0, 0.14), end: Offset.zero)
              .animate(_curve),
          child: widget.child,
        );
      case 2: // масштаб
        return ScaleTransition(
          scale: Tween(begin: 0.85, end: 1.0).animate(_curve),
          child: fade,
        );
      default: // подъём + fade
        return SlideTransition(
          position: Tween(begin: const Offset(0, 0.12), end: Offset.zero)
              .animate(_curve),
          child: fade,
        );
    }
  }
}

/// Пузырь со свайпом: плавно нарастающая иконка/фон по мере перетаскивания
/// (вправо — переслать, влево — удалить), лёгкая вибро-отдача на пороге.
class _SwipeRow extends StatefulWidget {
  final String itemId;
  final Widget child;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  const _SwipeRow({
    required this.itemId,
    required this.child,
    required this.onShare,
    required this.onDelete,
  });

  @override
  State<_SwipeRow> createState() => _SwipeRowState();
}

class _SwipeRowState extends State<_SwipeRow> {
  double _progress = 0; // -1..1 (влево..вправо)
  bool _reached = false;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('dismiss_${widget.itemId}'),
      direction: DismissDirection.horizontal,
      onUpdate: (details) {
        final signed = details.direction == DismissDirection.endToStart
            ? -details.progress
            : details.progress;
        if (details.reached && !_reached) HapticFeedback.lightImpact();
        setState(() {
          _progress = signed;
          _reached = details.reached;
        });
      },
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          widget.onShare();
          setState(() => _progress = 0);
          return false; // переслать — не удаляет
        }
        return true; // влево — удалить
      },
      onDismissed: (_) => widget.onDelete(),
      background: _swipeReveal(
        align: Alignment.centerLeft,
        icon: Icons.reply_rounded,
        label: tr(context).share,
        color: Colors.blue,
        progress: _progress.clamp(0, 1),
      ),
      secondaryBackground: _swipeReveal(
        align: Alignment.centerRight,
        icon: Icons.delete_outline_rounded,
        label: tr(context).delete,
        color: Colors.red,
        progress: (-_progress).clamp(0, 1),
      ),
      child: widget.child,
    );
  }

  Widget _swipeReveal({
    required Alignment align,
    required IconData icon,
    required String label,
    required Color color,
    required double progress,
  }) {
    final scale = 0.6 + (progress.clamp(0, 1) * 0.7);
    return Container(
      alignment: align,
      padding: const EdgeInsets.symmetric(horizontal: 26),
      color: color.withValues(alpha: 0.10 + progress * 0.10),
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontSize: 10.5)),
          ],
        ),
      ),
    );
  }
}
