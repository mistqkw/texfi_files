import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app.dart';
import '../app_state.dart';
import '../core/auth_service.dart';
import '../core/background.dart';
import '../core/crypto_util.dart';
import '../core/device_history.dart';
import '../core/settings.dart';
import '../core/version.dart';
import '../l10n/app_strings.dart';
import '../net/remote_input.dart';
import '../core/haptics.dart';
import '../core/theme/app_colors_ext.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles_ext.dart';
import '../core/theme/app_typography.dart';
import 'pixel/pixel_button.dart';
import 'pixel/pixel_card.dart';
import 'pixel/pixel_controls.dart';
import 'pixel/pixel_icons.dart';
import 'pixel/pixel_route.dart';
import 'admin_page.dart';
import 'format.dart';
import 'onboarding_screen.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  AppStrings get t => AppStrings(AppScope.of(context).settings.effectiveLanguageCode);
  bool? _ydotool; // доступен ли хоть какой-то движок ввода
  String _engine = '';
  int _versionTaps = 0;

  void _onVersionTap(BuildContext context, Settings s) {
    if (s.adminUnlocked) {
      Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AdminPage()));
      return;
    }
    _versionTaps++;
    if (_versionTaps >= 7) {
      s.adminUnlocked = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin settings unlocked')),
      );
      Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AdminPage()));
    } else if (_versionTaps >= 4) {
      final left = 7 - _versionTaps;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$left…'),
        duration: const Duration(milliseconds: 500),
      ));
    }
  }

  @override
  void initState() {
    super.initState();
    // Подстраховка независимо от того, откуда попали на экран: если
    // где-то ещё осталось открытое поле ввода с фокусом, клавиатура иначе
    // «протекает» на этот экран поверх списка настроек.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusManager.instance.primaryFocus?.unfocus();
    });
    RemoteInput.check().then((v) async {
      final e = await RemoteInput.engine();
      if (mounted) {
        setState(() {
          _ydotool = v;
          _engine = e;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.settings;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(t.settings)),
      body: ListenableBuilder(
        listenable: Listenable.merge([s, app.auth, app.cloud]),
        builder: (context, _) => ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            // Аккаунт — крупной карточкой сверху.
            _accountCard(context, app),
            const SizedBox(height: 8),
            _card(t.hLanguage,
                _langName(s), () => _open(t.hLanguage, _sectionLanguage),
                'language'),
            _card(t.hAppearance,
                t.catAppearanceSub, () => _open(t.hAppearance, _sectionAppearance),
                'appearance'),
            _card(t.hNetwork, t.catNetworkSub,
                () => _open(t.hNetwork, _sectionNetwork), 'network'),
            _card(t.hFilesSync, t.catFilesSyncSub,
                () => _open(t.hFilesSync, _sectionFilesSync), 'sync'),
            _card(t.hSecurity, t.catSecuritySub,
                () => _open(t.hSecurity, _sectionSecurity), 'security'),
            if (RemoteInput.supported)
              _card(t.hRemoteInput,
                  t.catRemoteSub, () => _open(t.hRemoteInput, _sectionRemote),
                  'remote'),
            _card(t.hPlayer,
                t.catPlayerSub, () => _open(t.hPlayer, _sectionPlayer), 'player'),
            _card(t.hDevice, t.catDeviceSub,
                () => _open(t.hDevice, _sectionDevice), 'device'),
            _card(t.hAbout, t.catAboutSub,
                () => _open(t.hAbout, _sectionAbout), 'about'),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => _onVersionTap(context, s),
                child: Text('TexFi files $kAppVersion',
                    style: TextStyle(color: cs.onSurfaceVariant)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _langName(Settings s) => switch (s.localeCode) {
        'en' => 'English',
        'ru' => 'Русский',
        'de' => 'Deutsch',
        'pl' => 'Polski',
        _ => t.systemLang,
      };

  // Карточка-категория в стиле TexFi.
  // slug — латинская метка во врезке рамки в терминальном режиме.
  Widget _card(String title, String subtitle, VoidCallback onTap,
      [String? slug]) {
    return _wrap(
      PixelTile(
        icon: _slugIcon(slug),
        title: title,
        subtitle: subtitle,
        trailing: PixelIcon(
          'chevron',
          size: 16,
          color: context.colors.textTertiary,
        ),
        onTap: onTap,
      ),
    );
  }

  /// Глиф категории. Имена глифов — строки, поэтому опечатка молча дала бы
  /// пустое место; неизвестный slug осознанно падает на 'gear'.
  static String _slugIcon(String? slug) => switch (slug) {
    'language' => 'globe',
    'appearance' => 'contrast',
    'network' => 'wifi',
    'sync' => 'node',
    'security' => 'shield',
    'remote' => 'text',
    'player' => 'note',
    'device' => 'device',
    'about' => 'warn',
    _ => 'gear',
  };

  Widget _accountCard(BuildContext context, AppState app) {
    return _wrap(
      PixelCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            _accountTile(context, app),
            _cloudStatus(context, app),
          ],
        ),
      ),
    );
  }

  void _open(String title, List<Widget> Function(BuildContext) body) {
    final app = AppScope.of(context);
    pixelPush(context, (ctx) => Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListenableBuilder(
        listenable: Listenable.merge([app.settings, app.auth, app.cloud]),
        builder: (ctx, _) => ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          children: body(ctx),
        ),
      ),
    ));
  }

  // ── Секции ──
  List<Widget> _sectionLanguage(BuildContext context) {
    final s = AppScope.of(context).settings;
    const names = {
      'system': null,
      'en': 'English',
      'ru': 'Русский',
      'de': 'Deutsch',
      'pl': 'Polski',
    };
    final cs = Theme.of(context).colorScheme;
    return [
      for (final e in names.entries)
        ListTile(
          title: Text(e.value ?? t.systemLang),
          trailing: s.localeCode == e.key
              ? Icon(Icons.check_rounded, color: cs.primary)
              : null,
          onTap: () => s.localeCode = e.key,
        ),
    ];
  }

  /// Внешний вид.
  ///
  /// Раньше тут жили скины под четыре ОС, четыре пресета палитры, стиль и
  /// скорость анимаций, стиль скругления пузырей, яркость обводки, выбор
  /// акцентного цвета и плотность — всё это косметика поверх одного и того
  /// же экрана. Осталось то, что либо меняет поведение, либо нужно для
  /// доступности.
  List<Widget> _sectionAppearance(BuildContext context) {
    final s = AppScope.of(context).settings;
    return [
      _sub(t.theme),
      for (final e in const {
        ThemeMode.system: 'System',
        ThemeMode.dark: 'Dark',
        ThemeMode.light: 'Light',
      }.entries)
        _radioTile(
          title: e.key == ThemeMode.system ? t.systemLang : e.value,
          selected: s.themeMode == e.key,
          onTap: () => s.themeMode = e.key,
        ),
      _sub(t.font),
      for (var i = 0; i < sansFamilyChoices.length; i++)
        _radioTile(
          // Подписываем шрифт им же самим — так видно, что выбираешь.
          title: _fontLabel(i),
          style: TextStyle(fontFamily: sansFamilyChoices[i], fontSize: 15),
          selected: s.fontChoice == i,
          onTap: () => s.fontChoice = i,
        ),
      _sub(t.uiScale),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
        child: Row(
          children: [
            Expanded(
              child: Slider(
                value: s.uiScale,
                min: 0.8,
                max: 1.4,
                divisions: 6,
                label: '${(s.uiScale * 100).round()}%',
                onChanged: (v) => s.uiScale = v,
              ),
            ),
            SizedBox(
              width: 52,
              child: Text(
                '${(s.uiScale * 100).round()}%',
                textAlign: TextAlign.end,
                style: context.text.statSmall,
              ),
            ),
          ],
        ),
      ),
      _switchTile(
        title: t.animations,
        subtitle: t.animationsSub,
        value: s.animations,
        onChanged: (v) => s.animations = v,
      ),
      _switchTile(
        title: t.haptics,
        subtitle: t.hapticsSub,
        value: s.hapticsEnabled,
        onChanged: (v) {
          s.hapticsEnabled = v;
          Haptics.enabled = v;
          // Отклик на само включение — иначе непонятно, сработало ли.
          if (v) Haptics.tap();
        },
      ),

      // --- Фон и эффекты ---
      //
      // Раздел вернулся после прошлой чистки. Тогда он ушёл целиком вместе
      // с действительно избыточным (погода с тремя ползунками, цвета
      // пузырей, пресеты палитр), но фото-фон, его размытие, затемнение и
      // снег — то, чем пользуются, а не косметика ради косметики.
      _sub(t.hBackground),
      _plainTile(
        icon: 'image',
        title: t.chatPhoto,
        subtitle: s.chatBgImage == null ? t.pickPhoto : null,
        trailing: s.chatBgImage == null
            ? null
            : PixelButton(
                label: t.removePhoto,
                expand: false,
                compact: true,
                primary: false,
                onPressed: () => s.chatBgImage = null,
              ),
        onTap: () => _pickBgImage(s),
      ),
      // Размытие и затемнение имеют смысл только поверх картинки, поэтому
      // без выбранного фото они просто не показываются — вместо того чтобы
      // висеть неактивными и озадачивать.
      if (s.chatBgImage != null) ...[
        _sliderTile(
          title: t.bgBlur,
          value: s.bgBlur,
          min: 0,
          max: 24,
          divisions: 12,
          label: s.bgBlur <= 0 ? t.off : s.bgBlur.round().toString(),
          onChanged: (v) => s.bgBlur = v,
        ),
        _sliderTile(
          title: t.bgDim,
          value: s.bgDim,
          min: 0,
          max: 0.8,
          divisions: 8,
          label: '${(s.bgDim * 100).round()}%',
          onChanged: (v) => s.bgDim = v,
        ),
      ],
      _switchTile(
        title: t.snow,
        subtitle: t.snowSub,
        value: s.snow,
        onChanged: (v) => s.snow = v,
      ),
      if (s.snow)
        for (final e in {
          0: t.snowSlow,
          1: t.snowMedium,
          2: t.snowFast,
        }.entries)
          _radioTile(
            title: e.value,
            selected: s.snowSpeed == e.key,
            onTap: () => s.snowSpeed = e.key,
          ),
    ];
  }

  /// Строка с ползунком и текущим значением справа.
  Widget _sliderTile({
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String label,
    required ValueChanged<double> onChanged,
  }) {
    return _wrap(
      PixelCard(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: context.text.tileTitle)),
                Text(label, style: context.text.statSmall),
              ],
            ),
            Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  String _fontLabel(int i) => switch (i) {
    1 => 'Roboto',
    2 => 'Mono',
    _ => 'Inter',
  };

  List<Widget> _sectionNetwork(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.settings;
    return [
      _switchTile(
        title: t.autoDiscovery,
        subtitle: t.autoDiscoverySub,
        value: s.autoDiscovery,
        onChanged: (v) {
          s.autoDiscovery = v;
          app.discovery.start();
        },
      ),
      ListTile(
        leading: const Icon(Icons.settings_ethernet_rounded),
        title: Text(t.discoveryPort),
        subtitle: Text('${s.discoveryPort}'),
        onTap: () => _editPort(context, s, app),
      ),
      _switchTile(
        title: t.autoAccept,
        value: s.autoAcceptFiles,
        onChanged: (v) => s.autoAcceptFiles = v,
      ),
      _switchTile(
        title: t.notifyReceive,
        value: s.notifyOnReceive,
        onChanged: (v) => s.notifyOnReceive = v,
      ),
      if (Platform.isAndroid)
        _switchTile(
          title: t.backgroundReceive,
          subtitle: t.backgroundReceiveSub,
          value: s.backgroundReceive,
          onChanged: (v) {
            s.backgroundReceive = v;
            if (v) {
              Background.start(t.bgTitle, t.bgText);
            } else {
              Background.stop();
            }
          },
        ),
    ];
  }

  List<Widget> _sectionFilesSync(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.settings;
    return [
      _sub(t.cloudRouting),
      for (final e in {
        0: t.cloudModeAuto,
        1: t.cloudModeAlways,
        2: t.cloudModeNever,
      }.entries)
        _radioTile(
          title: e.value,
          selected: s.cloudMode == e.key,
          onTap: () => s.cloudMode = e.key,
        ),
      _switchTile(
        title: t.selectiveSync,
        subtitle: t.selectiveSyncSub,
        value: s.selectiveSync,
        onChanged: (v) => s.selectiveSync = v,
      ),
      ListTile(
        leading: const Icon(Icons.pending_actions_rounded),
        title: Text(t.offlineQueue),
        subtitle: ListenableBuilder(
          listenable: app.queue,
          builder: (_, __) => Text('${app.queue.items.length}'),
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const _OfflineQueuePage()),
        ),
      ),
      ListTile(
        leading: const Icon(Icons.devices_other_rounded),
        title: Text(t.deviceHistory),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const _DeviceHistoryPage()),
        ),
      ),
    ];
  }

  List<Widget> _sectionSecurity(BuildContext context) {
    final s = AppScope.of(context).settings;
    return [
      _switchTile(
        title: t.encryptCloud,
        subtitle: t.encryptCloudSub,
        value: s.encryptCloud,
        onChanged: (v) => s.encryptCloud = v,
      ),
      _switchTile(
        title: t.pinLock,
        subtitle: t.pinLockSub,
        value: s.pinEnabled,
        onChanged: (v) async {
          if (v) {
            final ok = await _setupPin(context, s);
            if (ok) s.pinEnabled = true;
          } else {
            s.pinEnabled = false;
          }
        },
      ),
      if (s.pinEnabled) ...[
        if (Platform.isAndroid || Platform.isIOS)
          _switchTile(
            title: t.biometric,
            value: s.biometricEnabled,
            onChanged: (v) => s.biometricEnabled = v,
          ),
        ListTile(
          leading: const Icon(Icons.password_rounded),
          title: Text(t.setPin),
          onTap: () => _setupPin(context, s),
        ),
      ],
    ];
  }

  Future<bool> _setupPin(BuildContext context, Settings s) async {
    final first = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => _PinEntryPage(title: t.createPinStep1)),
    );
    if (first == null || !context.mounted) return false;
    final second = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => _PinEntryPage(title: t.createPinStep2)),
    );
    if (second == null) return false;
    if (first != second) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t.pinMismatch)));
      }
      return false;
    }
    final salt = await pinSalt();
    s.pinHash = hashPin(first, salt);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.pinSetDone)));
    }
    return true;
  }

  List<Widget> _sectionRemote(BuildContext context) {
    final s = AppScope.of(context).settings;
    return [
      _switchTile(
        title: t.allowTyping,
        subtitle: _ydotoolStatus(),
        value: s.remoteInputEnabled,
        onChanged: RemoteInput.supported && (_ydotool ?? false)
            ? (v) => s.remoteInputEnabled = v
            : null,
      ),
      if (RemoteInput.supported && _ydotool == false)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(t.wtypeHint,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.error, fontSize: 12)),
        ),
    ];
  }

  List<Widget> _sectionPlayer(BuildContext context) {
    final s = AppScope.of(context).settings;
    return [
      _switchTile(
        title: t.autoplay,
        value: s.autoplayMedia,
        onChanged: (v) => s.autoplayMedia = v,
      ),
      ListTile(
        leading: const Icon(Icons.volume_up_rounded),
        title: Text(t.playerVolume),
        subtitle: Slider(
          value: s.playerVolume,
          max: 100,
          divisions: 20,
          label: '${s.playerVolume.toStringAsFixed(0)}%',
          onChanged: (v) => s.playerVolume = v,
        ),
      ),
    ];
  }

  List<Widget> _sectionDevice(BuildContext context) {
    final s = AppScope.of(context).settings;
    return [
      ListTile(
        leading: const Icon(Icons.badge_outlined),
        title: Text(t.deviceName),
        subtitle: Text(s.deviceName),
        onTap: () => _editName(context, s),
      ),
    ];
  }

  List<Widget> _sectionAbout(BuildContext context) {
    final app = AppScope.of(context);
    return [
      ListTile(
        leading: const Icon(Icons.slideshow_rounded),
        title: Text(t.showOnboarding),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        ),
      ),
      ListTile(
        leading: Icon(Icons.delete_sweep_outlined,
            color: Theme.of(context).colorScheme.error),
        title: Text(t.clearAll),
        onTap: () => _confirmClear(context, app),
      ),
    ];
  }

  Widget _sub(String s) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.page,
      AppSpacing.lg,
      AppSpacing.page,
      AppSpacing.xs,
    ),
    child: PixelSectionHeader(title: s.toUpperCase()),
  );

  /// Строка-переключатель. Пиксельный свитч вместо материалового: у
  /// последнего скользящая круглая ручка — единственная мягкая форма,
  /// которая осталась бы во всём интерфейсе.
  Widget _switchTile({
    String? icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return _wrap(
      PixelTile(
        icon: icon,
        title: title,
        subtitle: subtitle,
        trailing: PixelSwitch(value: value, onChanged: onChanged),
        onTap: onChanged == null ? null : () => onChanged(!value),
      ),
    );
  }

  /// Строка выбора одного из вариантов.
  Widget _radioTile({
    required String title,
    TextStyle? style,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return _wrap(
      PixelCard(
        onTap: onTap,
        accent: selected,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Expanded(child: Text(title, style: style ?? context.text.tileTitle)),
            AppSpacing.wGapMd,
            PixelRadio(selected: selected, onTap: onTap),
          ],
        ),
      ),
    );
  }

  /// Обычная строка с произвольным правым элементом.
  Widget _plainTile({
    String? icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return _wrap(
      PixelTile(
        icon: icon,
        title: title,
        subtitle: subtitle,
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  /// Общие отступы строки настройки — чтобы они не подбирались заново в
  /// каждой секции.
  Widget _wrap(Widget child) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.page,
      AppSpacing.xs,
      AppSpacing.page,
      AppSpacing.xs,
    ),
    child: child,
  );

  Widget _accountTile(BuildContext context, AppState app) {
    return ListenableBuilder(
      listenable: app.auth,
      builder: (context, _) {
        final acc = app.auth.account;
        if (acc == null) {
          return ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: Text(t.signInGitHub),
            subtitle: Text(
                t.signInSubtitle),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _loginDialog(context, app),
          );
        }
        return ListTile(
          leading: CircleAvatar(
            backgroundImage:
                acc.avatarUrl != null ? NetworkImage(acc.avatarUrl!) : null,
            child: acc.avatarUrl == null
                ? Text(acc.login.characters.first.toUpperCase())
                : null,
          ),
          title: Text(acc.name?.isNotEmpty == true ? acc.name! : acc.login,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('@${acc.login} · GitHub'),
          trailing: TextButton(
            onPressed: () => app.auth.logout(),
            child: Text(t.signOut),
          ),
        );
      },
    );
  }

  Widget _cloudStatus(BuildContext context, AppState app) {
    return ListenableBuilder(
      listenable: Listenable.merge([app.auth, app.cloud]),
      builder: (context, _) {
        if (!app.auth.isLoggedIn) return const SizedBox.shrink();
        final cs = Theme.of(context).colorScheme;
        if (app.cloud.needsReauth) {
          return ListTile(
            leading: Icon(Icons.cloud_off_rounded, color: cs.error),
            title: Text(t.cloudOff),
            subtitle: Text(t.cloudReauth),
            trailing: FilledButton(
              onPressed: () => _loginDialog(context, app),
              child: Text(t.signInAgain),
            ),
          );
        }
        return ListTile(
          leading: Icon(Icons.cloud_done_rounded, color: cs.primary),
          title: Text(t.cloudOn),
          subtitle: Text(app.cloud.syncing
              ? t.cloudSyncing
              : t.cloudOnSub),
          trailing: app.cloud.syncing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : IconButton(
                  icon: const Icon(Icons.sync_rounded),
                  onPressed: () => app.cloud.pull(),
                ),
        );
      },
    );
  }

  void _loginDialog(BuildContext context, AppState app) {
    final auth = app.auth;
    auth.begin();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ListenableBuilder(
        listenable: auth,
        builder: (context, _) {
          if (auth.status == AuthStatus.success) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Navigator.canPop(context)) Navigator.pop(context);
            });
          }
          return AlertDialog(
            title: Text(t.loginTitle),
            content: _loginBody(context, auth),
            actions: [
              TextButton(
                onPressed: () {
                  auth.cancel();
                  Navigator.pop(context);
                },
                child: Text(t.close),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _loginBody(BuildContext context, AuthService auth) {
    final cs = Theme.of(context).colorScheme;
    if (auth.status == AuthStatus.error) {
      return Text(t.loginError(auth.error ?? ''),
          style: TextStyle(color: cs.error));
    }
    if (auth.status == AuthStatus.success) {
      return Text(t.loginDone);
    }
    if (auth.userCode == null) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(t.loginStep1),
        const SizedBox(height: 8),
        SelectableText(
          auth.userCode!,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
            color: cs.primary,
          ),
        ),
        const SizedBox(height: 16),
        Text(t.loginStep2),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => launchUrl(
            Uri.parse(auth.verificationUri ?? 'https://github.com/login/device'),
            mode: LaunchMode.externalApplication,
          ),
          icon: const Icon(Icons.open_in_new_rounded),
          label: Text(t.loginOpen),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
                width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 10),
            Text(t.loginWaiting,
                style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }

  String _ydotoolStatus() {
    if (!RemoteInput.supported) return t.inputOnlyLinux;
    if (_ydotool == null) return t.checking;
    return t.engineLabel(_engine);
  }

  Future<void> _pickBgImage(Settings s) async {
    try {
      String? src;
      if (Platform.isAndroid || Platform.isIOS) {
        final x = await ImagePicker()
            .pickImage(source: ImageSource.gallery, imageQuality: 90);
        src = x?.path;
      } else {
        final r = await FilePicker.platform.pickFiles(type: FileType.image);
        src = r?.files.single.path;
      }
      if (src == null) return;
      final dir = await getApplicationSupportDirectory();
      final dst =
          '${dir.path}/chat_bg_${DateTime.now().millisecondsSinceEpoch}.img';
      await File(src).copy(dst);
      s.chatBgImage = dst;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  void _editName(BuildContext context, Settings s) {
    final c = TextEditingController(text: s.deviceName);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.deviceName),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t.cancel)),
          FilledButton(
            onPressed: () {
              s.deviceName = c.text;
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _editPort(BuildContext context, Settings s, app) {
    final c = TextEditingController(text: '${s.discoveryPort}');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.discoveryPort),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t.cancel)),
          FilledButton(
            onPressed: () {
              final p = int.tryParse(c.text);
              if (p != null && p > 1024 && p < 65535) {
                s.discoveryPort = p;
                app.discovery.start();
              }
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _confirmClear(BuildContext context, app) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.clearConfirmTitle),
        content: Text(
            t.clearConfirmText),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              app.store.clearAll();
              Navigator.pop(context);
            },
            child: Text(t.clearBtn),
          ),
        ],
      ),
    );
  }
}

/// Экран ввода 4-значного PIN при настройке (шаг 1 и шаг 2 — подтверждение).
class _PinEntryPage extends StatefulWidget {
  final String title;
  const _PinEntryPage({required this.title});

  @override
  State<_PinEntryPage> createState() => _PinEntryPageState();
}

class _PinEntryPageState extends State<_PinEntryPage> {
  String _entered = '';

  void _tap(String d) {
    if (_entered.length >= 4) return;
    setState(() => _entered += d);
    if (_entered.length == 4) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) Navigator.of(context).pop(_entered);
      });
    }
  }

  void _backspace() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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
                  color: filled ? cs.primary : cs.surfaceContainerHighest,
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
                  ['', '0', 'back'],
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: row.map((d) {
                        if (d.isEmpty) return const SizedBox(width: 64);
                        if (d == 'back') {
                          return InkResponse(
                            onTap: _backspace,
                            radius: 36,
                            child: const SizedBox(
                              width: 64,
                              height: 64,
                              child: Center(child: Icon(Icons.backspace_outlined)),
                            ),
                          );
                        }
                        return InkResponse(
                          onTap: () => _tap(d),
                          radius: 36,
                          child: SizedBox(
                            width: 64,
                            height: 64,
                            child: Center(
                                child: Text(d,
                                    style: const TextStyle(fontSize: 24))),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Список отложенных отправок (оффлайн-очередь).
class _OfflineQueuePage extends StatelessWidget {
  const _OfflineQueuePage();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = tr(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.offlineQueue)),
      body: ListenableBuilder(
        listenable: app.queue,
        builder: (context, _) {
          if (app.queue.items.isEmpty) {
            return Center(child: Text(t.offlineQueueEmpty));
          }
          return ListView(
            children: [
              for (final q in app.queue.items)
                ListTile(
                  leading: Icon(q.kind == 'text'
                      ? Icons.chat_bubble_outline_rounded
                      : Icons.insert_drive_file_outlined),
                  title: Text(q.kind == 'text'
                      ? (q.text ?? '')
                      : q.filePath!.split('/').last),
                  subtitle: Text(q.peerName),
                  trailing: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => app.queue.cancel(q),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// История устройств: когда последний раз синкалось, сколько передано.
class _DeviceHistoryPage extends StatelessWidget {
  const _DeviceHistoryPage();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = tr(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.deviceHistory)),
      body: ListenableBuilder(
        listenable: app.deviceHistory,
        builder: (context, _) {
          final list = app.deviceHistory.all;
          if (list.isEmpty) {
            return const Center(child: Icon(Icons.devices_other_rounded, size: 48));
          }
          return ListView(
            children: [
              for (final d in list) _deviceTile(context, d),
            ],
          );
        },
      ),
    );
  }

  Widget _deviceTile(BuildContext context, DeviceStat d) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: cs.primaryContainer,
        child: Icon(Icons.smartphone_rounded, color: cs.onPrimaryContainer),
      ),
      title: Text(d.name),
      subtitle: Text(
          '${d.lastSeen.toLocal()}'.split('.').first),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('↑ ${humanSize(d.bytesSent)}', style: const TextStyle(fontSize: 11)),
          Text('↓ ${humanSize(d.bytesReceived)}', style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
