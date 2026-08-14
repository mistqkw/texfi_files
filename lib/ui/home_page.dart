import 'dart:io';
import 'dart:ui' as ui;
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter/services.dart'
    show HapticFeedback, SystemUiOverlayStyle;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../l10n/app_strings.dart';
import 'effects.dart';
import 'floating_player.dart';
import '../app.dart';
import '../app_state.dart';
import '../core/models.dart';
import '../core/offline_queue.dart';
import 'format.dart';
import 'item_bubble.dart';
import 'music_screen.dart';
import 'peers_page.dart';
import 'smooth_scroll.dart';
import 'terminal.dart';
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
  // Скрыты свайпом/меню, но ещё не удалены физически — ждут Undo из снекбара.
  final Set<String> _pendingDelete = {};
  bool _didInitialScroll = false;
  Peer? _target; // null = сохранить локально
  String?
  _filter; // null=все, '__pinned__'=закреплённые, '__archive__'=архив, иначе имя группы
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

  // Раз на процесс: main.dart уже пробует запросить POST_NOTIFICATIONS до
  // runApp, но там Activity может быть ещё не полностью готова на части
  // прошивок. Здесь контекст гарантированно валиден — подстраховка, чтобы
  // медиа-уведомление плеера не блокировалось молча из-за неполученного
  // разрешения.
  static bool _notifPermissionAsked = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid && !_notifPermissionAsked) {
      _notifPermissionAsked = true;
      FlutterForegroundTask.requestNotificationPermission().catchError(
        (_) => NotificationPermission.denied,
      );
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
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
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
        await _app.queue.enqueue(
          QueuedSend(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            peerId: peer.id,
            peerName: peer.name,
            kind: 'text',
            text: text,
            createdAt: DateTime.now(),
          ),
        );
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
    await _app.store.add(
      SavedItem(
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
      ),
    );
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
    _app
        .sendFileTo(peer, file, ttlSeconds: ttl)
        .listen(
          (p) => progress.value = p,
          onDone: () {
            entry.close();
            _toast(t.sentName(name));
            // Записываем в свою ленту как исходящее.
            _app.store.add(
              SavedItem(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                kind: kindFromMime(null, name),
                fileName: name,
                fileSize: file.lengthSync(),
                createdAt: DateTime.now(),
                outgoing: true,
                fromName: peer.name,
                expiresAt: ttl != null
                    ? DateTime.now().add(Duration(seconds: ttl))
                    : null,
              ),
            );
          },
          onError: (e) async {
            entry.close();
            // Пир пропал во время передачи — сохраняем копию и кладём в очередь.
            try {
              final copy = _app.store.newFileFor(name);
              await file.copy(copy.path);
              await _app.queue.enqueue(
                QueuedSend(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  peerId: peer.id,
                  peerName: peer.name,
                  kind: 'file',
                  filePath: copy.path,
                  createdAt: DateTime.now(),
                ),
              );
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
      listenable: Listenable.merge([
        _app,
        _app.store,
        _app.discovery,
        _app.auth,
      ]),
      builder: (context, _) {
        // авто-выбор адресата
        _target ??= _app.preferredPeer;
        if (_target != null &&
            !_app.peers.any((p) => p.id == _target!.id && p.online)) {
          _target = _app.preferredPeer;
        }
        final all = _app.store.items;
        final items = _applyFilter(all);
        if (!_didInitialScroll && items.isNotEmpty) {
          _didInitialScroll = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scroll.hasClients) {
              _scroll.jumpTo(_scroll.position.maxScrollExtent);
            }
          });
        }
        final cs = Theme.of(context).colorScheme;
        final scaffold = Scaffold(
          appBar: _appBar(context),
          // Обои видны и за плавающей капсулой шапки — иначе она сливается
          // с фоном Scaffold и перестаёт читаться как отдельный блок.
          extendBodyBehindAppBar: true,
          body: Stack(
            children: [
              Positioned.fill(child: _bgLayer(cs)),
              Column(
                children: [
                  SizedBox(height: appBarTotalHeight(context)),
                  if (_searching) _searchBar(context),
                  _filterBar(context),
                  Expanded(
                    child: Stack(
                      children: [
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
                          child: items.isEmpty
                              ? _empty(context)
                              : _timeline(items),
                        ),
                        if (_dragHover)
                          Positioned.fill(
                            child: Container(
                              color: cs.primary.withValues(alpha: 0.12),
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cs.surface,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: cs.primary,
                                      width: 2,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.file_download_outlined,
                                        color: cs.primary,
                                      ),
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
                  _inputBar(context),
                ],
              ),
              // Плавающий квадратик плеера — поверх всего, можно перетащить.
              const FloatingMiniPlayer(),
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

  // Единая компактная капсула: один ряд (лого + статус двухстрочным
  // заголовком слева, кнопки справа), без отдельной нижней подстроки —
  // именно она раньше раздувала шапку. Значение используется и здесь, и в
  // SizedBox-спейсере тела, чтобы они не расходились.
  static const double _kBarH = 46;
  static const double _kAppBarTopGap = 4;
  static double appBarTotalHeight(BuildContext context) =>
      MediaQuery.paddingOf(context).top + _kAppBarTopGap + _kBarH;

  PreferredSizeWidget _appBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final online = _app.peers.where((p) => p.online).length;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Плавающая капсула: отступы от краёв, скруглённая, с тонкой обводкой.
    final top = MediaQuery.paddingOf(context).top;
    return PreferredSize(
      preferredSize: Size.fromHeight(appBarTotalHeight(context)),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        // Статус-бар прозрачный (см. edgeToEdge в main.dart) — здесь только
        // яркость его иконок, синхронизированная с текущей темой.
        value: dark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
              ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(10, top + _kAppBarTopGap, 10, 0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: cs.outlineVariant.withValues(
                  alpha: _app.settings.borderOpacity,
                ),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: _rawAppBar(context, cs, online, dark),
            ),
          ),
        ),
      ),
    );
  }

  AppBar _rawAppBar(
    BuildContext context,
    ColorScheme cs,
    int online,
    bool dark,
  ) {
    final status = !_app.auth.isLoggedIn
        ? t.signInPrompt
        : online > 0
        ? t.devicesInAccount(online)
        : t.searchingDevices;
    return AppBar(
      elevation: 0,
      // primary: false — вертикальный отступ под статус-бар уже даёт капсула.
      primary: false,
      backgroundColor: cs.surface.withValues(alpha: 0.74),
      titleSpacing: 12,
      toolbarHeight: _kBarH,
      // Лого + мелкая строка статуса в две строки внутри одного ряда —
      // компактнее, чем отдельный bottom-сабтайтл.
      title: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                dark
                    ? 'assets/brand/logo-horizontal-white.png'
                    : 'assets/brand/logo-horizontal.png',
                height: 17,
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
                errorBuilder: (_, __, ___) => Image.asset(
                  'assets/brand/logo-horizontal-white.png',
                  height: 17,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'files',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Text(
            status,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              height: 1.1,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
      actions: [
        _tonalIcon(
          cs: cs,
          tooltip: t.searchHint,
          icon: const Icon(Icons.search_rounded, size: 19),
          onPressed: () => setState(() => _searching = !_searching),
        ),
        _tonalIcon(
          cs: cs,
          tooltip: t.ttDevices,
          icon: Badge(
            isLabelVisible: online > 0,
            label: Text('$online'),
            child: const Icon(Icons.devices_rounded, size: 20),
          ),
          onPressed: () {
            FocusScope.of(context).unfocus();
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const PeersPage()));
          },
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
            // Клавиатура от поля ввода сообщения не закрывается сама при
            // пуше нового роута — без этого она «протекала» на следующий
            // экран (например, в настройки).
            FocusScope.of(context).unfocus();
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 0,
              child: Row(
                children: [
                  const Icon(Icons.library_music_outlined, size: 20),
                  const SizedBox(width: 12),
                  Text(t.music),
                ],
              ),
            ),
            PopupMenuItem(
              value: 1,
              child: Row(
                children: [
                  const Icon(Icons.keyboard_alt_outlined, size: 20),
                  const SizedBox(width: 12),
                  Text(t.ttKeyboard),
                ],
              ),
            ),
            PopupMenuItem(
              value: 2,
              child: Row(
                children: [
                  const Icon(Icons.settings_outlined, size: 20),
                  const SizedBox(width: 12),
                  Text(t.ttSettings),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  /// Круглая тонированная кнопка-иконка — премиальный «пилюльный» стиль
  /// вместо голого IconButton на прозрачном фоне.
  Widget _tonalIcon({
    required ColorScheme cs,
    required String tooltip,
    required Widget icon,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
              shape: BoxShape.circle,
            ),
            child: IconTheme(
              data: IconThemeData(color: cs.onSurfaceVariant),
              child: icon,
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
        img = Image.file(
          File(path),
          fit: BoxFit.cover,
          cacheWidth: 48,
          filterQuality: FilterQuality.none,
        );
      } else {
        img = Image.file(File(path), fit: BoxFit.cover);
        if (s.bgEffect == 1) {
          img = ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: img,
          );
        }
      }
      return Stack(
        fit: StackFit.expand,
        children: [
          img,
          Container(color: Colors.black.withValues(alpha: s.bgDim)),
        ],
      );
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
        .where(
          (e) =>
              (e.text ?? '').toLowerCase().contains(q) ||
              (e.fileName ?? '').toLowerCase().contains(q),
        )
        .toList();
  }

  Widget _searchBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final terminal = _app.settings.terminalBubbles;
    final field = TextField(
      controller: _search,
      autofocus: true,
      onChanged: (v) => setState(() => _query = v),
      style: terminal ? TextStyle(color: cs.onSurface) : null,
      decoration: InputDecoration(
        isDense: true,
        hintText: t.searchHint,
        filled: terminal,
        fillColor: terminal ? Colors.black : null,
        border: terminal ? InputBorder.none : null,
        prefixIcon: Icon(
          Icons.search_rounded,
          color: terminal ? cs.primary : null,
        ),
        suffixIcon: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => setState(() {
            _searching = false;
            _query = '';
            _search.clear();
          }),
        ),
      ),
    );
    if (!terminal) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
        child: field,
      );
    }
    // Терминальный вид: та же чёрная пилюля с белой обводкой, что у поля
    // ввода сообщения — иначе стандартный TextField терялся на чёрном фоне.
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: _app.settings.borderOpacity),
          ),
        ),
        child: field,
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
          _filterChip(
            context,
            label: t.all,
            value: null,
            icon: Icons.apps_rounded,
          ),
          if (hasPinned)
            _filterChip(
              context,
              label: t.pinned,
              value: '__pinned__',
              icon: Icons.push_pin_rounded,
            ),
          if (hasArchived)
            _filterChip(
              context,
              label: t.archived,
              value: '__archive__',
              icon: Icons.archive_rounded,
            ),
          for (final g in groups)
            _filterChip(
              context,
              label: g,
              value: g,
              icon: Icons.folder_rounded,
            ),
        ],
      ),
    );
  }

  Widget _filterChip(
    BuildContext context, {
    required String label,
    required String? value,
    required IconData icon,
  }) {
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
          Text(
            t.emptyTitle,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
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

  /// Свайп-удаление и удаление из меню не стирают элемент сразу — прячут его
  /// и на несколько секунд дают отменить через снекбар с Undo. Это защита от
  /// случайного свайпа: физическое удаление происходит только когда снекбар
  /// закрылся, а Undo не был нажат.
  void _requestDelete(SavedItem item) {
    setState(() => _pendingDelete.add(item.id));
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger
        .showSnackBar(
          SnackBar(
            content: Text(t.deleted),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: t.undo,
              onPressed: () {
                if (mounted) setState(() => _pendingDelete.remove(item.id));
              },
            ),
          ),
        )
        .closed
        .then((_) {
          if (!mounted || !_pendingDelete.contains(item.id)) return;
          _pendingDelete.remove(item.id);
          _app.store.remove(item);
        });
  }

  Widget _timeline(List<SavedItem> items) {
    // items идут от новых к старым (store.items = reversed). Развернём для ленты.
    final ordered = items.reversed
        .where((e) => !_pendingDelete.contains(e.id))
        .toList();
    return SmoothScroll(
      controller: _scroll,
      builder: (physics) => ListView.builder(
        controller: _scroll,
        physics: physics,
        padding: const EdgeInsets.symmetric(vertical: 10),
        itemCount: ordered.length,
        itemBuilder: (context, i) {
          final item = ordered[i];
          final showDay =
              i == 0 || !_sameDay(ordered[i - 1].createdAt, item.createdAt);
          final animate = _app.settings.animations && !_seen.contains(item.id);
          _seen.add(item.id);
          final row = Column(
            key: ValueKey(item.id),
            children: [
              if (showDay) _dayChip(context, item.createdAt),
              _SwipeRow(
                itemId: item.id,
                onShare: () => shareItem(item),
                onDelete: () => _requestDelete(item),
                child: ItemBubble(
                  item: item,
                  onDelete: () => _requestDelete(item),
                ),
              ),
            ],
          );
          return animate
              ? _Entrance(
                  style: _app.settings.animStyle,
                  durationMs: _app.settings.animDurationMs,
                  child: row,
                )
              : row;
        },
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _dayChip(BuildContext context, DateTime dt) {
    // Терминальный вид: линия через всю ширину с датой посередине.
    if (_app.settings.terminalBubbles) {
      return TerminalDivider(text: daySeparator(dt, t));
    }
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          daySeparator(dt, t),
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
      ),
    );
  }

  Widget _inputBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final border = Colors.white.withValues(alpha: _app.settings.borderOpacity);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _targetSelector(context),
            if (_recording)
              _recordingRow(cs)
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Единая пилюля: вложения, текст и микрофон — всё внутри.
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: _ttlSeconds != null ? cs.primary : border,
                          width: _ttlSeconds != null ? 1.2 : 1,
                        ),
                      ),
                      child: Row(
                        // .center, а не .end — иначе IconButton (48px тап-таргет)
                        // выравнивался по нижнему краю текстового поля и
                        // визуально «сползал» ниже плейсхолдера.
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.add_circle_outline_rounded),
                            onPressed: _attachMenu,
                          ),
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
                                  4,
                                  12,
                                  4,
                                  12,
                                ),
                              ),
                            ),
                          ),
                          if (_ttlSeconds != null)
                            Padding(
                              padding: const EdgeInsets.only(
                                right: 4,
                                bottom: 6,
                              ),
                              child: Icon(
                                Icons.timer_rounded,
                                size: 16,
                                color: cs.primary,
                              ),
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
                      backgroundColor: _ttlSeconds != null ? cs.primary : null,
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
                leading: Icon(
                  v == null ? Icons.timer_off_outlined : Icons.timer_outlined,
                ),
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
          child: Text(
            t.recording,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
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
    // Выбирать не из чего — не занимаем место строкой с единственным чипом.
    if (peers.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SizedBox(
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
      ),
    );
  }

  Widget _targetChip(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    required ColorScheme color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: ChoiceChip(
        avatar: Icon(
          icon,
          size: 16,
          color: selected ? color.onSecondaryContainer : color.onSurface,
        ),
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
  const _Entrance({
    required this.child,
    required this.style,
    required this.durationMs,
  });

  @override
  State<_Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<_Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.durationMs),
  )..forward();
  late final Animation<double> _curve = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOutCubic,
  );

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
          position: Tween(
            begin: const Offset(0, 0.14),
            end: Offset.zero,
          ).animate(_curve),
          child: widget.child,
        );
      case 2: // масштаб
        return ScaleTransition(
          scale: Tween(begin: 0.85, end: 1.0).animate(_curve),
          child: fade,
        );
      default: // подъём + fade
        return SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.12),
            end: Offset.zero,
          ).animate(_curve),
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
      // По умолчанию порог 0.4 — слишком легко удалить случайным свайпом
      // при скролле. Для удаления (влево) требуем почти весь экран; для
      // пересылки (вправо) он и так безопасен — confirmDismiss всегда
      // отменяет анимацию, поэтому здесь порог можно оставить мягче.
      dismissThresholds: const {
        DismissDirection.endToStart: 0.68,
        DismissDirection.startToEnd: 0.4,
      },
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
