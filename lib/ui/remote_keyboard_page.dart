import 'dart:async';
import 'package:flutter/material.dart';
import '../app.dart';
import '../app_state.dart';
import '../core/models.dart';
import '../l10n/app_strings.dart';

/// Примитивная операция ввода: либо текст, либо нажатие клавиши N раз.
class _Op {
  String? text;
  String? key;
  int count;
  _Op.text(this.text) : count = 1;
  _Op.key(this.key, this.count);
}

/// Печать с телефона прямо на ПК. Работает в двух режимах:
/// — «вживую»: каждый символ уходит на ПК сразу (ydotool печатает);
/// — обычный: набираешь и жмёшь «Отправить».
class RemoteKeyboardPage extends StatefulWidget {
  const RemoteKeyboardPage({super.key});

  @override
  State<RemoteKeyboardPage> createState() => _RemoteKeyboardPageState();
}

class _RemoteKeyboardPageState extends State<RemoteKeyboardPage> {
  final _controller = TextEditingController();
  Peer? _target;
  bool _live = true;
  String _prev = '';

  late AppState _app;
  AppStrings get t => AppStrings(_app.settings.effectiveLanguageCode);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _app = AppScope.of(context);
    _target ??= _pcPeers().isNotEmpty ? _pcPeers().first : null;
  }

  List<Peer> _pcPeers() =>
      _app.peers.where((p) => p.online && p.platform == 'linux').toList();

  // Очередь операций + дебаунс, чтобы не слать HTTP-запрос на каждый символ.
  final List<_Op> _queue = [];
  Timer? _debounce;
  bool _sending = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String next) {
    if (!_live || _target == null) {
      _prev = next;
      return;
    }
    // Вычисляем изменение относительно предыдущего текста.
    var common = 0;
    final maxLen = _prev.length < next.length ? _prev.length : next.length;
    while (common < maxLen && _prev[common] == next[common]) {
      common++;
    }
    final deletions = _prev.length - common;
    final additions = next.substring(common);
    _prev = next;

    if (deletions > 0) _enqueueKey('backspace', deletions);
    if (additions.isNotEmpty) {
      final parts = additions.split('\n');
      for (var i = 0; i < parts.length; i++) {
        if (parts[i].isNotEmpty) _enqueueText(parts[i]);
        if (i < parts.length - 1) _enqueueKey('enter', 1);
      }
    }

    // Батчим: собираем ввод за короткое окно и шлём пачкой.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 45), _flush);
  }

  void _enqueueText(String s) {
    if (_queue.isNotEmpty && _queue.last.text != null) {
      _queue.last.text = _queue.last.text! + s; // склеиваем соседний текст
    } else {
      _queue.add(_Op.text(s));
    }
  }

  void _enqueueKey(String key, int count) {
    if (_queue.isNotEmpty && _queue.last.key == key) {
      _queue.last.count += count; // склеиваем повторы одной клавиши
    } else {
      _queue.add(_Op.key(key, count));
    }
  }

  Future<void> _flush() async {
    if (_sending || _target == null) return;
    _sending = true;
    try {
      while (_queue.isNotEmpty) {
        final op = _queue.removeAt(0);
        if (op.text != null) {
          await _app.client.sendTyping(_target!, text: op.text);
        } else {
          await _app.client
              .sendTyping(_target!, key: op.key, count: op.count);
        }
      }
    } finally {
      _sending = false;
    }
  }

  Future<void> _sendAll() async {
    if (_target == null) return;
    final ok = await _app.client.sendTyping(_target!, text: _controller.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? t.sentToName(_target!.name) : t.notSent),
      ));
    }
    _controller.clear();
    _prev = '';
  }

  Future<void> _key(String k) async {
    if (_target != null) await _app.client.sendTyping(_target!, key: k);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t.keyboardTitle)),
      body: ListenableBuilder(
        listenable: _app.discovery,
        builder: (context, _) {
          final pcs = _pcPeers();
          if (_target != null && !pcs.any((p) => p.id == _target!.id)) {
            _target = pcs.isNotEmpty ? pcs.first : null;
          }
          if (pcs.isEmpty) return _noPc(context);
          return Column(
            children: [
              _targetRow(context, pcs),
              const Divider(height: 1),
              Expanded(child: _editor(context)),
              _keyRow(context),
            ],
          );
        },
      ),
    );
  }

  Widget _noPc(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.desktop_access_disabled_rounded,
              size: 64, color: cs.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(t.noPcTitle,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              t.noPcText,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _targetRow(BuildContext context, List<Peer> pcs) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.laptop_rounded),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _target?.id,
              underline: const SizedBox(),
              items: [
                for (final p in pcs)
                  DropdownMenuItem(value: p.id, child: Text(p.name)),
              ],
              onChanged: (id) => setState(
                  () => _target = pcs.firstWhere((p) => p.id == id)),
            ),
          ),
          Text(t.live),
          Switch(
            value: _live,
            onChanged: (v) => setState(() {
              _live = v;
              _prev = _controller.text;
            }),
          ),
        ],
      ),
    );
  }

  Widget _editor(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        onChanged: _onChanged,
        decoration: InputDecoration(
          hintText: _live
              ? t.typeLiveHint
              : t.typeSendHint,
        ),
      ),
    );
  }

  Widget _keyRow(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Row(
          children: [
            _miniKey('⌫', () => _key('backspace')),
            _miniKey('⏎', () => _key('enter')),
            _miniKey('Tab', () => _key('tab')),
            _miniKey('Esc', () => _key('esc')),
            const Spacer(),
            if (!_live)
              FilledButton.icon(
                onPressed: _sendAll,
                icon: const Icon(Icons.send_rounded),
                label: Text(t.send),
              ),
          ],
        ),
      ),
    );
  }

  Widget _miniKey(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 40),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        child: Text(label),
      ),
    );
  }
}
