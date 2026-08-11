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
import '../core/settings.dart';
import '../core/version.dart';
import '../l10n/app_strings.dart';
import '../net/remote_input.dart';
import 'admin_page.dart';
import 'onboarding_screen.dart';

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
    return Scaffold(
      appBar: AppBar(title: Text(t.settings)),
      body: ListenableBuilder(
        listenable: s,
        builder: (context, _) => ListView(
          children: [
            _header(tr(context).hLanguage),
            _languageTile(context, s),
            const Divider(height: 1),
            _header(tr(context).hAccount),
            _accountTile(context, app),
            _cloudStatus(context, app),
            const Divider(height: 1),
            _header(t.hDevice),
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: Text(t.deviceName),
              subtitle: Text(s.deviceName),
              onTap: () => _editName(context, s),
            ),
            const Divider(height: 1),
            _header(t.hDesign),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Wrap(
                spacing: 8,
                children: [
                  for (var i = 0; i < DesignPreset.all.length; i++)
                    ChoiceChip(
                      label: Text(DesignPreset.all[i].name),
                      selected: s.designPreset == i,
                      onSelected: (_) => s.designPreset = i,
                    ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.font_download_outlined),
              title: Text(t.font),
              trailing: SegmentedButton<int>(
                segments: [
                  ButtonSegment(value: 0, label: Text(t.fontNormal)),
                  ButtonSegment(value: 1, label: Text('Serif')),
                  ButtonSegment(value: 2, label: Text('Mono')),
                ],
                selected: {s.fontChoice},
                showSelectedIcon: false,
                onSelectionChanged: (v) => s.fontChoice = v.first,
              ),
            ),
            const Divider(height: 1),
            _header(t.hAppearance),
            ListTile(
              leading: const Icon(Icons.brightness_6_outlined),
              title: Text(t.theme),
              trailing: SegmentedButton<ThemeMode>(
                segments: [
                  ButtonSegment(
                      value: ThemeMode.light, icon: Icon(Icons.light_mode)),
                  ButtonSegment(
                      value: ThemeMode.system, icon: Icon(Icons.brightness_auto)),
                  ButtonSegment(
                      value: ThemeMode.dark, icon: Icon(Icons.dark_mode)),
                ],
                selected: {s.themeMode},
                onSelectionChanged: (v) => s.themeMode = v.first,
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.contrast_rounded),
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
              leading: const Icon(Icons.format_size_rounded),
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
            ListTile(
              leading: const Icon(Icons.rounded_corner_rounded),
              title: Text(t.bubbleStyle),
              trailing: SegmentedButton<int>(
                segments: [
                  ButtonSegment(value: 0, label: Text(t.bubbleSoft)),
                  ButtonSegment(value: 1, label: Text(t.bubbleRound)),
                  ButtonSegment(value: 2, label: Text(t.bubbleSharp)),
                ],
                selected: {s.bubbleStyle},
                showSelectedIcon: false,
                onSelectionChanged: (v) => s.bubbleStyle = v.first,
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.gradient_rounded),
              title: Text(t.gradientBg),
              value: s.chatBackground == 1,
              onChanged: (v) => s.chatBackground = v ? 1 : 0,
            ),
            ListTile(
              leading: const Icon(Icons.wallpaper_rounded),
              title: Text(t.chatPhoto),
              subtitle: s.chatBgImage != null ? Text(t.pickPhoto) : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (s.chatBgImage != null)
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => s.chatBgImage = null,
                    ),
                  IconButton(
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    onPressed: () => _pickBgImage(s),
                  ),
                ],
              ),
            ),
            if (s.chatBgImage != null) ...[
              ListTile(
                leading: const Icon(Icons.blur_on_rounded),
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
                leading: const Icon(Icons.brightness_2_outlined),
                title: Text(t.dimLabel),
                subtitle: Slider(
                  value: s.bgDim,
                  max: 0.8,
                  divisions: 8,
                  onChanged: (v) => s.bgDim = v,
                ),
              ),
            ],
            ListTile(
              leading: const Icon(Icons.ac_unit_rounded),
              title: Text(t.weatherLabel),
              trailing: SegmentedButton<int>(
                segments: [
                  ButtonSegment(value: 0, label: Text(t.effectNone)),
                  ButtonSegment(value: 1, label: Text(t.snow)),
                  ButtonSegment(value: 2, label: Text(t.rain)),
                ],
                selected: {s.weather},
                showSelectedIcon: false,
                onSelectionChanged: (v) => s.weather = v.first,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline_rounded),
              title: Text(t.msgColors),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _msgColorDot(context, s, true),
                  const SizedBox(width: 8),
                  _msgColorDot(context, s, false),
                  IconButton(
                    tooltip: t.reset,
                    icon: const Icon(Icons.format_color_reset_rounded),
                    onPressed: () {
                      s.msgOutColor = -1;
                      s.msgInColor = -1;
                    },
                  ),
                ],
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.density_small_rounded),
              title: Text(t.compact),
              subtitle: Text(t.compactSub),
              value: s.compact,
              onChanged: (v) => s.compact = v,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.animation_rounded),
              title: Text(t.animations),
              subtitle: Text(t.animationsSub),
              value: s.animations,
              onChanged: (v) => s.animations = v,
            ),
            if (s.animations) ...[
              ListTile(
                leading: const Icon(Icons.auto_awesome_motion_rounded),
                title: Text(t.animStyle),
                trailing: DropdownButton<int>(
                  value: s.animStyle,
                  underline: const SizedBox(),
                  items: [
                    DropdownMenuItem(value: 0, child: Text('Fade')),
                    DropdownMenuItem(value: 1, child: Text(t.animRise)),
                    DropdownMenuItem(value: 2, child: Text(t.animScale)),
                    DropdownMenuItem(value: 3, child: Text(t.animRiseFade)),
                  ],
                  onChanged: (v) => s.animStyle = v ?? 3,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.speed_rounded),
                title: Text(t.animSpeed),
                trailing: SegmentedButton<int>(
                  segments: [
                    ButtonSegment(value: 0, label: Text(t.speedSlow)),
                    ButtonSegment(value: 1, label: Text(t.speedNormal)),
                    ButtonSegment(value: 2, label: Text(t.speedFast)),
                  ],
                  selected: {s.animSpeed},
                  showSelectedIcon: false,
                  onSelectionChanged: (v) => s.animSpeed = v.first,
                ),
              ),
            ],
            const Divider(height: 1),
            _header(t.hNetwork),
            SwitchListTile(
              secondary: const Icon(Icons.wifi_find_rounded),
              title: Text(t.autoDiscovery),
              subtitle: Text(t.autoDiscoverySub),
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
            SwitchListTile(
              secondary: const Icon(Icons.download_done_rounded),
              title: Text(t.autoAccept),
              value: s.autoAcceptFiles,
              onChanged: (v) => s.autoAcceptFiles = v,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.notifications_active_outlined),
              title: Text(t.notifyReceive),
              value: s.notifyOnReceive,
              onChanged: (v) => s.notifyOnReceive = v,
            ),
            if (Platform.isAndroid)
              SwitchListTile(
                secondary: const Icon(Icons.cloud_sync_rounded),
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
            const Divider(height: 1),
            _header(t.hRemoteInput),
            SwitchListTile(
              secondary: const Icon(Icons.keyboard_rounded),
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
                child: Text(
                  t.wtypeHint,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error, fontSize: 12),
                ),
              ),
            const Divider(height: 1),
            _header(t.hPlayer),
            SwitchListTile(
              secondary: const Icon(Icons.play_circle_outline_rounded),
              title: Text(t.autoplay),
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
            const Divider(height: 1),
            _header(t.hAbout),
            ListTile(
              leading: const Icon(Icons.slideshow_rounded),
              title: Text(t.showOnboarding),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OnboardingScreen()),
              ),
            ),
            const Divider(height: 1),
            _header(t.hData),
            ListTile(
              leading: Icon(Icons.delete_sweep_outlined,
                  color: Theme.of(context).colorScheme.error),
              title: Text(t.clearAll),
              onTap: () => _confirmClear(context, app),
            ),
            const SizedBox(height: 24),
            Center(
              child: TextButton(
                onPressed: () => _onVersionTap(context, s),
                child: Text('TexFi files $kAppVersion',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _languageTile(BuildContext context, Settings s) {
    const names = {
      'system': null, // берётся из перевода
      'en': 'English',
      'ru': 'Русский',
      'de': 'Deutsch',
      'pl': 'Polski',
    };
    return ListTile(
      leading: const Icon(Icons.language_rounded),
      title: Text(tr(context).hLanguage),
      trailing: DropdownButton<String>(
        value: s.localeCode,
        underline: const SizedBox(),
        items: [
          for (final e in names.entries)
            DropdownMenuItem(
              value: e.key,
              child: Text(e.value ?? tr(context).systemLang),
            ),
        ],
        onChanged: (v) => s.localeCode = v ?? 'system',
      ),
    );
  }

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

  Widget _header(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Text(t,
            style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 13)),
      );

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
              ? const Icon(Icons.check, color: Colors.white, size: 20)
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
          child: Icon(custom ? Icons.check : Icons.colorize_rounded,
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

  Widget _msgColorDot(BuildContext context, Settings s, bool outgoing) {
    final cs = Theme.of(context).colorScheme;
    final v = outgoing ? s.msgOutColor : s.msgInColor;
    final color = v != -1
        ? Color(v)
        : (outgoing ? cs.primaryContainer : cs.surfaceContainerHighest);
    return GestureDetector(
      onTap: () => _pickMsgColor(context, s, outgoing, color),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: cs.outlineVariant),
        ),
      ),
    );
  }

  void _pickMsgColor(
      BuildContext context, Settings s, bool outgoing, Color initial) {
    Color picked = initial;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(outgoing ? tr(context).outgoing : tr(context).incoming),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: picked,
            onColorChanged: (c) => picked = c,
            enableAlpha: false,
            labelTypes: const [],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr(context).cancel)),
          FilledButton(
            onPressed: () {
              final argb = picked.toARGB32() | 0xFF000000;
              if (outgoing) {
                s.msgOutColor = argb;
              } else {
                s.msgInColor = argb;
              }
              Navigator.pop(context);
            },
            child: Text(tr(context).selectAction),
          ),
        ],
      ),
    );
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
