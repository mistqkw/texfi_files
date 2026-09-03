import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
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
import 'admin_page.dart';
import 'format.dart';
import 'onboarding_screen.dart';
import 'terminal.dart';
import 'pixel/pixel_controls.dart';
import 'pixel/pixel_icons.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  AppStrings get t => AppStrings(AppScope.of(context).settings.effectiveLanguageCode);
  static const _seeds = <int>[
    0xFF4C7CFF, 0xFF2A63FF, 0xFF6C5CE7, 0xFF0984E3,
    0xFF00B894, 0xFF00CEC9, 0xFFE17055, 0xFFE84393,
    0xFFFF7675, 0xFFFDCB6E, 0xFFA55EEA, 0xFF576574,
  ];

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
            _card(cs, 'globe', t.hLanguage,
                _langName(s), () => _open(t.hLanguage, _sectionLanguage),
                'language'),
            _card(cs, 'palette', t.hAppearance,
                t.catAppearanceSub, () => _open(t.hAppearance, _sectionAppearance),
                'appearance'),
            _card(cs, 'picture', t.hBackground,
                t.catBackgroundSub, () => _open(t.hBackground, _sectionBackground),
                'background'),
            _card(cs, 'wifi', t.hNetwork, t.catNetworkSub,
                () => _open(t.hNetwork, _sectionNetwork), 'network'),
            _card(cs, 'sync', t.hFilesSync, t.catFilesSyncSub,
                () => _open(t.hFilesSync, _sectionFilesSync), 'sync'),
            _card(cs, 'lock', t.hSecurity, t.catSecuritySub,
                () => _open(t.hSecurity, _sectionSecurity), 'security'),
            if (RemoteInput.supported)
              _card(cs, 'keyboard', t.hRemoteInput,
                  t.catRemoteSub, () => _open(t.hRemoteInput, _sectionRemote),
                  'remote'),
            _card(cs, 'play', t.hPlayer,
                t.catPlayerSub, () => _open(t.hPlayer, _sectionPlayer), 'player'),
            _card(cs, 'badge', t.hDevice, t.catDeviceSub,
                () => _open(t.hDevice, _sectionDevice), 'device'),
            _card(cs, 'info', t.hAbout, t.catAboutSub,
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

  // Карточка-категория: пиксель-карточка с врезанной подписью.
  // slug — латинская метка во врезке рамки.
  Widget _card(ColorScheme cs, String icon, String title, String subtitle,
      VoidCallback onTap, [String? slug]) {
    final s = AppScope.of(context).settings;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: TerminalBox(
        label: slug,
        borderColor: Colors.white.withValues(alpha: s.borderOpacity),
        labelColor: cs.primary,
        padding: EdgeInsets.zero,
        child: ListTile(
          leading: PixelIcon(icon, color: cs.primary, size: 22),
          title: Text(title,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle:
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: PixelIcon('chevron_right'),
          onTap: onTap,
        ),
      ),
    );
  }

  Widget _accountCard(BuildContext context, AppState app) {
    final cs = Theme.of(context).colorScheme;
    final s = app.settings;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: TerminalBox(
        label: 'account',
        borderColor: Colors.white.withValues(alpha: s.borderOpacity),
        labelColor: cs.primary,
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

  // Открыть под-экран категории.
  void _open(String title, List<Widget> Function(BuildContext) body) {
    final app = AppScope.of(context);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (ctx) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ListenableBuilder(
          listenable: Listenable.merge([app.settings, app.auth, app.cloud]),
          builder: (ctx, _) => ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: body(ctx),
          ),
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
              ? PixelIcon('check', color: cs.primary)
              : null,
          onTap: () => s.localeCode = e.key,
        ),
    ];
  }

  List<Widget> _sectionAppearance(BuildContext context) {
    final s = AppScope.of(context).settings;
    return [
      ListTile(
        leading: PixelIcon('density'),
        title: Text(t.borderBrightness),
        subtitle: Slider(
          value: s.borderOpacity,
          min: 0.06,
          max: 1.0,
          divisions: 24,
          label: '${(s.borderOpacity * 100).round()}%',
          onChanged: (v) => s.borderOpacity = v,
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child:
            Text(t.prefixContent, style: Theme.of(context).textTheme.labelLarge),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Wrap(
          spacing: 8,
          children: [
            FilterChip(
              label: Text(t.prefixDevice),
              selected: s.prefixDevice,
              onSelected: (v) => s.prefixDevice = v,
            ),
            FilterChip(
              label: Text(t.prefixType),
              selected: s.prefixType,
              onSelected: (v) => s.prefixType = v,
            ),
            FilterChip(
              label: Text(t.prefixSize),
              selected: s.prefixSize,
              onSelected: (v) => s.prefixSize = v,
            ),
            FilterChip(
              label: Text(t.prefixTime),
              selected: s.prefixTime,
              onSelected: (v) => s.prefixTime = v,
            ),
          ],
        ),
      ),
      ListTile(
        leading: PixelIcon('sun'),
        title: Text(t.theme),
        trailing: SegmentedButton<ThemeMode>(
          segments: [
            ButtonSegment(value: ThemeMode.light, icon: PixelIcon('sun')),
            ButtonSegment(
                value: ThemeMode.system, icon: PixelIcon('auto')),
            ButtonSegment(value: ThemeMode.dark, icon: PixelIcon('moon')),
          ],
          selected: {s.themeMode},
          onSelectionChanged: (v) => s.themeMode = v.first,
        ),
      ),
      SwitchListTile(
        secondary: PixelIcon('moon'),
        title: Text(t.oledBg),
        subtitle: Text(t.oledBgSub),
        value: s.pureBlack,
        onChanged: (v) => s.pureBlack = v,
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Text(t.accentColor,
            style: Theme.of(context).textTheme.labelLarge),
      ),
      SizedBox(
        height: 56,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            for (final c in _seeds) _colorDot(s, c),
            _customColorDot(context, s),
          ],
        ),
      ),
      ListTile(
        leading: PixelIcon('font'),
        title: Text(t.font),
        trailing: SegmentedButton<int>(
          segments: [
            ButtonSegment(value: 0, label: Text(t.fontNormal)),
            ButtonSegment(value: 2, label: Text('Mono')),
          ],
          selected: {s.fontChoice == 1 ? 0 : s.fontChoice},
          showSelectedIcon: false,
          onSelectionChanged: (v) => s.fontChoice = v.first,
        ),
      ),
      ListTile(
        leading: PixelIcon('scale'),
        title: Text(t.uiScale),
        subtitle: Slider(
          value: s.uiScale,
          min: 0.8,
          max: 1.4,
          divisions: 6,
          label: '${(s.uiScale * 100).toStringAsFixed(0)}%',
          onChanged: (v) => s.uiScale = v,
        ),
      ),
      SwitchListTile(
        secondary: PixelIcon('density'),
        title: Text(t.compact),
        subtitle: Text(t.compactSub),
        value: s.compact,
        onChanged: (v) => s.compact = v,
      ),
      SwitchListTile(
        secondary: PixelIcon('spark'),
        title: Text(t.animations),
        subtitle: Text(t.animationsSub),
        value: s.animations,
        onChanged: (v) => s.animations = v,
      ),
    ];
  }

  List<Widget> _sectionBackground(BuildContext context) {
    final s = AppScope.of(context).settings;
    return [
      ListTile(
        leading: PixelIcon('picture'),
        title: Text(t.chatPhoto),
        subtitle: s.chatBgImage != null ? Text(t.pickPhoto) : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (s.chatBgImage != null)
              IconButton(
                icon: PixelIcon('close'),
                onPressed: () => s.chatBgImage = null,
              ),
            IconButton(
              icon: PixelIcon('picture'),
              onPressed: () => _pickBgImage(s),
            ),
          ],
        ),
      ),
      if (s.chatBgImage != null) ...[
        ListTile(
          leading: PixelIcon('blur'),
          title: Text(t.bgEffectLabel),
          trailing: SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 0, label: Text(t.effectNone)),
              ButtonSegment(value: 1, label: Text(t.effectBlur)),
              ButtonSegment(value: 2, label: Text(t.effectPixel)),
            ],
            selected: {s.bgEffect},
            showSelectedIcon: false,
            onSelectionChanged: (v) => s.bgEffect = v.first,
          ),
        ),
        ListTile(
          leading: PixelIcon('moon'),
          title: Text(t.dimLabel),
          subtitle: Slider(
            value: s.bgDim,
            max: 0.8,
            divisions: 8,
            onChanged: (v) => s.bgDim = v,
          ),
        ),
      ],
    ];
  }

  List<Widget> _sectionNetwork(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.settings;
    return [
      SwitchListTile(
        secondary: PixelIcon('wifi'),
        title: Text(t.autoDiscovery),
        subtitle: Text(t.autoDiscoverySub),
        value: s.autoDiscovery,
        onChanged: (v) {
          s.autoDiscovery = v;
          app.discovery.start();
        },
      ),
      SwitchListTile(
        secondary: PixelIcon('sync'),
        title: Text(t.autoAccept),
        value: s.autoAcceptFiles,
        onChanged: (v) => s.autoAcceptFiles = v,
      ),
      SwitchListTile(
        secondary: PixelIcon('bell'),
        title: Text(t.notifyReceive),
        value: s.notifyOnReceive,
        onChanged: (v) => s.notifyOnReceive = v,
      ),
      if (Platform.isAndroid)
        SwitchListTile(
          secondary: PixelIcon('cloud'),
          title: Text(t.backgroundReceive),
          subtitle: Text(t.backgroundReceiveSub),
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
      Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: PixelIcon('gear'),
          title: Text(t.advanced),
          childrenPadding: EdgeInsets.zero,
          children: [
            ListTile(
              leading: PixelIcon('link'),
              title: Text(t.discoveryPort),
              subtitle: Text('${s.discoveryPort}'),
              onTap: () => _editPort(context, s, app),
            ),
          ],
        ),
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
        ListTile(
          title: Text(e.value),
          trailing: PixelRadio<int>(
            value: e.key,
            groupValue: s.cloudMode,
            onChanged: (v) => s.cloudMode = v,
          ),
          onTap: () => s.cloudMode = e.key,
        ),
      SwitchListTile(
        secondary: PixelIcon('sync'),
        title: Text(t.selectiveSync),
        subtitle: Text(t.selectiveSyncSub),
        value: s.selectiveSync,
        onChanged: (v) => s.selectiveSync = v,
      ),
      ListTile(
        leading: PixelIcon('clock'),
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
        leading: PixelIcon('devices'),
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
      SwitchListTile(
        secondary: PixelIcon('shield'),
        title: Text(t.encryptCloud),
        subtitle: Text(t.encryptCloudSub),
        value: s.encryptCloud,
        onChanged: (v) => s.encryptCloud = v,
      ),
      SwitchListTile(
        secondary: PixelIcon('keypad'),
        title: Text(t.pinLock),
        subtitle: Text(t.pinLockSub),
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
          SwitchListTile(
            secondary: PixelIcon('fingerprint'),
            title: Text(t.biometric),
            value: s.biometricEnabled,
            onChanged: (v) => s.biometricEnabled = v,
          ),
        ListTile(
          leading: PixelIcon('keypad'),
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
      SwitchListTile(
        secondary: PixelIcon('keyboard'),
        title: Text(t.allowTyping),
        subtitle: Text(_ydotoolStatus()),
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
      SwitchListTile(
        secondary: PixelIcon('play'),
        title: Text(t.autoplay),
        value: s.autoplayMedia,
        onChanged: (v) => s.autoplayMedia = v,
      ),
      ListTile(
        leading: PixelIcon('volume'),
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
        leading: PixelIcon('badge'),
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
        leading: PixelIcon('picture'),
        title: Text(t.showOnboarding),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        ),
      ),
      ListTile(
        leading: PixelIcon('trash',
            color: Theme.of(context).colorScheme.error),
        title: Text(t.clearAll),
        onTap: () => _confirmClear(context, app),
      ),
    ];
  }

  Widget _sub(String s) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(s,
            style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 12)),
      );

  Widget _accountTile(BuildContext context, AppState app) {
    return ListenableBuilder(
      listenable: app.auth,
      builder: (context, _) {
        final acc = app.auth.account;
        if (acc == null) {
          return ListTile(
            leading: PixelIcon('badge'),
            title: Text(t.signInGitHub),
            subtitle: Text(
                t.signInSubtitle),
            trailing: PixelIcon('chevron_right'),
            onTap: () => _loginDialog(context, app),
          );
        }
        return ListTile(
          leading: PixelAvatar(
            image: acc.avatarUrl != null ? NetworkImage(acc.avatarUrl!) : null,
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
            leading: PixelIcon('cloud', color: cs.error),
            title: Text(t.cloudOff),
            subtitle: Text(t.cloudReauth),
            trailing: FilledButton(
              onPressed: () => _loginDialog(context, app),
              child: Text(t.signInAgain),
            ),
          );
        }
        return ListTile(
          leading: PixelIcon('cloud', color: cs.primary),
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
                  icon: PixelIcon('sync'),
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
          icon: PixelIcon('link'),
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

  Widget _colorDot(Settings s, int c) {
    final selected = s.seedColor == c;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: () => s.seedColor = c,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Color(c),
            shape: BoxShape.circle,
            border: selected
                ? Border.all(color: Colors.white, width: 3)
                : null,
            boxShadow: selected
                ? [BoxShadow(color: Color(c).withValues(alpha: 0.6), blurRadius: 10)]
                : null,
          ),
          child: selected
              ? PixelIcon('check', color: Colors.white, size: 20)
              : null,
        ),
      ),
    );
  }

  // Кнопка «любой цвет» — открывает цветовой круг.
  Widget _customColorDot(BuildContext context, Settings s) {
    final custom = !_seeds.contains(s.seedColor);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: () => _pickColor(context, s),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: const SweepGradient(colors: [
              Color(0xFFFF0000), Color(0xFFFFFF00), Color(0xFF00FF00),
              Color(0xFF00FFFF), Color(0xFF0000FF), Color(0xFFFF00FF),
              Color(0xFFFF0000),
            ]),
            shape: BoxShape.circle,
            border: custom
                ? Border.all(color: Colors.white, width: 3)
                : Border.all(color: Colors.white24, width: 1),
          ),
          child: PixelIcon(custom ? 'check' : 'palette',
              color: Colors.white, size: 20),
        ),
      ),
    );
  }

  void _pickColor(BuildContext context, Settings s) {
    Color picked = Color(s.seedColor);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.anyColor),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: picked,
            onColorChanged: (c) => picked = c,
            enableAlpha: false,
            labelTypes: const [],
            pickerAreaHeightPercent: 0.7,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t.cancel)),
          FilledButton(
            onPressed: () {
              s.seedColor = (picked.toARGB32() | 0xFF000000);
              Navigator.pop(context);
            },
            child: Text(t.selectAction),
          ),
        ],
      ),
    );
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
                              child: Center(child: PixelIcon('backspace')),
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
                  leading: PixelIcon(q.kind == 'text' ? 'note' : 'file'),
                  title: Text(q.kind == 'text'
                      ? (q.text ?? '')
                      : q.filePath!.split('/').last),
                  subtitle: Text(q.peerName),
                  trailing: IconButton(
                    icon: PixelIcon('close'),
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
            return const Center(child: PixelIcon('devices', size: 48));
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
      leading: PixelAvatar(
        child: PixelIcon('phone', color: cs.onPrimaryContainer),
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
