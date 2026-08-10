import 'package:flutter/material.dart';
import '../app.dart';
import '../core/settings.dart';
import '../net/remote_input.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _seeds = <int>[
    0xFF6C5CE7, 0xFF0984E3, 0xFF00B894, 0xFFE17055,
    0xFFE84393, 0xFFFDCB6E, 0xFFEE5253, 0xFF576574,
  ];

  bool? _ydotool;

  @override
  void initState() {
    super.initState();
    RemoteInput.check().then((v) {
      if (mounted) setState(() => _ydotool = v);
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
            _header('Устройство'),
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Имя устройства'),
              subtitle: Text(s.deviceName),
              onTap: () => _editName(context, s),
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
                  'Установите ydotool и запустите демон ydotoold, чтобы принимать ввод с телефона.',
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

  String _ydotoolStatus() {
    if (!RemoteInput.supported) return 'Доступно только на Linux (ПК)';
    if (_ydotool == null) return 'Проверка ydotool…';
    return _ydotool! ? 'ydotool найден' : 'ydotool не установлен';
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
