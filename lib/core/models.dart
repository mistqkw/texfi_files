import 'dart:convert';

/// Тип элемента ленты «Избранное».
enum ItemKind { text, file, image, audio, video, voice }

ItemKind kindFromMime(String? mime, String name) {
  // Голосовые сообщения — по префиксу имени, чтобы не путать с музыкой.
  final lower = name.toLowerCase();
  if (lower.startsWith('voice_') &&
      (lower.endsWith('.m4a') || lower.endsWith('.aac') ||
          lower.endsWith('.opus') || lower.endsWith('.ogg'))) {
    return ItemKind.voice;
  }
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
  String? filePath; // мутируется при отложенной загрузке (избирательная синхронизация)
  final String? fileName;
  int fileSize; // мутируется во время приёма (растёт до финального размера)
  final String? mime;
  final DateTime createdAt;
  final bool outgoing; // true = отправлено с этого устройства
  final String? fromName; // имя пира-источника
  bool pinned; // закреплено
  bool archived; // архивировано (скрыто из общей ленты)
  String? group; // название группы/коллекции (папки)

  /// Метки элемента. Ярлыки поверх папки: элемент лежит в одной папке, но
  /// может нести сколько угодно меток — «важное», «работа», «отправить
  /// позже». Множество, а не список: одна и та же метка не должна
  /// повторяться, и порядок для них ничего не значит.
  Set<String> labels;
  bool cloud; // синхронизировано в облако аккаунта (GitHub-репо)
  String? remotePath; // путь файла в репозитории (если в облаке)
  String? fileHash; // sha256 содержимого — для дедупликации в облаке
  bool encrypted; // содержимое в облаке зашифровано (AES-GCM)
  DateTime? expiresAt; // самоуничтожение: элемент удаляется после этого момента
  bool receiving; // сейчас идёт приём по сети — не персистится, только в памяти
  int expectedSize; // ожидаемый итоговый размер во время приёма (0 = неизвестен)

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
    this.archived = false,
    this.group,
    Set<String>? labels,
    this.cloud = false,
    this.remotePath,
    this.fileHash,
    this.encrypted = false,
    this.expiresAt,
    this.receiving = false,
    this.expectedSize = 0,
  }) : labels = labels ?? <String>{};

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
        'archived': archived,
        'group': group,
        'labels': labels.toList(),
        'cloud': cloud,
        'remotePath': remotePath,
        'fileHash': fileHash,
        'encrypted': encrypted,
        'expiresAt': expiresAt?.toIso8601String(),
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
        archived: j['archived'] as bool? ?? false,
        group: j['group'] as String?,
        // Поле появилось позже: у записей, сохранённых прежними версиями,
        // его просто нет — читаем как пустой набор, а не падаем.
        labels: (j['labels'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toSet() ??
            <String>{},
        cloud: j['cloud'] as bool? ?? false,
        remotePath: j['remotePath'] as String?,
        fileHash: j['fileHash'] as String?,
        encrypted: j['encrypted'] as bool? ?? false,
        expiresAt: j['expiresAt'] != null
            ? DateTime.tryParse(j['expiresAt'] as String)
            : null,
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
  final String? accountId; // gh:<id>, если пир вошёл в аккаунт
  DateTime lastSeen;

  Peer({
    required this.id,
    required this.name,
    required this.platform,
    required this.address,
    required this.httpPort,
    this.accountId,
    required this.lastSeen,
  });

  String get baseUrl => 'http://$address:$httpPort';

  bool get online => DateTime.now().difference(lastSeen).inSeconds < 90;
}
