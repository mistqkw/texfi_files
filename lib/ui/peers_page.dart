import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../core/haptics.dart';
import '../core/theme/app_colors_ext.dart';
import '../core/theme/app_motion.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles_ext.dart';
import 'pixel/pixel_button.dart';
import 'pixel/pixel_card.dart';
import 'pixel/pixel_entrance.dart';
import 'pixel/pixel_icons.dart';
import 'pixel/pixel_scanner.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../app.dart';
import '../l10n/app_strings.dart';
import '../app_state.dart';
import '../core/models.dart';

const _qrScheme = 'texfi';

class PeersPage extends StatefulWidget {
  const PeersPage({super.key});

  @override
  State<PeersPage> createState() => _PeersPageState();
}

class _PeersPageState extends State<PeersPage> {
  String? _localIp;
  late AppState _app;
  AppStrings get t => AppStrings(_app.settings.effectiveLanguageCode);

  /// Идентификаторы устройств, о которых мы уже сообщили. Нужны, чтобы
  /// отклик приходил на появление устройства, а не на каждое уведомление
  /// discovery: тот шлёт notifyListeners на каждый цикл опроса, включая
  /// циклы, в которых ничего не изменилось.
  final Set<String> _announced = {};
  bool _primed = false;

  /// Отдельно от [_announced]: тот в момент срабатывания слушателя УЖЕ
  /// помечает id как известный (нужно для тайминга вибро+подсказки), так
  /// что к моменту построения этой же карточки в билде он всегда «уже
  /// объявлен» — анимация появления по нему никогда бы не сработала.
  /// Здесь — то же самое, что `_seen` в ленте home_page.dart: множество,
  /// которое заполняется прямо во время построения списка карточек, а не
  /// слушателем.
  final Set<String> _seenTileIds = {};

  /// Сколько ждать, прежде чем сменить «идёт поиск» на подсказку.
  ///
  /// Опрос реестра идёт раз в 12 секунд, поэтому раньше первого-второго
  /// цикла говорить «никого нет» рано — это было бы неправдой.
  static const Duration _patience = Duration(seconds: 20);

  Timer? _patienceTimer;
  bool _waitedLongEnough = false;

  void _restartPatience() {
    _patienceTimer?.cancel();
    _waitedLongEnough = false;
    _patienceTimer = Timer(_patience, () {
      if (mounted) setState(() => _waitedLongEnough = true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _app = AppScope.of(context);
    _app.discovery.addListener(_onPeersChanged);
    _restartPatience();
    _loadIp();
  }

  @override
  void dispose() {
    _patienceTimer?.cancel();
    _app.discovery.removeListener(_onPeersChanged);
    super.dispose();
  }

  void _onPeersChanged() {
    final ids = _app.peers.where((p) => p.online).map((p) => p.id).toSet();
    if (!_primed) {
      // Первый заход: устройства, уже найденные к моменту открытия экрана,
      // не «обнаружены только что» — молча запоминаем их.
      _announced.addAll(ids);
      _primed = true;
      return;
    }
    final fresh = ids.difference(_announced);
    _announced
      ..removeWhere((id) => !ids.contains(id))
      ..addAll(ids);
    // Кто-то появился — отсчёт терпения начинается заново: если устройство
    // потом пропадёт, подсказка не выскочит мгновенно.
    if (ids.isNotEmpty) _restartPatience();
    if (fresh.isEmpty) return;
    Haptics.peerFound();
    // Устройство, появившееся в сети, — событие, а не строчка, которая
    // молча дописалась в список: без отклика человек узнаёт о нём, только
    // если в этот момент смотрел на экран.
    if (!mounted) return;
    final name = _app.peers
        .firstWhere((p) => p.id == fresh.first, orElse: () => _app.peers.first)
        .name;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Row(
            children: [
              PixelIcon('node', size: 16, color: context.colors.accent),
              AppSpacing.wGapMd,
              Expanded(child: Text(t.peerAppeared(name))),
            ],
          ),
        ),
      );
  }

  Future<void> _loadIp() async {
    try {
      final ifs = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final i in ifs) {
        for (final a in i.addresses) {
          if (!a.isLoopback) {
            if (mounted) setState(() => _localIp = a.address);
            return;
          }
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final mobile = Platform.isAndroid || Platform.isIOS;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.devicesTitle),
        actions: [
          PixelIconButton(
            icon: 'qr',
            size: 18,
            tooltip: t.showQr,
            onPressed: _showMyQr,
          ),
          if (mobile)
            PixelIconButton(
              icon: 'search',
              size: 18,
              tooltip: t.scanQr,
              onPressed: _scanQr,
            ),
          AppSpacing.wGapXs,
        ],
      ),
      // Обычная кнопка вместо FloatingActionButton: тот круглый и с мягкой
      // тенью — последняя материаловская форма на экране.
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(right: AppSpacing.xs),
        child: PixelButton(
          label: t.byIp,
          icon: 'plus',
          expand: false,
          onPressed: _addByIp,
        ),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          _app.discovery,
          _app.settings,
          _app.auth,
        ]),
        builder: (context, _) {
          final peers = _app.peers;
          return Column(
            children: [
              _selfCard(context),
              const Divider(height: 1),
              Expanded(
                child: !_app.auth.isLoggedIn
                    ? _needLogin(context)
                    : peers.isEmpty
                    ? _searching(context)
                    : ListView(
                        children: [
                          for (final p in peers) _peerEntry(context, p),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _selfCard(BuildContext context) {
    final colors = context.colors;
    final port = _app.server.port;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.xs,
      ),
      child: PixelCard(
        accent: true,
        child: Row(
          children: [
            // Платформо-зависимая иконка, как у остальных карточек ниже —
            // раньше здесь был жёстко зашит 'laptop', и на Android
            // карточка «это устройство» показывала бы ноутбук.
            PixelIcon(
              Platform.isAndroid ? 'phone' : 'laptop',
              size: 26,
              color: colors.accent,
            ),
            AppSpacing.wGapLg,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_app.settings.deviceName, style: context.text.tileTitle),
                  const SizedBox(height: 2),
                  Text(
                    _localIp != null
                        ? '${t.thisDevice} · $_localIp:$port'
                        : '${t.thisDevice} · $port',
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
            _StatusDot(online: true),
          ],
        ),
      ),
    );
  }

  Widget _searching(BuildContext context) {
    // Через [_patience] бесконечное «осматриваюсь» сменяется подсказкой с
    // конкретным следующим шагом. Висящий сканер сам по себе не сообщает
    // ничего: непонятно, ищет он или сломался, и что делать дальше.
    final waiting = !_waitedLongEnough;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        // Та же связка fade+scale, что у переходов между экранами
        // (pixel_route.dart) — раньше подсказка после ожидания просто
        // мгновенно подменяла сканер, без единого кадра перехода.
        child: AnimatedSwitcher(
          duration: AppMotion.route,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
              child: child,
            ),
          ),
          child: Column(
            key: ValueKey(waiting),
            mainAxisSize: MainAxisSize.min,
            children: [
              // Пиксельный сканер вместо CircularProgressIndicator: тот
              // крутится одинаково и когда идёт опрос сети, и когда всё
              // зависло. Здесь видно и сам факт опроса, и его темп.
              if (waiting)
                const PixelScanner(size: 88)
              else
                PixelIcon('wifi', size: 72, color: context.colors.textTertiary),
              AppSpacing.gapXl,
              Text(
                waiting ? t.searchingAccount : t.nobodyAroundTitle,
                textAlign: TextAlign.center,
                style: context.text.screenTitle,
              ),
              AppSpacing.gapSm,
              Text(
                waiting ? t.searchingAccountSub : t.nobodyAroundText,
                textAlign: TextAlign.center,
                style: context.text.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _needLogin(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PixelIcon('shield', size: 68, color: colors.textTertiary),
            AppSpacing.gapXl,
            Text(t.needLoginTitle, style: context.text.screenTitle),
            AppSpacing.gapSm,
            Text(
              t.needLoginText,
              textAlign: TextAlign.center,
              style: context.text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  /// Карточка устройства с ключом по id и анимацией появления для новых.
  ///
  /// Список сортируется по имени (см. Discovery.peers), поэтому позиции
  /// сдвигаются, когда появляется устройство, которое по алфавиту встаёт
  /// раньше уже показанных — без ValueKey Flutter сверял бы карточки по
  /// ПОЗИЦИИ в списке, а не по устройству, которое они показывают, и
  /// путал бы, какая карточка новая, а какая просто сдвинулась.
  Widget _peerEntry(BuildContext context, Peer p) {
    final isNew = !_seenTileIds.contains(p.id);
    _seenTileIds.add(p.id);
    final tile = _peerTile(context, p);
    return KeyedSubtree(
      key: ValueKey(p.id),
      child: isNew ? PixelEntrance(child: tile) : tile,
    );
  }

  Widget _peerTile(BuildContext context, Peer p) {
    final colors = context.colors;
    final trusted = _app.isTrusted(p);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.xs,
        AppSpacing.page,
        AppSpacing.xs,
      ),
      child: PixelCard(
        child: Row(
          children: [
            PixelIcon(
              p.platform == 'android' ? 'phone' : 'laptop',
              size: 24,
              color: p.online ? colors.accent : colors.textTertiary,
            ),
            AppSpacing.wGapLg,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          p.name,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.tileTitle,
                        ),
                      ),
                      if (trusted) ...[
                        AppSpacing.wGapXs,
                        PixelIcon('check', size: 13, color: colors.success),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    trusted
                        ? '${p.address} · ${t.yourAccount}'
                        : '${p.address} · ${p.online ? t.online : t.offline}',
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
            _StatusDot(online: p.online),
          ],
        ),
      ),
    );
  }

  void _addByIp() {
    final ipC = TextEditingController(
      text: _localIp != null
          ? '${_localIp!.substring(0, _localIp!.lastIndexOf('.') + 1)}'
          : '',
    );
    final portC = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.connectByIp),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ipC,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: t.ipAddress,
                hintText: '192.168.0.50',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: portC,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: t.port, hintText: '…'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final ip = ipC.text.trim();
              final port = int.tryParse(portC.text.trim());
              Navigator.pop(context);
              if (ip.isEmpty || port == null) return;
              final name = await _app.discovery.addManual(ip, port);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    name != null
                        ? t.connectedTo(name)
                        : t.connectFail('$ip:$port'),
                  ),
                ),
              );
            },
            child: Text(t.connect),
          ),
        ],
      ),
    );
  }

  void _showMyQr() {
    final ip = _localIp;
    final port = _app.server.port;
    if (ip == null) return;
    final data = '$_qrScheme:$ip:$port';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.showQr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(data: data, size: 220),
            const SizedBox(height: 12),
            Text('$ip:$port', style: const TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.close),
          ),
        ],
      ),
    );
  }

  Future<void> _scanQr() async {
    // Просим доступ к камере ЗАРАНЕЕ и явно: внутренний запрос mobile_scanner
    // гонится со стартом CameraX и часто падал с расплывчатым «Could not start
    // the camera». Когда разрешение уже выдано, сканер стартует чисто.
    if (Platform.isAndroid || Platform.isIOS) {
      final status = await Permission.camera.request();
      if (!mounted) return;
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.cameraPermissionDenied),
            action: status.isPermanentlyDenied
                ? SnackBarAction(label: t.settings, onPressed: openAppSettings)
                : null,
          ),
        );
        return;
      }
    }
    final result = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const _QrScannerPage()));
    if (result == null || !result.startsWith('$_qrScheme:')) return;
    final parts = result.split(':');
    if (parts.length != 3) return;
    final ip = parts[1];
    final port = int.tryParse(parts[2]);
    if (port == null) return;
    final name = await _app.discovery.addManual(ip, port);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          name != null ? t.connectedTo(name) : t.connectFail('$ip:$port'),
        ),
      ),
    );
  }
}

/// Полноэкранный сканер QR (Android/iOS) — считывает код пары другого
/// устройства и возвращает его строковое содержимое.
class _QrScannerPage extends StatefulWidget {
  const _QrScannerPage();

  @override
  State<_QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<_QrScannerPage> {
  // Разрешение камеры уже выдано до открытия этого экрана (см. _scanQr),
  // поэтому даём mobile_scanner стартовать штатно (autoStart по умолчанию) —
  // это самый обкатанный путь; ручной старт постфреймом раньше конфликтовал
  // с внутренним запросом разрешения и давал generic-ошибку.
  final _controller = MobileScannerController();
  bool _handled = false; // защита от многократного pop по одному коду
  bool _torch = false;

  Future<void> _start() async {
    try {
      await _controller.start();
    } catch (_) {
      // Ошибка попадёт в value.error и обработается в errorBuilder ниже.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = tr(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(t.scanQr),
        actions: [
          IconButton(
            icon: Icon(
              _torch ? Icons.flash_on_rounded : Icons.flash_off_rounded,
            ),
            onPressed: () {
              _controller.toggleTorch();
              setState(() => _torch = !_torch);
            },
          ),
        ],
      ),
      body: MobileScanner(
        controller: _controller,
        overlayBuilder: (context, constraints) => const _ScanFrame(),
        onDetect: (capture) {
          if (_handled) return;
          final codes = capture.barcodes;
          if (codes.isEmpty) return;
          final value = codes.first.rawValue;
          if (value != null) {
            _handled = true;
            Navigator.of(context).pop(value);
          }
        },
        errorBuilder: (context, error, child) {
          final denied =
              error.errorCode == MobileScannerErrorCode.permissionDenied;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    denied
                        ? Icons.no_photography_outlined
                        : Icons.error_outline_rounded,
                    size: 48,
                    color: Colors.white70,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    denied ? t.cameraPermissionDenied : t.scanQrError,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _start,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(t.retry),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Полупрозрачная маска с прозрачным «окном»-прицелом по центру.
class _ScanFrame extends StatelessWidget {
  const _ScanFrame();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

/// Индикатор состояния устройства.
///
/// Квадрат, а не круг: круглая точка в 8px на пиксельной сетке всегда
/// выходит кривой — сглаживание размывает её в пятно.
class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: online ? colors.success : colors.textTertiary,
        border: Border.all(color: colors.divider, width: 1),
      ),
    );
  }
}
