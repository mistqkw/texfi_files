import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../player_service.dart';

/// Мост между PlayerService (media_kit) и MPRIS — стандартным D-Bus
/// протоколом, через который рабочий стол Linux (GNOME Shell, KDE Plasma,
/// `playerctl`, медиа-клавиши на клавиатуре) видит и управляет плеером
/// приложения. Тот же принцип, что у [TexFiAudioHandler] на Android:
/// PlayerService остаётся единственным источником истины, этот класс
/// только зеркалит его состояние наружу и транслирует команды обратно.
///
/// Один объект на шине реализует сразу оба обязательных интерфейса
/// (`org.mpris.MediaPlayer2` и `...Player`) — так делает подавляющее
/// большинство реальных MPRIS-плееров, и именно этого ждут клиенты.
class MprisService extends DBusObject {
  MprisService(this._player)
    : super(DBusObjectPath('/org/mpris/MediaPlayer2'));

  static const _busName = 'org.mpris.MediaPlayer2.texfi_files';
  static const _rootIface = 'org.mpris.MediaPlayer2';
  static const _playerIface = 'org.mpris.MediaPlayer2.Player';

  final PlayerService _player;
  DBusClient? _client;

  /// Последний набор свойств Player, отправленный наружу — чтобы слать
  /// PropertiesChanged только на реальные изменения. PlayerService шлёт
  /// notifyListeners несколько раз в секунду только из-за тика позиции;
  /// без диффа это была бы D-Bus рассылка на каждый кадр.
  Map<String, DBusValue> _lastPlayerProps = {};

  String? _artWrittenFor;
  Directory? _artDir;

  /// Включает мост: поднимает соединение с session bus, регистрирует имя
  /// и объект. Не бросает исключение наружу — на машине без D-Bus (голый
  /// контейнер, редкий десктоп без сессионной шины) это не должно ронять
  /// приложение, просто MPRIS не заработает.
  static Future<MprisService?> tryStart(PlayerService player) async {
    if (!Platform.isLinux) return null;
    final service = MprisService(player);
    try {
      final client = DBusClient.session();
      service._client = client;
      await client.requestName(
        _busName,
        flags: {DBusRequestNameFlag.replaceExisting},
      );
      await client.registerObject(service);
      player.addListener(service._sync);
      player.onSeek = service._emitSeeked;
      service._sync();
      return service;
    } catch (error, stack) {
      debugPrint('MPRIS: недоступен ($error)\n$stack');
      await service._client?.close();
      return null;
    }
  }

  Future<void> dispose() async {
    _player.removeListener(_sync);
    _player.onSeek = null;
    await _client?.close();
  }

  // ── Отражение состояния плеера в свойства и сигналы D-Bus ──

  void _emitSeeked(Duration position) {
    emitSignal(_playerIface, 'Seeked', [DBusInt64(position.inMicroseconds)]);
  }

  void _sync() {
    final changed = <String, DBusValue>{};
    final props = _playerProperties();
    props.forEach((name, value) {
      if (_lastPlayerProps[name] != value) changed[name] = value;
    });
    _lastPlayerProps = props;
    if (changed.isEmpty) return;
    emitPropertiesChanged(_playerIface, changedProperties: changed);

    final item = _player.current;
    final art = _player.art;
    if (item != null && art != null && _artWrittenFor != item.id) {
      _writeArt(item.id, art);
    }
  }

  Future<void> _artCacheDir() async {
    if (_artDir != null) return;
    _artDir = Directory('${(await getTemporaryDirectory()).path}/mpris_art')
      ..createSync(recursive: true);
  }

  /// Обложка публикуется по artUrl (файл), а не байтами — так же, как в
  /// Android-мосте. Одно имя на трек, старые файлы не копятся: каталог
  /// чистится при каждой смене трека, а не растёт на весь срок жизни
  /// процесса.
  Future<void> _writeArt(String itemId, Uint8List bytes) async {
    try {
      await _artCacheDir();
      final dir = _artDir!;
      if (dir.existsSync()) {
        for (final f in dir.listSync()) {
          try {
            f.deleteSync();
          } catch (_) {}
        }
      }
      final file = File('${dir.path}/$itemId.img');
      await file.writeAsBytes(bytes, flush: true);
      // Пока писали файл, трек мог смениться — не публикуем устаревшую
      // обложку под чужим mpris:trackid.
      if (_player.current?.id != itemId) return;
      _artWrittenFor = itemId;
      final props = _playerProperties();
      _lastPlayerProps = props;
      emitPropertiesChanged(
        _playerIface,
        changedProperties: {'Metadata': props['Metadata']!},
      );
    } catch (_) {
      // Не критично — просто останется без обложки в этом такте.
    }
  }

  /// Object path трека. MPRIS требует тип 'o' — сегменты только из
  /// [A-Za-z0-9_], поэтому id (обычно числовой epoch) на всякий случай
  /// прогоняется через санитайзер, а не подставляется как есть.
  DBusObjectPath _trackPath(String itemId) {
    final safe = itemId.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
    return DBusObjectPath('/app/texfi/files/track/$safe');
  }

  Map<String, DBusValue> _playerProperties() {
    final item = _player.current;
    final status = item == null
        ? 'Stopped'
        : (_player.playing ? 'Playing' : 'Paused');
    final loop = switch (_player.repeatMode) {
      PlayerRepeatMode.off => 'None',
      PlayerRepeatMode.one => 'Track',
      PlayerRepeatMode.all => 'Playlist',
    };

    final metadata = <String, DBusValue>{
      'mpris:trackid': item == null
          ? const DBusObjectPath.unchecked(
              '/org/mpris/MediaPlayer2/TrackList/NoTrack',
            )
          : _trackPath(item.id),
    };
    if (item != null) {
      if (_player.dur > Duration.zero) {
        metadata['mpris:length'] = DBusInt64(_player.dur.inMicroseconds);
      }
      final title = _player.title?.trim();
      metadata['xesam:title'] = DBusString(
        title?.isNotEmpty == true ? title! : (item.fileName ?? 'Audio'),
      );
      final artist = _player.artist?.trim();
      if (artist?.isNotEmpty == true) {
        metadata['xesam:artist'] = DBusArray.string([artist!]);
      }
      if (_artWrittenFor == item.id && _artDir != null) {
        metadata['mpris:artUrl'] = DBusString(
          Uri.file('${_artDir!.path}/${item.id}.img').toString(),
        );
      }
    }

    final hasItem = item != null;
    final hasQueue = _player.queue.isNotEmpty;
    return {
      'PlaybackStatus': DBusString(status),
      'LoopStatus': DBusString(loop),
      'Rate': const DBusDouble(1.0),
      'Shuffle': DBusBoolean(_player.shuffle),
      'Metadata': DBusDict.stringVariant(metadata),
      'Volume': DBusDouble((_player.volume / 100).clamp(0.0, 1.0)),
      'MinimumRate': const DBusDouble(1.0),
      'MaximumRate': const DBusDouble(1.0),
      'CanGoNext': DBusBoolean(hasQueue),
      'CanGoPrevious': DBusBoolean(hasQueue),
      'CanPlay': DBusBoolean(hasItem),
      'CanPause': DBusBoolean(hasItem),
      'CanSeek': DBusBoolean(hasItem),
      'CanControl': const DBusBoolean(true),
    };
  }

  // ── org.freedesktop.DBus.Introspectable ──

  @override
  List<DBusIntrospectInterface> introspect() {
    DBusIntrospectProperty prop(
      String name,
      String sig, {
      bool writable = false,
    }) => DBusIntrospectProperty(
      name,
      DBusSignature(sig),
      access: writable ? DBusPropertyAccess.readwrite : DBusPropertyAccess.read,
    );
    DBusIntrospectMethod method(String name, [List<DBusIntrospectArgument> args = const []]) =>
        DBusIntrospectMethod(name, args: args);
    DBusIntrospectArgument arg(String name, String sig) => DBusIntrospectArgument(
      DBusSignature(sig),
      DBusArgumentDirection.in_,
      name: name,
    );

    final root = DBusIntrospectInterface(
      _rootIface,
      methods: [method('Raise'), method('Quit')],
      properties: [
        prop('CanQuit', 'b'),
        prop('CanRaise', 'b'),
        prop('HasTrackList', 'b'),
        prop('Identity', 's'),
        prop('DesktopEntry', 's'),
        prop('SupportedUriSchemes', 'as'),
        prop('SupportedMimeTypes', 'as'),
      ],
    );

    final player = DBusIntrospectInterface(
      _playerIface,
      methods: [
        method('Next'),
        method('Previous'),
        method('Pause'),
        method('PlayPause'),
        method('Stop'),
        method('Play'),
        method('Seek', [arg('Offset', 'x')]),
        method('SetPosition', [arg('TrackId', 'o'), arg('Position', 'x')]),
        method('OpenUri', [arg('Uri', 's')]),
      ],
      signals: [
        DBusIntrospectSignal(
          'Seeked',
          args: [
            DBusIntrospectArgument(
              DBusSignature('x'),
              DBusArgumentDirection.out,
              name: 'Position',
            ),
          ],
        ),
      ],
      properties: [
        prop('PlaybackStatus', 's'),
        prop('LoopStatus', 's', writable: true),
        prop('Rate', 'd', writable: true),
        prop('Shuffle', 'b', writable: true),
        prop('Metadata', 'a{sv}'),
        prop('Volume', 'd', writable: true),
        prop('Position', 'x'),
        prop('MinimumRate', 'd'),
        prop('MaximumRate', 'd'),
        prop('CanGoNext', 'b'),
        prop('CanGoPrevious', 'b'),
        prop('CanPlay', 'b'),
        prop('CanPause', 'b'),
        prop('CanSeek', 'b'),
        prop('CanControl', 'b'),
      ],
    );

    return [root, player];
  }

  // ── org.freedesktop.DBus.Properties ──

  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async {
    if (interface == _rootIface) {
      switch (name) {
        case 'CanQuit':
        case 'CanRaise':
        case 'HasTrackList':
          return DBusGetPropertyResponse(const DBusBoolean(false));
        case 'Identity':
          return DBusGetPropertyResponse(DBusString('TexFi files'));
        case 'DesktopEntry':
          return DBusGetPropertyResponse(DBusString('texfi-files'));
        case 'SupportedUriSchemes':
        case 'SupportedMimeTypes':
          return DBusGetPropertyResponse(DBusArray.string(const []));
      }
      return DBusMethodErrorResponse.unknownProperty();
    }
    if (interface == _playerIface) {
      if (name == 'Position') {
        return DBusGetPropertyResponse(
          DBusInt64(_player.pos.inMicroseconds),
        );
      }
      final value = _playerProperties()[name];
      if (value == null) return DBusMethodErrorResponse.unknownProperty();
      return DBusGetPropertyResponse(value);
    }
    return DBusMethodErrorResponse.unknownInterface();
  }

  @override
  Future<DBusMethodResponse> getAllProperties(String interface) async {
    if (interface == _rootIface) {
      return DBusGetAllPropertiesResponse({
        'CanQuit': const DBusBoolean(false),
        'CanRaise': const DBusBoolean(false),
        'HasTrackList': const DBusBoolean(false),
        'Identity': DBusString('TexFi files'),
        'DesktopEntry': DBusString('texfi-files'),
        'SupportedUriSchemes': DBusArray.string(const []),
        'SupportedMimeTypes': DBusArray.string(const []),
      });
    }
    if (interface == _playerIface) {
      return DBusGetAllPropertiesResponse({
        ..._playerProperties(),
        'Position': DBusInt64(_player.pos.inMicroseconds),
      });
    }
    return DBusMethodErrorResponse.unknownInterface();
  }

  @override
  Future<DBusMethodResponse> setProperty(
    String interface,
    String name,
    DBusValue value,
  ) async {
    if (interface != _playerIface) {
      return interface == _rootIface
          ? DBusMethodErrorResponse.propertyReadOnly()
          : DBusMethodErrorResponse.unknownInterface();
    }
    switch (name) {
      case 'Volume':
        final v = value.asDouble();
        _player.setVolume((v.clamp(0.0, 1.0)) * 100);
        return DBusMethodSuccessResponse();
      case 'LoopStatus':
        final v = value.asString();
        _player.setRepeatMode(switch (v) {
          'Track' => PlayerRepeatMode.one,
          'Playlist' => PlayerRepeatMode.all,
          _ => PlayerRepeatMode.off,
        });
        return DBusMethodSuccessResponse();
      case 'Shuffle':
        if (value.asBoolean() != _player.shuffle) _player.toggleShuffle();
        return DBusMethodSuccessResponse();
      case 'Rate':
        // Playback rate other than 1.0 isn't something the app's UI
        // exposes anywhere — accept the write silently rather than fail a
        // spec-required property, but don't pretend to honour a value we
        // don't apply.
        return DBusMethodSuccessResponse();
    }
    return DBusMethodErrorResponse.unknownProperty();
  }

  // ── org.freedesktop.DBus.Introspectable / method calls ──

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    if (methodCall.interface == _rootIface) {
      switch (methodCall.name) {
        case 'Raise':
        case 'Quit':
          // CanQuit/CanRaise оба false — по спеке клиенты и не должны сюда
          // звать, но отвечаем успехом на случай, если кто-то всё равно
          // попробует, вместо непонятной ошибки.
          return DBusMethodSuccessResponse();
      }
      return DBusMethodErrorResponse.unknownMethod();
    }
    if (methodCall.interface == _playerIface) {
      switch (methodCall.name) {
        case 'Next':
          await _player.next();
          return DBusMethodSuccessResponse();
        case 'Previous':
          await _player.previous();
          return DBusMethodSuccessResponse();
        case 'Pause':
          _player.pause();
          return DBusMethodSuccessResponse();
        case 'PlayPause':
          _player.toggle();
          return DBusMethodSuccessResponse();
        case 'Stop':
          await _player.stop();
          return DBusMethodSuccessResponse();
        case 'Play':
          _player.play();
          return DBusMethodSuccessResponse();
        case 'Seek':
          final offsetUs = methodCall.values.first.asInt64();
          _player.seek(_player.pos + Duration(microseconds: offsetUs));
          return DBusMethodSuccessResponse();
        case 'SetPosition':
          // TrackId проверяется против текущего трека: клиент мог послать
          // команду для трека, который к этому моменту уже сменился —
          // применять её тогда нельзя, это перемотало бы совсем не то,
          // что показано у клиента на экране.
          final trackId = methodCall.values[0].asObjectPath();
          final positionUs = methodCall.values[1].asInt64();
          final current = _player.current;
          if (current == null || trackId != _trackPath(current.id)) {
            return DBusMethodSuccessResponse();
          }
          _player.seek(Duration(microseconds: positionUs));
          return DBusMethodSuccessResponse();
        case 'OpenUri':
          return DBusMethodErrorResponse.failed(
            'Opening arbitrary URIs is not supported',
          );
      }
      return DBusMethodErrorResponse.unknownMethod();
    }
    return DBusMethodErrorResponse.unknownInterface();
  }
}
