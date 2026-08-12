import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import '../net/client.dart';
import '../net/discovery.dart';

class QueuedSend {
  final String id;
  final String peerId;
  final String peerName;
  final String kind; // 'text' | 'file'
  final String? text;
  final String? filePath;
  final DateTime createdAt;

  QueuedSend({
    required this.id,
    required this.peerId,
    required this.peerName,
    required this.kind,
    this.text,
    this.filePath,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'peerId': peerId,
        'peerName': peerName,
        'kind': kind,
        'text': text,
        'filePath': filePath,
        'createdAt': createdAt.toIso8601String(),
      };

  factory QueuedSend.fromJson(Map<String, dynamic> j) => QueuedSend(
        id: j['id'] as String,
        peerId: j['peerId'] as String,
        peerName: j['peerName'] as String,
        kind: j['kind'] as String,
        text: j['text'] as String?,
        filePath: j['filePath'] as String?,
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

/// Очередь оффлайн-отправки: если целевое устройство недоступно, кладём
/// сообщение/файл сюда и повторяем автоматически, как только оно снова
/// появится онлайн (через авто-поиск по аккаунту).
class OfflineQueue extends ChangeNotifier {
  static const _pref = 'offlineQueue';
  final SharedPreferences _p;
  final SendClient client;
  final Discovery discovery;
  final void Function(SavedItem item) onDelivered;

  final List<QueuedSend> _items = [];
  List<QueuedSend> get items => List.unmodifiable(_items);
  bool _flushing = false;

  OfflineQueue(this._p, this.client, this.discovery, this.onDelivered) {
    _load();
    discovery.addListener(_tryFlush);
  }

  void _load() {
    final raw = _p.getString(_pref);
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List;
      _items.addAll(list
          .map((e) => QueuedSend.fromJson(e as Map<String, dynamic>)));
    } catch (_) {}
  }

  Future<void> _save() async {
    await _p.setString(
        _pref, jsonEncode(_items.map((e) => e.toJson()).toList()));
  }

  Future<void> enqueue(QueuedSend q) async {
    _items.add(q);
    notifyListeners();
    await _save();
  }

  Future<void> _tryFlush() async {
    if (_flushing || _items.isEmpty) return;
    _flushing = true;
    try {
      final online = {for (final p in discovery.peers) p.id: p};
      final delivered = <QueuedSend>[];
      for (final q in List.of(_items)) {
        final peer = online[q.peerId];
        if (peer == null || !peer.online) continue;
        bool ok;
        if (q.kind == 'text') {
          ok = await client.sendText(peer, q.text ?? '');
        } else {
          final f = File(q.filePath!);
          if (!f.existsSync()) {
            delivered.add(q); // файл пропал — выбрасываем из очереди
            continue;
          }
          ok = false;
          await for (final _ in client.sendFile(peer, f)) {
            ok = true; // хотя бы один тик прогресса — считаем отправленным по завершении
          }
        }
        if (ok) {
          delivered.add(q);
          onDelivered(SavedItem(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            kind: q.kind == 'text'
                ? ItemKind.text
                : kindFromMime(null, q.filePath!.split('/').last),
            text: q.text,
            fileName: q.kind == 'file' ? q.filePath!.split('/').last : null,
            fileSize: q.kind == 'file' ? File(q.filePath!).lengthSync() : 0,
            createdAt: DateTime.now(),
            outgoing: true,
            fromName: q.peerName,
          ));
        }
      }
      if (delivered.isNotEmpty) {
        _items.removeWhere((e) => delivered.any((d) => d.id == e.id));
        notifyListeners();
        await _save();
      }
    } finally {
      _flushing = false;
    }
  }

  Future<void> cancel(QueuedSend q) async {
    _items.removeWhere((e) => e.id == q.id);
    notifyListeners();
    await _save();
  }

  @override
  void dispose() {
    discovery.removeListener(_tryFlush);
    super.dispose();
  }
}
