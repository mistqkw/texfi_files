import 'dart:io';
import 'package:flutter/material.dart';
import '../app.dart';
import '../l10n/app_strings.dart';
import '../app_state.dart';
import '../core/models.dart';

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
    return Scaffold(
      appBar: AppBar(title: Text(t.devicesTitle)),
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
    final cs = Theme.of(context).colorScheme;
    final port = _app.server.port;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: cs.primaryContainer,
        child: Icon(Icons.laptop_rounded, color: cs.onPrimaryContainer),
      ),
      title: Text(_app.settings.deviceName,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(_localIp != null
          ? '${t.thisDevice} · $_localIp:$port'
          : '${t.thisDevice} · $port'),
      trailing: const Icon(Icons.circle, size: 10, color: Colors.green),
    );
  }

  Widget _searching(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
                width: 28, height: 28, child: CircularProgressIndicator()),
            const SizedBox(height: 16),
            Text(t.searchingAccount,
                style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(
              t.searchingAccountSub,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _needLogin(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_circle_outlined,
                size: 64, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(t.needLoginTitle,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              t.needLoginText,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _peerTile(BuildContext context, Peer p) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            p.online ? cs.tertiaryContainer : cs.surfaceContainerHighest,
        child: Icon(
          p.platform == 'android'
              ? Icons.smartphone_rounded
              : Icons.laptop_rounded,
          color: p.online ? cs.onTertiaryContainer : cs.onSurfaceVariant,
        ),
      ),
      title: Row(
        children: [
          Flexible(child: Text(p.name, overflow: TextOverflow.ellipsis)),
          if (_app.isTrusted(p)) ...[
            const SizedBox(width: 6),
            Icon(Icons.verified_rounded, size: 16, color: cs.primary),
          ],
        ],
      ),
      subtitle: Text(_app.isTrusted(p)
          ? '${p.address} · ${t.yourAccount}'
          : '${p.address} · ${p.online ? t.online : t.offline}'),
      trailing: Icon(Icons.circle,
          size: 10, color: p.online ? Colors.green : cs.outline),
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
}
