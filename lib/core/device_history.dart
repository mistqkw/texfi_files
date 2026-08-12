import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceStat {
  final String id;
  String name;
  DateTime lastSeen;
  int bytesSent;
  int bytesReceived;

  DeviceStat({
    required this.id,
    required this.name,
    required this.lastSeen,
    this.bytesSent = 0,
    this.bytesReceived = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lastSeen': lastSeen.toIso8601String(),
        'bytesSent': bytesSent,
        'bytesReceived': bytesReceived,
      };

  factory DeviceStat.fromJson(Map<String, dynamic> j) => DeviceStat(
        id: j['id'] as String,
        name: j['name'] as String,
        lastSeen: DateTime.tryParse(j['lastSeen'] as String? ?? '') ??
            DateTime.now(),
        bytesSent: (j['bytesSent'] as num?)?.toInt() ?? 0,
        bytesReceived: (j['bytesReceived'] as num?)?.toInt() ?? 0,
      );
}

/// «Когда последний раз синкалось, сколько места заняло» — по каждому
/// устройству, с которым когда-либо был обмен.
class DeviceHistory extends ChangeNotifier {
  static const _pref = 'deviceHistory';
  final SharedPreferences _p;
  final Map<String, DeviceStat> _stats = {};

  DeviceHistory(this._p) {
    final raw = _p.getString(_pref);
    if (raw == null) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      for (final e in map.entries) {
        _stats[e.key] = DeviceStat.fromJson(e.value as Map<String, dynamic>);
      }
    } catch (_) {}
  }

  List<DeviceStat> get all =>
      _stats.values.toList()..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));

  Future<void> _save() async {
    await _p.setString(_pref,
        jsonEncode({for (final e in _stats.entries) e.key: e.value.toJson()}));
  }

  Future<void> recordReceived(String id, String name, int bytes) async {
    final s = _stats.putIfAbsent(
        id, () => DeviceStat(id: id, name: name, lastSeen: DateTime.now()));
    s.name = name;
    s.lastSeen = DateTime.now();
    s.bytesReceived += bytes;
    notifyListeners();
    await _save();
  }

  Future<void> recordSent(String id, String name, int bytes) async {
    final s = _stats.putIfAbsent(
        id, () => DeviceStat(id: id, name: name, lastSeen: DateTime.now()));
    s.name = name;
    s.lastSeen = DateTime.now();
    s.bytesSent += bytes;
    notifyListeners();
    await _save();
  }
}
