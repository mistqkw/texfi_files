import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../app.dart';
import '../core/crypto_util.dart';
import '../l10n/app_strings.dart';

/// Экран блокировки: запрашивает PIN (и/или биометрию) при запуске
/// приложения, если включено в настройках.
class PinLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const PinLockScreen({super.key, required this.onUnlocked});

  // Идёт системный биометрический диалог. Он сам уводит приложение в
  // inactive/paused, поэтому наблюдатель жизненного цикла (app.dart) на это
  // время не должен заново перекрывать экран блокировки — иначе двойной
  // запрос отпечатка по кругу.
  static bool authenticating = false;

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  String _entered = '';
  bool _error = false;
  final _auth = LocalAuthentication();

  // Локальная защита от повторного/параллельного вызова. Без неё — если
  // _tryBiometric() успевает стартовать дважды почти одновременно (например,
  // от автозапуска в initState и одновременного лишнего пересоздания
  // экрана) — второй вызов ArrayList native BiometricPrompt на Android
  // заклинивает: он не поддерживает конкурентные показы, и ВСЕ последующие
  // попытки (включая ручной тап по иконке отпечатка) молча зависают навсегда
  // без единого лога с нативной стороны. Именно это отдельно от статического
  // PinLockScreen.authenticating (тот защищает от re-lock жизненным циклом).
  bool _bioBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
  }

  Future<void> _tryBiometric() async {
    if (_bioBusy) return;
    final s = AppScope.of(context).settings;
    if (!s.biometricEnabled) return;
    _bioBusy = true;
    PinLockScreen.authenticating = true;
    try {
      final can =
          await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (!can) return;
      if (!mounted) return;
      final ok = await _auth.authenticate(
        localizedReason: tr(context).unlockReason,
        options: const AuthenticationOptions(biometricOnly: false),
      );
      if (ok) widget.onUnlocked();
    } catch (_) {
      // недоступно на этой платформе/устройстве — просто останется PIN
    } finally {
      _bioBusy = false;
      PinLockScreen.authenticating = false;
    }
  }

  Future<void> _tap(String d) async {
    if (_entered.length >= 6) return;
    setState(() {
      _entered += d;
      _error = false;
    });
    if (_entered.length == 4) await _verify();
  }

  void _backspace() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  Future<void> _verify() async {
    final s = AppScope.of(context).settings;
    final salt = await pinSalt();
    final hash = hashPin(_entered, salt);
    if (hash == s.pinHash) {
      widget.onUnlocked();
    } else {
      setState(() => _error = true);
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) setState(() => _entered = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = tr(context);
    final s = AppScope.of(context).settings;
    return Scaffold(
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_rounded, size: 48, color: cs.primary),
            const SizedBox(height: 16),
            Text(t.enterPin, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _entered.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _error
                        ? cs.error
                        : (filled ? cs.primary : cs.surfaceContainerHighest),
                  ),
                );
              }),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 280,
              child: Column(
                children: [
                  for (final row in [
                    ['1', '2', '3'],
                    ['4', '5', '6'],
                    ['7', '8', '9'],
                    [
                      s.biometricEnabled ? 'bio' : '',
                      '0',
                      'back',
                    ],
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: row.map((d) {
                          if (d.isEmpty) return const SizedBox(width: 64);
                          if (d == 'back') {
                            return _key(
                              icon: Icons.backspace_outlined,
                              onTap: _backspace,
                            );
                          }
                          if (d == 'bio') {
                            return _key(
                              icon: Icons.fingerprint_rounded,
                              onTap: _tryBiometric,
                            );
                          }
                          return _key(label: d, onTap: () => _tap(d));
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _key({String? label, IconData? icon, required VoidCallback onTap}) {
    return InkResponse(
      onTap: onTap,
      radius: 36,
      child: SizedBox(
        width: 64,
        height: 64,
        child: Center(
          child: icon != null
              ? Icon(icon)
              : Text(label!, style: const TextStyle(fontSize: 24)),
        ),
      ),
    );
  }
}
