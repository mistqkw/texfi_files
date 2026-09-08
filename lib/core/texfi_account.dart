import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Состояние входа в аккаунт TexFi.
enum TexfiAuthStatus { idle, working, signedIn, error }

/// Аккаунт TexFi — тот же, что на сайте и в веб-версиях.
///
/// Это второй, независимый способ входа рядом с уже существующим входом
/// через GitHub ([AuthService]). Он не заменяет его и ничего у него не
/// отбирает: GitHub остаётся тем, чем был, — способом узнавать свои
/// устройства в общей сети. Аккаунт TexFi нужен для другого — чтобы лента
/// «Избранного» была одна и та же на телефоне, на компьютере и в браузере.
///
/// Почему вход по почте, а не через GitHub. Supabase умеет и то и другое,
/// но OAuth в приложении требует возврата по deep link, а он настраивается
/// отдельно под каждую платформу (манифест на Android, схема URL на
/// desktop) и там же ломается. Почта с паролем работает одинаково везде
/// без единой платформенной настройки. Если аккаунт на сайте заведён через
/// GitHub — пароль к нему можно задать через «забыли пароль», это тот же
/// самый аккаунт, а не второй.
class TexfiAccount extends ChangeNotifier {
  TexfiAccount(this._client) {
    _user = _client.auth.currentUser;
    // Сессия переживает перезапуск сама (supabase_flutter хранит её в
    // защищённом хранилище платформы), поэтому здесь только подписка на
    // дальнейшие изменения — выход, обновление токена, вход на другом
    // экране.
    _sub = _client.auth.onAuthStateChange.listen((event) {
      _user = event.session?.user;
      status = _user != null ? TexfiAuthStatus.signedIn : TexfiAuthStatus.idle;
      notifyListeners();
    });
    if (_user != null) status = TexfiAuthStatus.signedIn;
  }

  final SupabaseClient _client;
  StreamSubscription<AuthState>? _sub;

  User? _user;
  TexfiAuthStatus status = TexfiAuthStatus.idle;
  String? error;

  User? get user => _user;
  bool get isSignedIn => _user != null;
  String? get userId => _user?.id;
  String? get email => _user?.email;

  SupabaseClient get client => _client;

  Future<bool> signIn(String email, String password) =>
      _run(() => _client.auth.signInWithPassword(
            email: email.trim(),
            password: password,
          ));

  /// Регистрация. Если в проекте включено подтверждение почты, сессии
  /// сразу не будет — человек попадёт внутрь только после письма. Это не
  /// ошибка, и мы про это честно сообщаем вызывающей стороне через
  /// [needsEmailConfirmation], а не делаем вид, что вход состоялся.
  Future<bool> signUp(String email, String password) => _run(() async {
        final res = await _client.auth.signUp(
          email: email.trim(),
          password: password,
        );
        needsEmailConfirmation = res.session == null && res.user != null;
        return res;
      });

  bool needsEmailConfirmation = false;

  Future<void> sendPasswordReset(String email) async {
    await _client.auth.resetPasswordForEmail(email.trim());
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
    _user = null;
    status = TexfiAuthStatus.idle;
    notifyListeners();
  }

  /// Общая обвязка: любой вызов авторизации либо получается, либо оставляет
  /// человеку читаемую причину. Голый `AuthException.message` приходит
  /// по-английски от сервера — показываем его как есть, но не роняем
  /// приложение и не проглатываем молча.
  Future<bool> _run(Future<dynamic> Function() action) async {
    status = TexfiAuthStatus.working;
    error = null;
    needsEmailConfirmation = false;
    notifyListeners();
    try {
      await action();
      _user = _client.auth.currentUser;
      status = _user != null ? TexfiAuthStatus.signedIn : TexfiAuthStatus.idle;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      error = e.message;
      status = TexfiAuthStatus.error;
      notifyListeners();
      return false;
    } catch (e) {
      error = '$e';
      status = TexfiAuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
