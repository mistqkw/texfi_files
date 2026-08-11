import 'dart:convert';

/// Тип элемента ленты «Избранное».
enum ItemKind { text, file, image, audio, video }

ItemKind kindFromMime(String? mime, String name) {
  final m = (mime ?? '').toLowerCase();
  if (m.startsWith('image/')) return ItemKind.image;
  if (m.startsWith('audio/')) return ItemKind.audio;
  if (m.startsWith('video/')) return ItemKind.video;
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  const img = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'heic'};
  const aud = {'mp3', 'flac', 'wav', 'ogg', 'm4a', 'opus', 'aac'};
  const vid = {'mp4', 'mkv', 'webm', 'mov', 'avi', 'm4v'};
  if (img.contains(ext)) return ItemKind.image;
  if (aud.contains(ext)) return ItemKind.audio;
  if (vid.contains(ext)) return ItemKind.video;
  return ItemKind.file;
}

/// Элемент ленты. Либо текст, либо файл (с локальным путём).
class SavedItem {
  final String id;
  final ItemKind kind;
  final String? text;
  final String? filePath;
  final String? fileName;
  final int fileSize;
  final String? mime;
  final DateTime createdAt;
  final bool outgoing; // true = отправлено с этого устройства
  final String? fromName; // имя пира-источника
  bool pinned; // закреплено
  String? group; // название группы/коллекции

  SavedItem({
    required this.id,
    required this.kind,
    this.text,
    this.filePath,
    this.fileName,
    this.fileSize = 0,
    this.mime,
    required this.createdAt,
    this.outgoing = false,
    this.fromName,
    this.pinned = false,
    this.group,
  });

  bool get isMedia =>
      kind == ItemKind.audio || kind == ItemKind.video || kind == ItemKind.image;

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'text': text,
        'filePath': filePath,
        'fileName': fileName,
        'fileSize': fileSize,
        'mime': mime,
        'createdAt': createdAt.toIso8601String(),
        'outgoing': outgoing,
        'fromName': fromName,
        'pinned': pinned,
        'group': group,
      };

  factory SavedItem.fromJson(Map<String, dynamic> j) => SavedItem(
        id: j['id'] as String,
        kind: ItemKind.values.firstWhere((e) => e.name == j['kind'],
            orElse: () => ItemKind.text),
        text: j['text'] as String?,
        filePath: j['filePath'] as String?,
        fileName: j['fileName'] as String?,
        fileSize: (j['fileSize'] as num?)?.toInt() ?? 0,
        mime: j['mime'] as String?,
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ??
            DateTime.now(),
        outgoing: j['outgoing'] as bool? ?? false,
        fromName: j['fromName'] as String?,
        pinned: j['pinned'] as bool? ?? false,
        group: j['group'] as String?,
      );

  static List<SavedItem> listFromJson(String raw) {
    final data = jsonDecode(raw) as List<dynamic>;
    return data
        .map((e) => SavedItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static String listToJson(List<SavedItem> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());
}

/// Обнаруженное в сети устройство.
class Peer {
  final String id;
  final String name;
  final String platform;
  final String address;
  final int httpPort;
  DateTime lastSeen;

  Peer({
    required this.id,
    required this.name,
    required this.platform,
    required this.address,
    required this.httpPort,
    required this.lastSeen,
  });

  String get baseUrl => 'http://$address:$httpPort';

  bool get online => DateTime.now().difference(lastSeen).inSeconds < 12;
}
