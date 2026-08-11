import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Точка входа фоновой задачи (отдельный изолят). Держит процесс живым,
/// чтобы основной изолят продолжал принимать файлы и синхронизировать облако.
@pragma('vm:entry-point')
void startForegroundCallback() {
  FlutterForegroundTask.setTaskHandler(_KeepAliveHandler());
}

class _KeepAliveHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}

/// Фоновый режим: на Android — foreground-сервис с постоянным уведомлением,
/// чтобы приём файлов и синхронизация не останавливались, когда приложение
/// свёрнуто. На ПК не требуется (свёрнутое окно и так работает).
class Background {
  static bool get supported => Platform.isAndroid;

  static bool _inited = false;

  static void init() {
    if (!supported || _inited) return;
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'texfi_files_bg',
        channelName: 'TexFi files',
        channelDescription: 'Фоновый приём файлов и синхронизация',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(60000),
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    _inited = true;
  }

  static Future<void> start(String title, String text) async {
    if (!supported) return;
    init();
    try {
      await FlutterForegroundTask.requestNotificationPermission();
      if (await FlutterForegroundTask.isRunningService) return;
      await FlutterForegroundTask.startService(
        notificationTitle: title,
        notificationText: text,
        callback: startForegroundCallback,
      );
    } catch (e) {
      debugPrint('Background.start: $e');
    }
  }

  static Future<void> stop() async {
    if (!supported) return;
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (e) {
      debugPrint('Background.stop: $e');
    }
  }
}
