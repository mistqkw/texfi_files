import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'models.dart';
import '../store/store.dart';
import 'settings.dart';

/// Приём «Поделиться в TexFi files» из других приложений (галерея, браузер,
/// Telegram и т.д.) — Android/iOS через системное меню Share.
class QuickShare {
  final Store store;
  final Settings settings;
  StreamSubscription? _sub;

  QuickShare(this.store, this.settings);

  static bool get supported => Platform.isAndroid || Platform.isIOS;

  Future<void> start() async {
    if (!supported) return;
    try {
      final initial = await ReceiveSharingIntent.instance.getInitialMedia();
      if (initial.isNotEmpty) await _handle(initial);
      ReceiveSharingIntent.instance.reset();
      _sub = ReceiveSharingIntent.instance.getMediaStream().listen(_handle,
          onError: (e) => debugPrint('QuickShare stream err: $e'));
    } catch (e) {
      debugPrint('QuickShare start err: $e');
    }
  }

  Future<void> _handle(List<SharedMediaFile> files) async {
    for (final f in files) {
      try {
        if (f.type == SharedMediaType.text || f.type == SharedMediaType.url) {
          await store.add(SavedItem(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            kind: ItemKind.text,
            text: f.path,
            createdAt: DateTime.now(),
            outgoing: true,
          ));
        } else {
          final src = File(f.path);
          if (!src.existsSync()) continue;
          final name = f.path.split('/').last;
          final target = store.newFileFor(name);
          await src.copy(target.path);
          final size = await target.length();
          await store.add(SavedItem(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            kind: kindFromMime(f.mimeType, name),
            filePath: target.path,
            fileName: name,
            fileSize: size,
            mime: f.mimeType,
            createdAt: DateTime.now(),
            outgoing: true,
          ));
        }
      } catch (e) {
        debugPrint('QuickShare handle err: $e');
      }
    }
  }

  void dispose() {
    _sub?.cancel();
  }
}
