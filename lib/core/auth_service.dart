import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_config.dart';

/// Аккаунт GitHub (личность пользователя).
class GithubAccount {
  final int id;
  final String login;
  final String? name;
  final String? avatarUrl;

  GithubAccount({
    required this.id,
    required this.login,
    this.name,
    this.avatarUrl,
  });

  Map<String, dynamic> toJson() =>
      {'id': id, 'login': login, 'name': name, 'avatarUrl': avatarUrl};

  factory GithubAccount.fromJson(Map<String, dynamic> j) => GithubAccount(
        id: (j['id'] as num).toInt(),
        login: j['login'] as String,
        name: j['name'] as String?,
        avatarUrl: j['avatarUrl'] as String?,
      );
}

enum AuthStatus { idle, awaitingUser, polling, success, error }

/// Вход через GitHub OAuth Device Flow. Токен нужен только на этом устройстве;
/// другим устройствам передаётся лишь github id (как «подпись» аккаунта).
class AuthService extends ChangeNotifier {
  final SharedPreferences _p;
  AuthService(this._p) {
    final raw = _p.getString('account');
    if (raw != null) {
      try {
        _account = GithubAccount.fromJson(jsonDecode(raw));
      } catch (_) {}
    }
    _token = _p.getString('gh_token');
  }

  static Future<AuthService> load() async =>
      AuthService(await SharedPreferences.getInstance());

  GithubAccount? _account;
  String? _token;
  AuthStatus status = AuthStatus.idle;
  String? userCode;
  String? verificationUri;
  String? error;

  GithubAccount? get account => _account;
  String? get token => _token;
  bool get isLoggedIn => _account != null;

  /// Идентификатор аккаунта для авто-доверия между устройствами.
  String? get accountId => _account != null ? 'gh:${_account!.id}' : null;

  Timer? _poll;

  /// Начать вход: запрашиваем device code, показываем пользователю.
  Future<void> begin() async {
    _reset();
    status = AuthStatus.awaitingUser;
    notifyListeners();
    try {
      final resp = await http.post(
        Uri.parse(AuthConfig.deviceCodeUrl),
        headers: {'Accept': 'application/json'},
        body: {
          'client_id': AuthConfig.githubClientId,
          'scope': AuthConfig.scope,
        },
      );
      final j = jsonDecode(resp.body) as Map<String, dynamic>;
      final deviceCode = j['device_code'] as String?;
      userCode = j['user_code'] as String?;
      verificationUri =
          (j['verification_uri'] as String?) ?? AuthConfig.verificationUrl;
      final interval = (j['interval'] as num?)?.toInt() ?? 5;
      if (deviceCode == null || userCode == null) {
        throw Exception('Некорректный ответ GitHub');
      }
      notifyListeners();
      _startPolling(deviceCode, interval);
    } catch (e) {
      status = AuthStatus.error;
      error = '$e';
      notifyListeners();
    }
  }

  void _startPolling(String deviceCode, int interval) {
    status = AuthStatus.polling;
    notifyListeners();
    var seconds = interval;
    void schedule() {
      _poll = Timer(Duration(seconds: seconds), () async {
        try {
          final resp = await http.post(
            Uri.parse(AuthConfig.tokenUrl),
            headers: {'Accept': 'application/json'},
            body: {
              'client_id': AuthConfig.githubClientId,
              'device_code': deviceCode,
              'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
            },
          );
          final j = jsonDecode(resp.body) as Map<String, dynamic>;
          final token = j['access_token'] as String?;
          if (token != null) {
            await _onToken(token);
            return;
          }
          final err = j['error'] as String?;
          if (err == 'authorization_pending') {
            schedule();
          } else if (err == 'slow_down') {
            seconds += 5;
            schedule();
          } else {
            status = AuthStatus.error;
            error = err ?? 'Отменено';
            notifyListeners();
          }
        } catch (e) {
          // Кратковременный сетевой сбой (DNS/соединение) — не отменяем вход,
          // а повторяем попытку.
          if (_isNetworkError(e)) {
            seconds = 5;
            schedule();
          } else {
            status = AuthStatus.error;
            error = '$e';
            notifyListeners();
          }
        }
      });
    }

    schedule();
  }

  bool _isNetworkError(Object e) {
    if (e is SocketException) return true;
    final s = e.toString();
    return s.contains('Failed host lookup') ||
        s.contains('SocketException') ||
        s.contains('Connection closed') ||
        s.contains('Connection reset') ||
        s.contains('timed out');
  }

  Future<void> _onToken(String token) async {
    _token = token;
    // Профиль тянем с повторами — на случай сетевого моргания.
    http.Response? resp;
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        resp = await http.get(
          Uri.parse('https://api.github.com/user'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/vnd.github+json',
            'User-Agent': 'TexFi-files',
          },
        );
        break;
      } catch (e) {
        if (!_isNetworkError(e) || attempt == 4) rethrow;
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    final j = jsonDecode(resp!.body) as Map<String, dynamic>;
    _account = GithubAccount(
      id: (j['id'] as num).toInt(),
      login: j['login'] as String,
      name: j['name'] as String?,
      avatarUrl: j['avatar_url'] as String?,
    );
    await _p.setString('account', jsonEncode(_account!.toJson()));
    await _p.setString('gh_token', token);
    status = AuthStatus.success;
    notifyListeners();
  }

  Future<void> logout() async {
    _poll?.cancel();
    _account = null;
    _token = null;
    await _p.remove('account');
    await _p.remove('gh_token');
    _reset();
    notifyListeners();
  }

  void cancel() {
    _poll?.cancel();
    _reset();
    notifyListeners();
  }

  void _reset() {
    _poll?.cancel();
    status = AuthStatus.idle;
    userCode = null;
    verificationUri = null;
    error = null;
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }
}
