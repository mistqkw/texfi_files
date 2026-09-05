import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart'
    show SystemUiOverlayStyle;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../l10n/app_strings.dart';
import 'floating_player.dart';
import '../app.dart';
import '../app_state.dart';
import '../core/models.dart';
import '../core/offline_queue.dart';
import 'format.dart';
import 'item_bubble.dart';
import 'music_screen.dart';
import '../core/theme/app_colors_ext.dart';
import '../core/haptics.dart';
import '../core/theme/app_motion.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles_ext.dart';
import 'pixel/pixel_card.dart';
import 'pixel/pixel_controls.dart';
import 'pixel/pixel_icons.dart';
import 'pixel/pixel_burst.dart';
import 'pixel/pixel_button.dart';
import 'selection_paint.dart';
import 'pixel/pixel_route.dart';
import 'pixel/pixel_progress.dart';
import 'pixel/pixel_snow.dart';
import 'pixel/pixel_wordmark.dart';
import 'pixel/pixel_shadow.dart';
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
  // Скрыты свайпом/меню, но ещё не удалены физически — ждут Undo из снекбара.
  final Set<String> _pendingDelete = {};
  bool _didInitialScroll = false;
  Peer? _target; // null = сохранить локально
  String?
  _filter; // null=все, '__pinned__'=закреплённые, '__archive__'=архив, иначе имя группы
  bool _searching = false;
  final _sendKey = GlobalKey<_SendButtonState>();

  /// Режим выделения: идентификаторы отмеченных элементов.
  ///
  /// Храним id, а не сами объекты: элемент может быть пересоздан при
  /// обновлении ленты (приём файла, синхронизация), и ссылка на старый
  /// экземпляр молча выпала бы из выделения.
  final Set<String> _selected = {};
  bool _selecting = false;

  /// Что именно делает протяжка при выделении: отмечает или снимает.
  /// Определяется по первому задетому элементу — как в файловых менеджерах.
  bool _paintValue = true;

  /// Порядок строк на экране — нужен протяжке, чтобы закрасить всё между
  /// двумя замерами пальца, а не только строку прямо под ним.
  List<SavedItem> _ordered = const [];

  /// Индекс последней задетой строки.
  int? _lastPaintIndex;

  /// Автопрокрутка, пока палец держат у края списка.
  Timer? _edgeScroll;

  /// Высота клавиатуры на прошлом кадре — чтобы заметить её появление.
  double _lastInset = 0;
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
      if (!mounted) return;
      setState(() => _recording = true);
    } catch (e) {
      if (!mounted) return;
      _toast(t.failed('$e'));
    }
  }

  Future<void> _stopRecord({bool cancel = false}) async {
    try {
      final path = await _recorder.stop();
      if (!mounted) return;
      setState(() => _recording = false);
      if (cancel || path == null) return;
      final f = File(path);
      if (f.existsSync() && await f.length() > 0) {
        await _dispatchFile(f);
        _scrollToBottom();
      }
    } catch (e) {
      if (!mounted) return;
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
      Permission.notification.request().catchError(
        (_) => PermissionStatus.denied,
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
    // Таймер автопрокрутки переживёт экран, если его не остановить, и
    // продолжит дёргать уже уничтоженный ScrollController.
    _stopEdgeScroll();
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
    _sendKey.currentState?.pulse();
    // Текст уходит мгновенно, поэтому вспышку частиц здесь не показываем —
    // она бы срабатывала на каждое сообщение и быстро надоела. Курсор
    // отбивает такт только когда адресат действительно был.
    if (_target != null) PixelWordmark.blink();
    _scrollToBottom();
  }

  Future<void> _dispatchFile(File file) async {
    if (_target != null) {
      _showFileProgress(file);
    } else {
      await _saveFileLocal(file);
    }
    // Тот же момент подтверждения, что и у текста: файл уходит в фоне, и
    // без отклика непонятно, приняло ли приложение действие вообще.
    _sendKey.currentState?.pulse();
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
          builder: (_, v, _) => TweenAnimationBuilder<double>(
            // Прогресс приходит рывками по мере отправки кусков; без
            // сглаживания полоса прыгает через несколько ячеек разом.
            tween: Tween<double>(end: v),
            duration: kProgressCatchUp,
            builder: (_, shown, _) => PixelTransferRow(
              title: name,
              value: v == 0 ? null : shown,
            ),
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
            // Момент прибытия: вспышка частиц с галочкой, вибро-квитанция и
            // короткая серия миганий курсора в логотипе — файл дошёл, и это
            // видно, а не только записано строкой в ленте.
            if (mounted) PixelBurst.show(context);
            PixelWordmark.blink();
            Haptics.sent();
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
    // Store намеренно НЕ в этом списке.
    //
    // Он уведомляет чаще всех — во время приёма файла раз в 256KB, то есть
    // десятки раз в секунду. Пока он был здесь, каждое такое уведомление
    // пересобирало весь экран: фон, шапку, панель фильтров, поле ввода и
    // всю ленту. Теперь на store подписана только сама лента (см. _feed),
    // а здесь остаётся то, что меняется редко.
    return ListenableBuilder(
      listenable: Listenable.merge([_app, _app.discovery, _app.auth]),
      builder: (context, _) {
        _keepBottomOnKeyboard(context);
        // авто-выбор адресата
        _target ??= _app.preferredPeer;
        if (_target != null &&
            !_app.peers.any((p) => p.id == _target!.id && p.online)) {
          _target = _app.preferredPeer;
        }
        final cs = Theme.of(context).colorScheme;
        final scaffold = Scaffold(
          appBar: _appBar(context),
          // Обои видны и за плавающей капсулой шапки — иначе она сливается
          // с фоном Scaffold и перестаёт читаться как отдельный блок.
          extendBodyBehindAppBar: true,
          // Клавиатура не сжимает тело экрана.
          //
          // По умолчанию Scaffold уменьшает body на высоту клавиатуры — а
          // вместе с ним уезжал и фон: картинка перемасштабировалась, снег
          // перестраивался, лента прыгала. Теперь высота постоянна, а под
          // клавиатуру приподнимается только поле ввода (см. _inputBar).
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              Positioned.fill(child: _bgLayer(cs)),
              Column(
                children: [
                  SizedBox(height: appBarTotalHeight(context)),
                  if (_searching) _searchBar(context),
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          // Тап мимо поля ввода прячет клавиатуру.
                          // translucent, а не opaque: жесты самой ленты
                          // (прокрутка, свайп по сообщению) должны
                          // продолжать работать.
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () => FocusScope.of(context).unfocus(),
                            child: _feed(context),
                          ),
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
  // Метрики шапки. Размеры именно те, которыми набирается текст, — высота
  // капсулы считается из них, а не задаётся отдельной константой.
  static const double _kTitleSize = 12;   // пиксельный шрифт
  static const double _kStatusSize = 10;  // гротеск
  static const double _kTitleLeading = 1.25;
  static const double _kTitleGap = 3;
  static const double _kBarVPad = 9;
  static const double _kAppBarTopGap = 4;

  /// Масштаб текста внутри шапки.
  ///
  /// Общий масштаб интерфейса (uiScale) применяется ко всему дереву, но
  /// шапка — фиксированная по высоте полоса поверх ленты, и растить её
  /// вместе с текстом бесконечно нельзя. Ограничиваем: до 1.15 шапка
  /// растёт, дальше текст остаётся читаемым, но перестаёт распирать
  /// капсулу.
  static TextScaler _barScaler(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(100) / 100;
    return TextScaler.linear(scale.clamp(1.0, 1.15));
  }

  /// Высота капсулы шапки, посчитанная по тексту, который в ней рисуется.
  ///
  /// Раньше здесь стояла константа 46, а заголовок с подписью жили внутри
  /// AppBar с жёстким toolbarHeight. Обе строки масштабировались вместе с
  /// uiScale, в 46px переставали помещаться — и наезжали друг на друга.
  /// Теперь высота выводится из тех же размеров, которыми набирается
  /// текст, поэтому разъехаться они не могут в принципе.
  static double _barHeight(BuildContext context) {
    final scaler = _barScaler(context);
    final title = scaler.scale(_kTitleSize) * _kTitleLeading;
    final status = scaler.scale(_kStatusSize) * _kTitleLeading;
    return _kBarVPad * 2 + title + _kTitleGap + status;
  }

  static double appBarTotalHeight(BuildContext context) =>
      MediaQuery.paddingOf(context).top + _kAppBarTopGap + _barHeight(context);

  PreferredSizeWidget _appBar(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final top = MediaQuery.paddingOf(context).top;
    return PreferredSize(
      preferredSize: Size.fromHeight(appBarTotalHeight(context)),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        // Статус-бар прозрачный (см. edgeToEdge в main.dart) — здесь только
        // яркость его иконок, синхронизированная с темой.
        value: dark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
              ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            top + _kAppBarTopGap,
            AppSpacing.md,
            0,
          ),
          child: _barContent(context),
        ),
      ),
    );
  }

  /// Содержимое капсулы. Собрано явным Row/Column, а не AppBar: у AppBar
  /// заголовок живёт в жёстко заданном toolbarHeight — ровно та причина,
  /// по которой строки налезали друг на друга.
  Widget _barContent(BuildContext context) {
    if (_selecting) return _selectionBar(context);
    final colors = context.colors;
    final online = _app.peers.where((p) => p.online).length;
    final status = !_app.auth.isLoggedIn
        ? t.signInPrompt
        : online > 0
        ? t.devicesInAccount(online)
        : t.searchingDevices;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: _barScaler(context)),
      child: Container(
        height: _barHeight(context),
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.xs, 0),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: AppRadius.cardMediumAll,
          border: Border.all(
            color: colors.divider,
            width: AppRadius.pixelBorder,
          ),
        ),
        child: Row(
          children: [
            // Текстовый блок в Expanded: по ширине он тоже не может
            // вытеснить кнопки — при длинном статусе строка обрежется
            // многоточием, а не уедет под иконки.
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PixelWordmark(
                    size: _kTitleSize,
                    leading: _kTitleLeading,
                  ),
                  const SizedBox(height: _kTitleGap),
                  Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.captionSmall.copyWith(
                      fontSize: _kStatusSize,
                      height: _kTitleLeading,
                    ),
                  ),
                ],
              ),
            ),
            PixelIconButton(
              icon: 'search',
              tooltip: t.searchHint,
              onPressed: () => setState(() => _searching = !_searching),
            ),
            _devicesButton(context, online),
            PixelIconButton(
              icon: 'gear',
              tooltip: t.ttSettings,
              onPressed: () => _openMenu(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Шапка режима выделения: сколько отмечено и что с этим можно сделать.
  ///
  /// Занимает место обычной шапки, а не появляется сверху неё: иначе
  /// содержимое ленты уезжало бы вниз при каждом входе в режим.
  Widget _selectionBar(BuildContext context) {
    final colors = context.colors;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: _barScaler(context)),
      child: Container(
        height: _barHeight(context),
        padding: const EdgeInsets.fromLTRB(AppSpacing.xs, 0, AppSpacing.xs, 0),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: AppRadius.cardMediumAll,
          border: Border.all(color: colors.accent, width: AppRadius.pixelBorder),
        ),
        child: Row(
          children: [
            PixelIconButton(
              icon: 'close',
              size: 16,
              tooltip: t.cancel,
              onPressed: _endSelection,
            ),
            Expanded(
              child: Text(
                t.selectedCount(_selected.length),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.screenTitle.copyWith(
                  fontSize: _kStatusSize + 1,
                  color: colors.accent,
                ),
              ),
            ),
            PixelIconButton(
              icon: 'label',
              size: 17,
              tooltip: t.labels,
              onPressed: _selected.isEmpty ? null : _labelSelected,
            ),
            PixelIconButton(
              icon: 'folder',
              size: 17,
              tooltip: t.moveToFolder,
              onPressed: _selected.isEmpty ? null : _moveSelected,
            ),
            PixelIconButton(
              icon: 'trash',
              size: 17,
              color: colors.danger,
              tooltip: t.delete,
              onPressed: _selected.isEmpty ? null : _deleteSelected,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSelected() async {
    final items = _selectedItems;
    if (items.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.delete),
        content: Text(t.selectedCount(items.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _app.store.removeAll(items);
    Haptics.sent();
    _endSelection();
  }

  Future<void> _moveSelected() async {
    final items = _selectedItems;
    if (items.isEmpty) return;
    final group = await _pickGroup(context);
    if (group == null) return;
    // Пустая строка из диалога означает «вынуть из папки».
    await _app.store.setGroupAll(items, group.isEmpty ? null : group);
    Haptics.tap();
    _endSelection();
  }

  Future<void> _labelSelected() async {
    final items = _selectedItems;
    if (items.isEmpty) return;
    final tag = await _pickLabel(context);
    if (tag == null || tag.isEmpty) return;
    await _app.store.toggleLabelAll(items, tag);
    Haptics.tap();
    _endSelection();
  }

  /// Выбор папки: существующие плюс создание новой. Пустая строка —
  /// «вынуть из папки».
  Future<String?> _pickGroup(BuildContext context) {
    final groups = _app.store.groups;
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final g in groups)
                PixelTile(
                  icon: 'folder',
                  title: g,
                  onTap: () => Navigator.pop(sheet, g),
                ),
              PixelTile(
                icon: 'close',
                title: t.removeFromGroup,
                onTap: () => Navigator.pop(sheet, ''),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: _NewNameField(
                  hint: t.newGroup,
                  onSubmit: (v) => Navigator.pop(sheet, v),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _pickLabel(BuildContext context) {
    final known = _app.store.labels;
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final tag in known)
                PixelTile(
                  icon: 'label',
                  title: tag,
                  onTap: () => Navigator.pop(sheet, tag),
                ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: _NewNameField(
                  hint: t.newLabel,
                  onSubmit: (v) => Navigator.pop(sheet, v),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Кнопка перехода к устройствам со счётчиком найденных.
  Widget _devicesButton(BuildContext context, int online) {
    final colors = context.colors;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        PixelIconButton(
          icon: 'device',
          tooltip: t.ttDevices,
          onPressed: () {
            FocusScope.of(context).unfocus();
            _openPage((_) => const PeersPage());
          },
        ),
        if (online > 0)
          Positioned(
            right: 4,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: colors.accent,
                borderRadius: AppRadius.controlTinyAll,
              ),
              child: Text(
                '$online',
                style: context.text.pixelLabel.copyWith(
                  fontSize: 7,
                  color: colors.onAccent,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Открыть экран, погасив клавиатуру и до, и после перехода.
  ///
  /// Одного unfocus перед push мало: возвращаясь, Flutter восстанавливает
  /// прежний фокус, и клавиатура сама выезжала на главном экране, хотя
  /// пользователь ничего не набирал.
  Future<void> _openPage(WidgetBuilder builder) async {
    FocusScope.of(context).unfocus();
    await pixelPush(context, builder);
    if (mounted) FocusScope.of(context).unfocus();
  }

  void _openMenu(BuildContext context) {
    // Клавиатура от поля ввода не закрывается сама при пуше нового роута —
    // без этого она «протекала» на следующий экран.
    FocusScope.of(context).unfocus();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Вход в режим выделения — рядом с остальными действиями
              // экрана, а не спрятан в меню отдельного сообщения.
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: PixelTile(
                  icon: 'check',
                  title: t.select,
                  onTap: () {
                    Navigator.pop(sheet);
                    setState(() {
                      _selecting = true;
                      _selected.clear();
                    });
                  },
                ),
              ),
              for (final e in [
                ('note', t.music, const MusicScreen()),
                ('laptop', t.ttKeyboard, const RemoteKeyboardPage()),
                ('gear', t.ttSettings, const SettingsPage()),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: PixelTile(
                    icon: e.$1,
                    title: e.$2,
                    onTap: () {
                      Navigator.pop(sheet);
                      _openPage((_) => e.$3);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Подложка ленты.
  ///
  /// От разросшейся подсистемы (градиент, эффект «блюр/пиксели», ползунок
  /// затемнения, погода) осталось одно: своё фото, если пользователь его
  /// выбрал. Затемнение фиксированное — подобрано так, чтобы текст
  /// сообщений читался поверх любой картинки, включая светлую.
  ///
  /// Существование файла проверяется на каждом кадре сознательно: картинку
  /// могли удалить из галереи уже после выбора, и без проверки Image.file
  /// сыпал бы исключением декодирования непрерывно.
  /// Подложка ленты: фото пользователя, размытие, затемнение и снег.
  ///
  /// Всё это — вынесенный в отдельный виджет слой, а не часть дерева
  /// главного экрана: лента перестраивается на каждое изменение store
  /// (пришло сообщение, обновился прогресс передачи), и без такого
  /// разделения фоновая картинка пересоздавалась бы вместе с ней.
  Widget _bgLayer(ColorScheme cs) {
    final s = _app.settings;
    return _BackgroundLayer(
      path: s.chatBgImage,
      blur: s.bgBlur,
      dim: s.bgDim,
      snow: s.snow,
      snowSpeed: s.snowSpeed,
    );
  }


  /// Префикс значения фильтра для метки.
  static const _labelFilter = 'label:';

  List<SavedItem> _applyFilter(List<SavedItem> items) {
    List<SavedItem> base;
    if (_filter == '__archive__') {
      base = items.where((e) => e.archived).toList();
    } else if (_filter == '__pinned__') {
      base = items.where((e) => e.pinned && !e.archived).toList();
    } else if (_filter != null && _filter!.startsWith(_labelFilter)) {
      final tag = _filter!.substring(_labelFilter.length);
      base = items.where((e) => !e.archived && e.labels.contains(tag)).toList();
    } else if (_filter == null) {
      // «Все» — это лента, а не свалка: элемент, разложенный по папке,
      // живёт в ней и здесь больше не мозолит глаза. Иначе папки не
      // разгружают ленту, а только дублируют её.
      base = items
          .where((e) => !e.archived && (e.group == null || e.group!.isEmpty))
          .toList();
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
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: PixelCard(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          children: [
            PixelIcon('search', size: 16, color: colors.accent),
            AppSpacing.wGapMd,
            Expanded(
              child: TextField(
                controller: _search,
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                style: context.text.body,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: t.searchHint,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md,
                  ),
                ),
              ),
            ),
            PixelIconButton(
              icon: 'close',
              size: 14,
              onPressed: () => setState(() {
                _searching = false;
                _query = '';
                _search.clear();
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterBar(BuildContext context, List<SavedItem> all) {
    // Один проход по ленте вместо нескольких отдельных: каждый заново
    // обходил бы весь список при любой перерисовке.
    final groupSet = <String>{};
    final labelSet = <String>{};
    var hasPinned = false;
    var hasArchived = false;
    for (final it in all) {
      if (it.group != null && it.group!.isNotEmpty) groupSet.add(it.group!);
      if (!it.archived) labelSet.addAll(it.labels);
      if (it.archived) {
        hasArchived = true;
      } else if (it.pinned) {
        hasPinned = true;
      }
    }
    final groups = groupSet.toList()..sort();
    final labels = labelSet.toList()..sort();
    if (groups.isEmpty && labels.isEmpty && !hasPinned && !hasArchived) {
      return const SizedBox.shrink();
    }
    // Сбрасываем фильтр, если папка или метка исчезли.
    //
    // Именно отложенно, а не прямо здесь. Раньше присваивание стояло в
    // build без setState: лента к этому моменту уже отфильтрована старым
    // значением, поэтому кадр уходил с пустым списком и схлопнувшейся
    // панелью, а перерисовка не назначалась — панель «пропадала» до
    // следующего постороннего обновления. Это и был баг с исчезающей
    // шторкой архива и папок.
    final known = {
      null,
      '__pinned__',
      '__archive__',
      ...groups,
      ...labels.map((e) => '$_labelFilter$e'),
    };
    if (!known.contains(_filter)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !known.contains(_filter)) {
          setState(() => _filter = null);
        }
      });
    }

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        children: [
          _filterChip(label: t.all, value: null, icon: 'folder'),
          if (hasPinned)
            _filterChip(label: t.pinned, value: '__pinned__', icon: 'star'),
          if (hasArchived)
            _filterChip(
              label: t.archived,
              value: '__archive__',
              icon: 'archive',
            ),
          for (final g in groups)
            _filterChip(label: g, value: g, icon: 'folder'),
          for (final l in labels)
            _filterChip(
              label: l,
              value: '$_labelFilter$l',
              icon: 'label',
            ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required String? value,
    required String icon,
  }) {
    final selected = _filter == value;
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: PixelCard(
        accent: selected,
        background: selected ? colors.accent : null,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        onTap: () => setState(() => _filter = value),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PixelIcon(
              icon,
              size: 13,
              color: selected ? colors.onAccent : colors.accent,
            ),
            AppSpacing.wGapSm,
            Text(
              label,
              style: context.text.tileTitleSmall.copyWith(
                color: selected ? colors.onAccent : colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.huge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Крупный простой силуэт: на пустом экране он единственный
            // объект, и мелкая иконка тут читается как случайный мусор.
            PixelIcon('star', size: 76, color: colors.accent),
            AppSpacing.gapXl,
            Text(t.emptyTitle, style: context.text.screenTitle),
            AppSpacing.gapMd,
            Text(
              t.emptyText,
              textAlign: TextAlign.center,
              // Обычный шрифт: это связный текст, а не метка.
              style: context.text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

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

  /// Держит ленту у нижнего края, когда выезжает клавиатура.
  ///
  /// Тело экрана больше не сжимается под клавиатуру, но поле ввода
  /// приподнимается и закрывает нижнюю часть ленты. Позиция прокрутки при
  /// этом не менялась — последние сообщения уходили под поле ввода.
  ///
  /// Догоняем только если пользователь и так стоял внизу: если он листает
  /// историю, дёргать его к последнему сообщению нельзя.
  void _keepBottomOnKeyboard(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    if (inset <= _lastInset) {
      _lastInset = inset;
      return;
    }
    final grew = inset - _lastInset;
    _lastInset = inset;
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    // «Внизу» — с запасом на высоту одного сообщения.
    if (pos.maxScrollExtent - pos.pixels > 160) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final p = _scroll.position;
      _scroll.jumpTo(
        (p.pixels + grew).clamp(p.minScrollExtent, p.maxScrollExtent),
      );
    });
  }

  /// Лента вместе с панелью фильтров — единственная часть экрана,
  /// подписанная на store.
  Widget _feed(BuildContext context) {
    return ListenableBuilder(
      listenable: _app.store,
      builder: (context, _) {
        final all = _app.store.itemsChronological;
        final items = _applyFilter(all);
        if (!_didInitialScroll && items.isNotEmpty) {
          _didInitialScroll = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scroll.hasClients) {
              _scroll.jumpTo(_scroll.position.maxScrollExtent);
            }
          });
        }
        return Column(
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _filterBar(context, all),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: items.isEmpty
                    ? _empty(context)
                    : KeyedSubtree(
                        key: ValueKey(_filter),
                        child: _timeline(items),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _timeline(List<SavedItem> items) {
    // items уже в хронологическом порядке (store.itemsChronological).
    final ordered = _pendingDelete.isEmpty
        ? items
        : items.where((e) => !_pendingDelete.contains(e.id)).toList();
    _ordered = ordered;
    final list = SmoothScroll(
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
          final selected = _selected.contains(item.id);
          final row = Column(
            key: ValueKey(item.id),
            children: [
              if (showDay) _dayChip(context, item.createdAt),
              // MetaData помечает строку её id: по нему протяжка узнаёт,
              // над каким элементом сейчас палец (обычный hit-test по
              // координатам ничего не сказал бы о содержимом).
              MetaData(
                // Индекс, а не только id: по нему протяжка закрашивает
                // весь отрезок между предыдущим замером и текущим.
                metaData: i,
                child: _selecting
                    ? _SelectableRow(
                        selected: selected,
                        onTap: () => _toggleSelected(item.id),
                        child: ItemBubble(item: item, onDelete: () {}),
                      )
                    : _SwipeRow(
                        itemId: item.id,
                        onShare: () => shareItem(item),
                        onDelete: () => _requestDelete(item),
                        child: ItemBubble(
                          item: item,
                          onDelete: () => _requestDelete(item),
                          onSelect: () => _startSelection(item.id),
                        ),
                      ),
              ),
            ],
          );
          return animate ? _Entrance(child: row) : row;
        },
      ),
    );
    if (!_selecting) return list;
    // Зажать и провести — «закрасить» выделение. Именно долгое нажатие, а
    // не обычная протяжка: иначе жест отбирал бы у списка прокрутку.
    return GestureDetector(
      onLongPressStart: (d) => _paintAt(d.globalPosition, start: true),
      onLongPressMoveUpdate: (d) {
        _paintAt(d.globalPosition);
        _updateEdgeScroll(d.globalPosition);
      },
      onLongPressEnd: (_) => _stopEdgeScroll(),
      onLongPressCancel: _stopEdgeScroll,
      child: list,
    );
  }

  // ── Выделение ──

  void _startSelection(String id) {
    Haptics.tap();
    setState(() {
      _selecting = true;
      _selected
        ..clear()
        ..add(id);
    });
  }

  void _toggleSelected(String id) {
    Haptics.tap();
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
      // Сняли последний — выходим из режима: пустая панель действий над
      // нулём элементов бесполезна.
      if (_selected.isEmpty) _selecting = false;
    });
  }

  void _endSelection() {
    _stopEdgeScroll();
    _lastPaintIndex = null;
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  /// Отмечает строки, задетые протяжкой.
  ///
  /// Закрашивается весь отрезок от прошлого замера до текущего, а не одна
  /// строка под пальцем: события движения приходят раз в кадр, и при
  /// быстрой протяжке между двумя замерами оставалось несколько строк —
  /// они молча не попадали в выделение. Отсюда и было «выделил много, а в
  /// папку добавилось только несколько».
  void _paintAt(Offset globalPosition, {bool start = false}) {
    final index = _rowAt(globalPosition);
    if (index == null) return;
    if (start) {
      // Направление задаёт первая задетая строка: начали с невыделенной —
      // красим, с выделенной — стираем.
      final id = _idAt(index);
      _paintValue = id != null && !_selected.contains(id);
      _lastPaintIndex = index;
      _applyPaint(index, index);
      return;
    }
    final from = _lastPaintIndex ?? index;
    _lastPaintIndex = index;
    _applyPaint(from, index);
  }

  /// Индекс строки под точкой экрана, если она там есть.
  int? _rowAt(Offset globalPosition) {
    final view = View.of(context);
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, globalPosition, view.viewId);
    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderMetaData && target.metaData is int) {
        return target.metaData as int;
      }
    }
    return null;
  }

  String? _idAt(int index) =>
      index >= 0 && index < _ordered.length ? _ordered[index].id : null;

  void _applyPaint(int from, int to) {
    final changed = applySelectionPaint(
      selected: _selected,
      ids: [for (final e in _ordered) e.id],
      from: from,
      to: to,
      value: _paintValue,
    );
    if (!changed) return;
    setState(() {
      if (_selected.isEmpty) _selecting = false;
    });
    Haptics.tap();
  }

  /// Прокрутка, пока палец держат у верхнего или нижнего края списка.
  ///
  /// Скорость растёт по мере приближения к самому краю, но упирается в
  /// потолок: без него у границы лента улетала на сотни элементов за
  /// мгновение и выделяла их все.
  void _updateEdgeScroll(Offset globalPosition) {
    if (!_scroll.hasClients) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalPosition);
    const zone = 90.0;
    final height = box.size.height;
    double speed = 0;
    if (local.dy < zone) {
      speed = -(1 - local.dy / zone);
    } else if (local.dy > height - zone) {
      speed = 1 - (height - local.dy) / zone;
    }
    if (speed == 0) {
      _stopEdgeScroll();
      return;
    }
    // 14 логических пикселей за кадр на полной скорости — примерно
    // страница в секунду: успеваешь разглядеть, что отмечается.
    final step = speed.clamp(-1.0, 1.0) * 14;
    _edgeScroll ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_scroll.hasClients) return;
      final pos = _scroll.position;
      final target = (pos.pixels + _edgeStep)
          .clamp(pos.minScrollExtent, pos.maxScrollExtent);
      if (target == pos.pixels) return;
      _scroll.jumpTo(target);
      // После прокрутки под пальцем уже другая строка — дорисовываем.
      _paintAt(_lastPointer);
    });
    _edgeStep = step;
    _lastPointer = globalPosition;
  }

  double _edgeStep = 0;
  Offset _lastPointer = Offset.zero;

  void _stopEdgeScroll() {
    _edgeScroll?.cancel();
    _edgeScroll = null;
  }

  List<SavedItem> get _selectedItems => _app.store.itemsChronological
      .where((e) => _selected.contains(e.id))
      .toList();

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _dayChip(BuildContext context, DateTime dt) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Container(height: 2, color: colors.divider)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              daySeparator(dt, t),
              // Дата — короткая акцентная метка, здесь пиксельный шрифт
              // уместен.
              style: context.text.sectionTitle.copyWith(
                fontSize: 7,
                color: colors.textTertiary,
              ),
            ),
          ),
          Expanded(child: Container(height: 2, color: colors.divider)),
        ],
      ),
    );
  }

  Widget _inputBar(BuildContext context) {
    final colors = context.colors;
    // Поле ввода само отступает на высоту клавиатуры — это единственное,
    // что должно на неё реагировать.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      // Системный отступ снизу нужен только когда клавиатуры нет: под ней
      // он даёт лишний зазор.
      bottom: keyboard == 0,
      child: AnimatedPadding(
        duration: AppMotion.fast,
        curve: AppMotion.standard,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.sm + keyboard,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _targetSelector(context),
            if (_recording)
              _recordingRow(Theme.of(context).colorScheme)
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: PixelCard(
                      // Активный самоуничтожающийся режим подсвечивает саму
                      // карточку: иконка-таймер внутри слишком мелкая,
                      // чтобы заметить её до отправки.
                      accent: _ttlSeconds != null,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                      ),
                      child: Row(
                        // .center, а не .end — иначе кнопка с её тап-таргетом
                        // выравнивается по нижнему краю поля и визуально
                        // сползает ниже плейсхолдера.
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          PixelIconButton(
                            icon: 'plus',
                            size: 18,
                            tooltip: t.messageHint,
                            onPressed: _attachMenu,
                          ),
                          Expanded(
                            child: TextField(
                              controller: _input,
                              minLines: 1,
                              maxLines: 5,
                              style: context.text.body,
                              textInputAction: TextInputAction.newline,
                              decoration: InputDecoration(
                                hintText: t.messageHint,
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.xs,
                                  vertical: AppSpacing.md,
                                ),
                              ),
                            ),
                          ),
                          if (_ttlSeconds != null)
                            Padding(
                              padding: const EdgeInsets.only(right: AppSpacing.xs),
                              child: PixelIcon(
                                'clock',
                                size: 14,
                                color: colors.accent,
                              ),
                            ),
                          PixelIconButton(
                            icon: 'mic',
                            size: 18,
                            onPressed: _startRecord,
                          ),
                        ],
                      ),
                    ),
                  ),
                  AppSpacing.wGapSm,
                  // Долгое нажатие — самоуничтожение: второстепенное
                  // действие, которому не место в постоянно видимой кнопке.
                  GestureDetector(
                    onLongPress: _pickTtl,
                    child: _SendButton(
                      key: _sendKey,
                      onPressed: _sendText,
                      tooltip: t.selfDestruct,
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
/// Появление нового элемента ленты: короткий подъём с проявлением.
///
/// Стиль и скорость были настройками (четыре варианта × три скорости) —
/// двенадцать сочетаний одного и того же движения. Осталось одно,
/// согласованное с длительностями остальной экосистемы.
class _Entrance extends StatefulWidget {
  const _Entrance({required this.child});

  final Widget child;

  @override
  State<_Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<_Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppMotion.normal,
  )..forward();
  late final Animation<double> _curve = CurvedAnimation(
    parent: _c,
    curve: AppMotion.standard,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween(
        begin: const Offset(0, 0.12),
        end: Offset.zero,
      ).animate(_curve),
      child: FadeTransition(opacity: _curve, child: widget.child),
    );
  }
}

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
        if (details.reached && !_reached) Haptics.tap();
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


/// Кнопка отправки с моментом подтверждения.
///
/// Раньше отправка проходила беззвучно: текст исчезал из поля, и всё —
/// понять, ушло ли что-то, можно было только по появлению элемента внизу
/// ленты, который в этот момент ещё уезжал за край экрана. Теперь кнопка
/// коротко вспыхивает и отдаёт тактильный щелчок.
class _SendButton extends StatefulWidget {
  const _SendButton({super.key, required this.onPressed, this.tooltip});

  final VoidCallback onPressed;
  final String? tooltip;

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: AppMotion.pop,
  );
  bool _pressed = false;

  /// Вызывается снаружи, когда отправка действительно состоялась, — а не
  /// по самому нажатию: подтверждать нужно факт, а не намерение.
  void pulse() {
    if (!mounted) return;
    _flash.forward(from: 0);
    Haptics.sent();
  }

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: Tooltip(
        message: widget.tooltip ?? '',
        child: PixelShadowBox(
          shadowColor: colors.accentShadow,
          pressed: _pressed,
          child: AnimatedBuilder(
            animation: _flash,
            builder: (context, _) {
              // Треугольная вспышка: быстро вверх, чуть медленнее вниз.
              final t = _flash.value;
              final lit = t == 0 ? 0.0 : (t < 0.35 ? t / 0.35 : (1 - t) / 0.65);
              return Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Color.lerp(colors.accent, Colors.white, lit * 0.85),
                  borderRadius: AppRadius.controlSmallAll,
                  border: Border.all(
                    color: colors.accent,
                    width: AppRadius.pixelBorder,
                  ),
                ),
                child: PixelIcon('send', size: 20, color: colors.onAccent),
              );
            },
          ),
        ),
      ),
    );
  }
}


/// Фоновый слой: фото, размытие, затемнение, снег.
///
/// Отдельный [StatefulWidget] ради кэша изображения. Раньше здесь стоял
/// `Image.file(File(path))` прямо в дереве главного экрана: каждый его
/// пересбор создавал новый `FileImage`, а полноэкранное фото с телефона —
/// это несколько мегапикселей, которые декодировались заново. Теперь
/// провайдер создаётся один раз на путь и уменьшается до размера экрана
/// через [ResizeImage].
class _BackgroundLayer extends StatefulWidget {
  const _BackgroundLayer({
    required this.path,
    required this.blur,
    required this.dim,
    required this.snow,
    required this.snowSpeed,
  });

  final String? path;
  final double blur;
  final double dim;
  final bool snow;
  final int snowSpeed;

  @override
  State<_BackgroundLayer> createState() => _BackgroundLayerState();
}

class _BackgroundLayerState extends State<_BackgroundLayer> {
  ImageProvider? _provider;
  String? _resolvedPath;
  int? _decodeWidth;

  void _ensureProvider(double logicalWidth, double devicePixelRatio) {
    final path = widget.path;
    if (path == null) {
      _provider = null;
      _resolvedPath = null;
      return;
    }
    // Существование файла проверяем при смене пути, а не на каждом кадре:
    // картинку могли удалить из галереи уже после выбора, но синхронный
    // доступ к диску в build() — сам по себе источник подтормаживаний.
    final width = (logicalWidth * devicePixelRatio).round();
    if (_resolvedPath == path && _decodeWidth == width) return;
    _resolvedPath = path;
    _decodeWidth = width;
    if (!File(path).existsSync()) {
      _provider = null;
      return;
    }
    _provider = ResizeImage(
      FileImage(File(path)),
      width: width,
      // Высоту не задаём: ResizeImage сохранит пропорции, а BoxFit.cover
      // обрежет лишнее.
      policy: ResizeImagePolicy.fit,
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    _ensureProvider(media.size.width, media.devicePixelRatio);

    final layers = <Widget>[];
    if (_provider != null) {
      Widget image = Image(
        image: _provider!,
        fit: BoxFit.cover,
        // Готовый кадр не перепроявляем: без этого при каждом возврате на
        // экран картинка коротко мигала.
        gaplessPlayback: true,
      );
      if (widget.blur > 0) {
        image = ImageFiltered(
          imageFilter: ui.ImageFilter.blur(
            sigmaX: widget.blur,
            sigmaY: widget.blur,
            tileMode: TileMode.decal,
          ),
          child: image,
        );
      }
      layers.add(Positioned.fill(child: image));
      if (widget.dim > 0) {
        layers.add(
          Positioned.fill(
            child: ColoredBox(color: Colors.black.withValues(alpha: widget.dim)),
          ),
        );
      }
    }
    if (widget.snow) {
      layers.add(Positioned.fill(child: PixelSnow(speed: widget.snowSpeed)));
    }
    if (layers.isEmpty) return const SizedBox.shrink();
    return RepaintBoundary(child: Stack(fit: StackFit.expand, children: layers));
  }
}


/// Строка ленты в режиме выделения.
///
/// Собственные жесты сообщения (свайп, меню по долгому нажатию) здесь
/// отключены: пока идёт выбор, любое касание должно означать «отметить», а
/// не запускать действие над одним элементом.
class _SelectableRow extends StatelessWidget {
  const _SelectableRow({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ColoredBox(
        color: selected
            ? colors.accent.withValues(alpha: 0.18)
            : Colors.transparent,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.md),
              child: PixelCheckbox(
                value: selected,
                // Обрабатывает вся строка — отдельный обработчик у галочки
                // означал бы две зоны с разным поведением.
                onChanged: (_) => onTap(),
              ),
            ),
            Expanded(child: IgnorePointer(child: child)),
          ],
        ),
      ),
    );
  }
}


/// Поле «создать новое» с кнопкой подтверждения.
///
/// Отдельный виджет, потому что контроллер должен жить ровно столько,
/// сколько открыт лист: в замыкании внутри builder'а он создавался бы
/// заново на каждую перестройку и терял введённый текст.
class _NewNameField extends StatefulWidget {
  const _NewNameField({required this.hint, required this.onSubmit});

  final String hint;
  final ValueChanged<String> onSubmit;

  @override
  State<_NewNameField> createState() => _NewNameFieldState();
}

class _NewNameFieldState extends State<_NewNameField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    widget.onSubmit(value);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(hintText: widget.hint),
            onSubmitted: (_) => _submit(),
          ),
        ),
        AppSpacing.wGapSm,
        PixelButton(
          label: tr(context).save,
          expand: false,
          compact: true,
          onPressed: _submit,
        ),
      ],
    );
  }
}
