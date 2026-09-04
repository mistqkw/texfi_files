import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app.dart';
import '../core/version.dart';

/// Скрытые admin/dev настройки (разблокируются тапами по версии).
class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Admin settings')),
      body: ListenableBuilder(
        listenable: Listenable.merge([app.cloud, app.discovery, app.auth, s]),
        builder: (context, _) {
          final acc = app.auth.account;
          return ListView(
            children: [
              _section('Info'),
              _kv(context, 'Version', kAppVersion),
              _kv(context, 'Device ID', s.deviceId),
              _kv(context, 'Server port', '${app.server.port}'),
              _kv(context, 'Account', acc == null ? '—' : '@${acc.login} (${acc.id})'),
              _kv(context, 'Token', app.auth.token == null ? 'none' : 'present'),
              _kv(context, 'Language', s.effectiveLanguageCode),
              const Divider(height: 1),
              _section('Cloud'),
              _kv(context, 'Available', '${app.cloud.available}'),
              _kv(context, 'Syncing', '${app.cloud.syncing}'),
              _kv(context, 'Needs re-auth', '${app.cloud.needsReauth}'),
              _kv(context, 'Last error', app.cloud.lastError ?? '—'),
              ListTile(
                leading: const Icon(Icons.sync_rounded),
                title: const Text('Force cloud sync now'),
                onTap: () {
                  app.cloud.pull();
                  _toast(context, 'Sync triggered');
                },
              ),
              const Divider(height: 1),
              _section('Network'),
              _kv(context, 'Peers', '${app.discovery.peers.length}'),
              for (final p in app.discovery.peers)
                _kv(context, '· ${p.name}', '${p.address}:${p.httpPort}'),
              const Divider(height: 1),
              _section('Actions'),
              ListTile(
                leading: const Icon(Icons.slideshow_rounded),
                title: const Text('Reset onboarding (show again)'),
                onTap: () {
                  s.onboardingSeen = false;
                  _toast(context, 'Onboarding reset');
                },
              ),
              ListTile(
                leading: const Icon(Icons.wallpaper_rounded),
                title: const Text('Clear custom background'),
                onTap: () {
                  s.chatBgImage = null;
                  _toast(context, 'Background cleared');
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Copy device ID'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: s.deviceId));
                  _toast(context, 'Copied');
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.lock_outline_rounded,
                    color: Theme.of(context).colorScheme.error),
                title: const Text('Lock admin settings'),
                onTap: () {
                  s.adminUnlocked = false;
                  Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
        child: Text(t,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 13)),
      );

  Widget _kv(BuildContext context, String k, String v) => ListTile(
        dense: true,
        title: Text(k),
        subtitle: Text(v,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );

  void _toast(BuildContext context, String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m),
        duration: const Duration(milliseconds: 900),
      ));
}
