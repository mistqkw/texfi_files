import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SHA-256 хэш содержимого файла (hex) — для дедупликации в облаке.
Future<String> sha256Hex(List<int> bytes) async {
  return crypto.sha256.convert(bytes).toString();
}

/// PIN-код хешируется с локальной солью (не для серверной аутентификации —
/// это просто локальный экран-блокировка приложения).
String hashPin(String pin, String salt) {
  return crypto.sha256.convert(utf8.encode('$salt:$pin')).toString();
}

/// Локальное шифрование файлов перед загрузкой в облако (AES-256-GCM).
/// Ключ генерируется один раз на устройстве и хранится в SharedPreferences.
/// Это защищает содержимое файлов в приватном GitHub-репозитории от того,
/// кто получит доступ к самому репозиторию/токену, но не от компрометации
/// самого устройства (ключ лежит локально, не в защищённом keystore).
class CryptoUtil {
  static const _keyPref = 'encKeyB64';
  static final _algo = AesGcm.with256bits();

  static Future<SecretKey> _key(SharedPreferences p) async {
    final existing = p.getString(_keyPref);
    if (existing != null) {
      return SecretKey(base64.decode(existing));
    }
    final generated = await _algo.newSecretKey();
    final bytes = await generated.extractBytes();
    await p.setString(_keyPref, base64.encode(bytes));
    return generated;
  }

  /// Зашифровать: [nonce(12)][ciphertext][mac(16)] одним блобом.
  static Future<Uint8List> encrypt(List<int> plain) async {
    final p = await SharedPreferences.getInstance();
    final key = await _key(p);
    final nonce = _algo.newNonce();
    final box = await _algo.encrypt(plain, secretKey: key, nonce: nonce);
    return Uint8List.fromList([...nonce, ...box.cipherText, ...box.mac.bytes]);
  }

  static Future<Uint8List> decrypt(List<int> blob) async {
    final p = await SharedPreferences.getInstance();
    final key = await _key(p);
    final nonce = blob.sublist(0, 12);
    final mac = blob.sublist(blob.length - 16);
    final cipherText = blob.sublist(12, blob.length - 16);
    final box = SecretBox(cipherText, nonce: nonce, mac: Mac(mac));
    final plain = await _algo.decrypt(box, secretKey: key);
    return Uint8List.fromList(plain);
  }
}

/// Случайная соль для PIN, генерируется один раз.
Future<String> pinSalt() async {
  final p = await SharedPreferences.getInstance();
  final existing = p.getString('pinSalt');
  if (existing != null) return existing;
  final rnd = Random.secure();
  final salt =
      base64.encode(List.generate(16, (_) => rnd.nextInt(256)));
  await p.setString('pinSalt', salt);
  return salt;
}
