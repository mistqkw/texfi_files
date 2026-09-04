import 'dart:io';
import 'package:flutter/material.dart';
import '../core/theme/app_colors_ext.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles_ext.dart';
import 'pixel/pixel_card.dart';
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _app = AppScope.of(context);
    _loadIp();
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
          IconButton(
            tooltip: t.showQr,
            icon: const Icon(Icons.qr_code_rounded),
            onPressed: _showMyQr,
          ),
          if (mobile)
            IconButton(
              tooltip: t.scanQr,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              onPressed: _scanQr,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addByIp,
        icon: const Icon(Icons.add_link_rounded),
        label: Text(t.byIp),
      ),
      body: ListenableBuilder(
        listenable:
            Listenable.merge([_app.discovery, _app.settings, _app.auth]),
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
                              for (final p in peers) _peerTile(context, p),
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
            PixelIcon('laptop', size: 26, color: colors.accent),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Пиксельный сканер вместо CircularProgressIndicator: тот
            // крутится одинаково и когда идёт опрос сети, и когда всё
            // зависло. Здесь видно и сам факт опроса, и его темп.
            const PixelScanner(size: 88),
            AppSpacing.gapXl,
            Text(t.searchingAccount, style: context.text.screenTitle),
            AppSpacing.gapSm,
            Text(
              t.searchingAccountSub,
              textAlign: TextAlign.center,
              style: context.text.bodySmall,
            ),
          ],
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
            : '');
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
                  labelText: t.ipAddress, hintText: '192.168.0.50'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: portC,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: t.port, hintText: '…'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t.cancel)),
          FilledButton(
            onPressed: () async {
              final ip = ipC.text.trim();
              final port = int.tryParse(portC.text.trim());
              Navigator.pop(context);
              if (ip.isEmpty || port == null) return;
              final name = await _app.discovery.addManual(ip, port);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(name != null
                    ? t.connectedTo(name)
                    : t.connectFail('$ip:$port')),
              ));
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
              onPressed: () => Navigator.pop(context), child: Text(t.close)),
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
                ? SnackBarAction(
                    label: t.settings,
                    onPressed: openAppSettings,
                  )
                : null,
          ),
        );
        return;
      }
    }
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _QrScannerPage()),
    );
    if (result == null || !result.startsWith('$_qrScheme:')) return;
    final parts = result.split(':');
    if (parts.length != 3) return;
    final ip = parts[1];
    final port = int.tryParse(parts[2]);
    if (port == null) return;
    final name = await _app.discovery.addManual(ip, port);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          name != null ? t.connectedTo(name) : t.connectFail('$ip:$port')),
    ));
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
            icon: Icon(_torch ? Icons.flash_on_rounded : Icons.flash_off_rounded),
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
