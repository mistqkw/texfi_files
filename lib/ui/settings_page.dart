import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app.dart';
import '../app_state.dart';
import '../core/auth_service.dart';
import '../core/settings.dart';
import '../net/remote_input.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _seeds = <int>[
    0xFF3B6CF0, 0xFF6C5CE7, 0xFF0984E3, 0xFF00B894,
    0xFF00CEC9, 0xFFE17055, 0xFFE84393, 0xFFFF7675,
    0xFFFDCB6E, 0xFFEE5253, 0xFFA55EEA, 0xFF576574,
  ];

  bool? _ydotool; // доступен ли хоть какой-то движок ввода
  String _engine = '';

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
      appBar: AppBar(title: const Text('Настройки')),
      body: ListenableBuilder(
        listenable: s,
        builder: (context, _) => ListView(
          children: [
            _header('Аккаунт'),
            _accountTile(context, app),
            const Divider(height: 1),
            _header('Устройство'),
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Имя устройства'),
              subtitle: Text(s.deviceName),
              onTap: () => _editName(context, s),
            ),
            const Divider(height: 1),
            _header('Дизайн'),
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
              title: const Text('Шрифт'),
              trailing: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Обычный')),
                  ButtonSegment(value: 1, label: Text('Serif')),
                  ButtonSegment(value: 2, label: Text('Mono')),
                ],
                selected: {s.fontChoice},
                showSelectedIcon: false,
                onSelectionChanged: (v) => s.fontChoice = v.first,
              ),
            ),
            const Divider(height: 1),
            _header('Внешний вид'),
            ListTile(
              leading: const Icon(Icons.brightness_6_outlined),
              title: const Text('Тема'),
              trailing: SegmentedButton<ThemeMode>(
                segments: const [
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
              title: const Text('Чёрный фон (OLED)'),
              subtitle: const Text('Чистый чёрный в тёмной теме'),
              value: s.pureBlack,
              onChanged: (v) => s.pureBlack = v,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('Акцентный цвет',
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
              title: const Text('Масштаб интерфейса'),
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
              title: const Text('Стиль пузырей'),
              trailing: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Мягкий')),
                  ButtonSegment(value: 1, label: Text('Круглый')),
                  ButtonSegment(value: 2, label: Text('Острый')),
                ],
                selected: {s.bubbleStyle},
                showSelectedIcon: false,
                onSelectionChanged: (v) => s.bubbleStyle = v.first,
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.gradient_rounded),
              title: const Text('Градиентный фон ленты'),
              value: s.chatBackground == 1,
              onChanged: (v) => s.chatBackground = v ? 1 : 0,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.density_small_rounded),
              title: const Text('Компактный режим'),
              subtitle: const Text('Плотнее, меньше отступов'),
              value: s.compact,
              onChanged: (v) => s.compact = v,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.animation_rounded),
              title: const Text('Анимации'),
              subtitle: const Text('Плавное появление и переходы'),
              value: s.animations,
              onChanged: (v) => s.animations = v,
            ),
            if (s.animations) ...[
              ListTile(
                leading: const Icon(Icons.auto_awesome_motion_rounded),
                title: const Text('Стиль анимации'),
                trailing: DropdownButton<int>(
                  value: s.animStyle,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Fade')),
                    DropdownMenuItem(value: 1, child: Text('Подъём')),
                    DropdownMenuItem(value: 2, child: Text('Масштаб')),
                    DropdownMenuItem(value: 3, child: Text('Подъём+Fade')),
                  ],
                  onChanged: (v) => s.animStyle = v ?? 3,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.speed_rounded),
                title: const Text('Скорость анимаций'),
                trailing: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('Медл.')),
                    ButtonSegment(value: 1, label: Text('Обычно')),
                    ButtonSegment(value: 2, label: Text('Быстро')),
                  ],
                  selected: {s.animSpeed},
                  showSelectedIcon: false,
                  onSelectionChanged: (v) => s.animSpeed = v.first,
                ),
              ),
            ],
            const Divider(height: 1),
            _header('Сеть'),
            SwitchListTile(
              secondary: const Icon(Icons.wifi_find_rounded),
              title: const Text('Авто-поиск устройств'),
              subtitle: const Text('Находить устройства в Wi-Fi автоматически'),
              value: s.autoDiscovery,
              onChanged: (v) {
                s.autoDiscovery = v;
                app.discovery.start();
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_ethernet_rounded),
              title: const Text('Порт поиска'),
              subtitle: Text('${s.discoveryPort}'),
              onTap: () => _editPort(context, s, app),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.download_done_rounded),
              title: const Text('Принимать файлы автоматически'),
              value: s.autoAcceptFiles,
              onChanged: (v) => s.autoAcceptFiles = v,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.notifications_active_outlined),
              title: const Text('Уведомлять о приёме'),
              value: s.notifyOnReceive,
              onChanged: (v) => s.notifyOnReceive = v,
            ),
            const Divider(height: 1),
            _header('Удалённый ввод (клавиатура на ПК)'),
            SwitchListTile(
              secondary: const Icon(Icons.keyboard_rounded),
              title: const Text('Разрешить печать с телефона'),
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
                  'Установите wtype (sudo pacman -S wtype), чтобы печатать с телефона '
                  'на ПК с поддержкой кириллицы.',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error, fontSize: 12),
                ),
              ),
            const Divider(height: 1),
            _header('Плеер'),
            SwitchListTile(
              secondary: const Icon(Icons.play_circle_outline_rounded),
              title: const Text('Автовоспроизведение'),
              value: s.autoplayMedia,
              onChanged: (v) => s.autoplayMedia = v,
            ),
            ListTile(
              leading: const Icon(Icons.volume_up_rounded),
              title: const Text('Громкость плеера'),
              subtitle: Slider(
                value: s.playerVolume,
                max: 100,
                divisions: 20,
                label: '${s.playerVolume.toStringAsFixed(0)}%',
                onChanged: (v) => s.playerVolume = v,
              ),
            ),
            const Divider(height: 1),
            _header('Данные'),
            ListTile(
              leading: Icon(Icons.delete_sweep_outlined,
                  color: Theme.of(context).colorScheme.error),
              title: const Text('Очистить всё «Избранное»'),
              onTap: () => _confirmClear(context, app),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text('TexFi files · 1.0.0',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            const SizedBox(height: 24),
          ],
        ),
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
            title: const Text('Войти через GitHub'),
            subtitle: const Text(
                'Устройства одного аккаунта соединяются автоматически'),
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
            child: const Text('Выйти'),
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
            title: const Text('Вход через GitHub'),
            content: _loginBody(context, auth),
            actions: [
              TextButton(
                onPressed: () {
                  auth.cancel();
                  Navigator.pop(context);
                },
                child: const Text('Закрыть'),
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
      return Text('Ошибка: ${auth.error}',
          style: TextStyle(color: cs.error));
    }
    if (auth.status == AuthStatus.success) {
      return const Text('Готово! Вы вошли.');
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
        const Text('1. Скопируй код:'),
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
        const Text('2. Открой страницу и вставь код:'),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => launchUrl(
            Uri.parse(auth.verificationUri ?? 'https://github.com/login/device'),
            mode: LaunchMode.externalApplication,
          ),
          icon: const Icon(Icons.open_in_new_rounded),
          label: const Text('Открыть github.com/login/device'),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
                width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 10),
            Text('Ждём подтверждения…',
                style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }

  String _ydotoolStatus() {
    if (!RemoteInput.supported) return 'Доступно только на Linux (ПК)';
    if (_ydotool == null) return 'Проверка…';
    return 'Движок: $_engine';
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
        title: const Text('Любой цвет'),
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
              child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              s.seedColor = (picked.toARGB32() | 0xFF000000);
              Navigator.pop(context);
            },
            child: const Text('Выбрать'),
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
        title: const Text('Имя устройства'),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена')),
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
        title: const Text('Порт поиска'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена')),
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
        title: const Text('Очистить всё?'),
        content: const Text(
            'Все сообщения и полученные файлы будут удалены безвозвратно.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              app.store.clearAll();
              Navigator.pop(context);
            },
            child: const Text('Очистить'),
          ),
        ],
      ),
    );
  }
}
