/// Конфигурация входа через GitHub (OAuth Device Flow).
///
/// Client ID публичный — для device flow client_secret не требуется,
/// поэтому его безопасно хранить в приложении.
class AuthConfig {
  static const String githubClientId = 'Ov23li0vXDo4QQvsmegD';

  // Эндпоинты GitHub device flow.
  static const String deviceCodeUrl = 'https://github.com/login/device/code';
  static const String tokenUrl = 'https://github.com/login/oauth/access_token';
  static const String verificationUrl = 'https://github.com/login/device';

  // Права: профиль + gist (реестр устройств) + repo (приватное хранилище файлов аккаунта).
  static const String scope = 'read:user gist repo';

  // Порог: файлы до этого размера уходят в облако аккаунта (GitHub-репо),
  // большие — только напрямую между устройствами в одной сети.
  static const int cloudMaxBytes = 90 * 1024 * 1024; // ~90 МБ
  static const String storageRepo = 'texfi-files-storage';
}
