import 'package:flutter/widgets.dart';
import '../app.dart';

/// Простая локализация на 4 языка без кодогенерации.
/// Каждая строка — одна запись со всеми переводами (ru/en/de/pl).
class AppStrings {
  final String lang;
  const AppStrings(this.lang);

  String _(String ru, String en, String de, String pl) => switch (lang) {
        'ru' => ru,
        'de' => de,
        'pl' => pl,
        _ => en,
      };

  // Общее
  String get ok => 'OK';
  String get cancel => _('Отмена', 'Cancel', 'Abbrechen', 'Anuluj');
  String get close => _('Закрыть', 'Close', 'Schließen', 'Zamknij');
  String get save => _('Сохранить', 'Save', 'Speichern', 'Zapisz');
  String get delete => _('Удалить', 'Delete', 'Löschen', 'Usuń');
  String get deleted => _('Удалено', 'Deleted', 'Gelöscht', 'Usunięto');
  String get undo => _('Отменить', 'Undo', 'Rückgängig', 'Cofnij');
  String get open => _('Открыть', 'Open', 'Öffnen', 'Otwórz');
  String get copy => _('Копировать', 'Copy', 'Kopieren', 'Kopiuj');
  String get copied => _('Скопировано', 'Copied', 'Kopiert', 'Skopiowano');
  String get saved => _('Сохранено', 'Saved', 'Gespeichert', 'Zapisano');
  String get cancelled => _('Отменено', 'Cancelled', 'Abgebrochen', 'Anulowano');
  String get selectAction => _('Выбрать', 'Select', 'Auswählen', 'Wybierz');

  // Главный экран
  String get filesWord => 'files';
  String get signInPrompt =>
      _('Войдите в аккаунт', 'Sign in', 'Anmelden', 'Zaloguj się');
  String devicesInAccount(int n) => _(
      '$n ${_plural(n, 'устройство', 'устройства', 'устройств')} на связи',
      n == 1 ? '1 device on the line' : '$n devices on the line',
      n == 1 ? '1 Gerät verbunden' : '$n Geräte verbunden',
      '$n ${_plural(n, 'urządzenie', 'urządzenia', 'urządzeń')} na łączu');
  String get searchingDevices => _('Ищу твои устройства…',
      'Looking for your devices…',
      'Suche deine Geräte…', 'Szukam Twoich urządzeń…');

  /// Славянское склонение по числу: 1 устройство, 2 устройства, 5 устройств.
  ///
  /// Раньше во всех случаях подставлялась форма множественного числа, и
  /// шапка писала «1 устройств» — мелочь, которая сразу выдаёт, что текст
  /// не вычитывали.
  static String _plural(int n, String one, String few, String many) {
    final mod100 = n % 100;
    if (mod100 >= 11 && mod100 <= 14) return many;
    return switch (n % 10) {
      1 => one,
      2 || 3 || 4 => few,
      _ => many,
    };
  }
  String get ttKeyboard => _('Клавиатура на ПК', 'Keyboard on PC',
      'Tastatur am PC', 'Klawiatura na PC');
  String get ttDevices => _('Устройства', 'Devices', 'Geräte', 'Urządzenia');
  String get ttSettings =>
      _('Настройки', 'Settings', 'Einstellungen', 'Ustawienia');
  String get emptyTitle => _('Ваше «Избранное»', 'Your Saved',
      'Deine Favoriten', 'Twoje zapisane');
  String get emptyText => _(
      'Отправляйте сюда текст и файлы любого размера. Выберите устройство или сохраните локально.',
      'Send text and files of any size here. Pick a device or save locally.',
      'Sende hier Text und Dateien jeder Größe. Wähle ein Gerät oder speichere lokal.',
      'Wysyłaj tu tekst i pliki dowolnego rozmiaru. Wybierz urządzenie lub zapisz lokalnie.');
  String get messageHint => _('Сообщение или текст для копирования…',
      'Message or text to copy…',
      'Nachricht oder Text zum Kopieren…', 'Wiadomość lub tekst…');
  String get saveHere =>
      _('Сохранить здесь', 'Save here', 'Hier speichern', 'Zapisz tutaj');
  String couldNotSendTo(String name) => _('Не удалось отправить на $name',
      'Could not send to $name', 'Senden an $name fehlgeschlagen',
      'Nie udało się wysłać do $name');
  String sentName(String name) =>
      _('Отправлено: $name', 'Sent: $name', 'Gesendet: $name', 'Wysłano: $name');
  String queuedOffline(String name) => _(
      'Устройство $name не в сети — отправлю, когда появится',
      '$name is offline — will send when it reconnects',
      '$name ist offline — wird gesendet, sobald verfügbar',
      '$name jest offline — wyślę, gdy będzie dostępne');
  String get offlineQueue => _('Очередь отправки', 'Send queue',
      'Sendewarteschlange', 'Kolejka wysyłania');
  String get offlineQueueEmpty => _('Очередь пуста', 'Queue is empty',
      'Warteschlange leer', 'Kolejka jest pusta');
  String get enterPin => _('Введите PIN', 'Enter PIN', 'PIN eingeben',
      'Wprowadź PIN');
  String get unlockReason => _('Разблокировать TexFi files',
      'Unlock TexFi files', 'TexFi files entsperren', 'Odblokuj TexFi files');
  String get setPin => _('Задать PIN-код', 'Set PIN code', 'PIN festlegen',
      'Ustaw kod PIN');
  String get pinLock => _('PIN-код', 'PIN lock', 'PIN-Sperre', 'Blokada PIN');
  String get pinLockSub => _('Запрашивать код при открытии приложения',
      'Ask for a code when opening the app',
      'Code beim Öffnen der App abfragen',
      'Pytaj o kod przy otwieraniu aplikacji');
  String get biometric => _('Биометрия', 'Biometric unlock', 'Biometrie',
      'Odblokowanie biometryczne');
  String get biometricUnavailable => _(
      'Биометрия недоступна на этом устройстве — введите PIN',
      'Biometric unlock is unavailable on this device — enter your PIN',
      'Biometrie ist auf diesem Gerät nicht verfügbar — PIN eingeben',
      'Odblokowanie biometryczne jest niedostępne — wprowadź PIN');
  String get createPinStep1 =>
      _('Придумайте 4-значный PIN', 'Create a 4-digit PIN', 'PIN erstellen',
          'Utwórz 4-cyfrowy PIN');
  String get createPinStep2 => _('Повторите PIN', 'Repeat the PIN',
      'PIN wiederholen', 'Powtórz PIN');
  String get pinMismatch => _('PIN не совпадает, попробуйте снова',
      'PINs don\'t match, try again', 'PINs stimmen nicht überein',
      'PIN-y się nie zgadzają');
  String get pinSetDone => _('PIN установлен', 'PIN set', 'PIN gesetzt',
      'PIN ustawiony');
  String sendError(String name) => _('Ошибка отправки $name',
      'Error sending $name', 'Fehler beim Senden $name', 'Błąd wysyłania $name');
  String failed(String e) =>
      _('Не удалось: $e', 'Failed: $e', 'Fehlgeschlagen: $e', 'Nie udało się: $e');

  // Вложения
  String get files => _('Файлы', 'Files', 'Dateien', 'Pliki');
  String get gallery => _('Галерея', 'Gallery', 'Galerie', 'Galeria');
  String get camera => _('Камера', 'Camera', 'Kamera', 'Aparat');

  // Фильтры / группы / закрепление
  String get all => _('Все', 'All', 'Alle', 'Wszystkie');
  String get pinned => _('Закреплённые', 'Pinned', 'Angeheftet', 'Przypięte');
  String get pin => _('Закрепить', 'Pin', 'Anheften', 'Przypnij');
  String get unpin => _('Открепить', 'Unpin', 'Lösen', 'Odepnij');
  String get archived => _('Архив', 'Archive', 'Archiv', 'Archiwum');
  String get archive => _('В архив', 'Archive', 'Archivieren', 'Archiwizuj');
  String get unarchive =>
      _('Из архива', 'Unarchive', 'Aus Archiv', 'Wyjmij z archiwum');
  String get searchHint =>
      _('Поиск по сохранённому…', 'Search saved items…', 'Suche…', 'Szukaj…');

  // Терминальный стиль ленты
  String get hTerminal =>
      _('Терминальный стиль', 'Terminal style', 'Terminal-Stil', 'Styl terminala');
  String get terminalBubbles =>
      _('Терминальные блоки', 'Terminal blocks', 'Terminal-Blöcke', 'Bloki terminala');
  String get terminalBubblesSub => _(
      'Рамка с врезанной подписью вместо пузырей',
      'Framed blocks with inset label instead of bubbles',
      'Rahmen mit eingelassener Beschriftung',
      'Ramka z wpisaną etykietą');
  String get borderBrightness =>
      _('Яркость обводки', 'Border brightness', 'Rahmenhelligkeit', 'Jasność obramowania');
  String get readyThemes => _('Готовые темы', 'Presets', 'Vorlagen', 'Motywy');
  String get prefixContent =>
      _('Содержимое врезки', 'Label content', 'Beschriftung', 'Zawartość etykiety');
  String get prefixDevice => _('Устройство', 'Device', 'Gerät', 'Urządzenie');
  String get prefixType => _('Тип', 'Type', 'Typ', 'Typ');
  String get prefixSize => _('Размер', 'Size', 'Größe', 'Rozmiar');
  String get prefixTime => _('Время', 'Time', 'Zeit', 'Czas');
  String get addToGroup =>
      _('Добавить в группу…', 'Add to group…', 'Zur Gruppe…', 'Dodaj do grupy…');
  String groupName(String g) =>
      _('Группа: $g', 'Group: $g', 'Gruppe: $g', 'Grupa: $g');
  String get removeFromGroup => _('Убрать из группы', 'Remove from group',
      'Aus Gruppe entfernen', 'Usuń z grupy');
  String get newGroup =>
      _('Новая группа…', 'New group…', 'Neue Gruppe…', 'Nowa grupa…');
  String get saveAs =>
      _('Сохранить как…', 'Save as…', 'Speichern unter…', 'Zapisz jako…');
  String get saveTitle =>
      _('Сохранить файл', 'Save file', 'Datei speichern', 'Zapisz plik');
  String savedTo(String p) =>
      _('Сохранено: $p', 'Saved: $p', 'Gespeichert: $p', 'Zapisano: $p');
  String saveError2(String e) => _('Ошибка сохранения: $e',
      'Save error: $e', 'Speicherfehler: $e', 'Błąd zapisu: $e');

  // Типы
  String get fileWord => _('Файл', 'File', 'Datei', 'Plik');
  String get imageWord => _('Изображение', 'Image', 'Bild', 'Obraz');
  String get audioWord => _('Аудио', 'Audio', 'Audio', 'Audio');
  String get videoWord => _('Видео', 'Video', 'Video', 'Wideo');
  String get mediaWord => _('Медиа', 'Media', 'Medien', 'Media');
  String get voiceMessage => _('Голосовое сообщение', 'Voice message',
      'Sprachnachricht', 'Wiadomość głosowa');
  String get share => _('Поделиться', 'Share', 'Teilen', 'Udostępnij');
  String get recording =>
      _('Запись…', 'Recording…', 'Aufnahme…', 'Nagrywanie…');
  String get receivingLabel =>
      _('приём…', 'receiving…', 'Empfang…', 'odbieranie…');
  String get micDenied => _('Нет доступа к микрофону',
      'Microphone permission denied', 'Kein Mikrofonzugriff',
      'Brak dostępu do mikrofonu');
  String get today => _('Сегодня', 'Today', 'Heute', 'Dziś');
  String get yesterday => _('Вчера', 'Yesterday', 'Gestern', 'Wczoraj');
  String get thisWeek =>
      _('На этой неделе', 'This week', 'Diese Woche', 'W tym tygodniu');

  // Настройки — заголовки
  String get settings =>
      _('Настройки', 'Settings', 'Einstellungen', 'Ustawienia');
  String get hAccount => _('Аккаунт', 'Account', 'Konto', 'Konto');
  String get hDevice => _('Устройство', 'Device', 'Gerät', 'Urządzenie');
  String get hDesign => _('Дизайн', 'Design', 'Design', 'Wygląd');
  String get hAppearance =>
      _('Внешний вид', 'Appearance', 'Darstellung', 'Wygląd');
  String get hNetwork => _('Сеть', 'Network', 'Netzwerk', 'Sieć');
  String get hRemoteInput => _('Удалённый ввод (клавиатура на ПК)',
      'Remote input (keyboard on PC)', 'Ferneingabe (Tastatur am PC)',
      'Zdalne wpisywanie (klawiatura na PC)');
  String get hPlayer => _('Плеер', 'Player', 'Player', 'Odtwarzacz');
  String get hAbout => _('О приложении', 'About', 'Über', 'O aplikacji');
  String get hData => _('Данные', 'Data', 'Daten', 'Dane');
  String get hLanguage => _('Язык', 'Language', 'Sprache', 'Język');
  String get hBackground =>
      _('Фон и эффекты', 'Background & effects', 'Hintergrund & Effekte',
          'Tło i efekty');
  String get hFilesSync => _('Файлы и синхронизация', 'Files & sync',
      'Dateien & Synchronisierung', 'Pliki i synchronizacja');
  String get hSecurity =>
      _('Безопасность', 'Security', 'Sicherheit', 'Bezpieczeństwo');
  String get catFilesSyncSub => _('Облако/P2P, оффлайн-очередь, устройства',
      'Cloud/P2P, offline queue, devices',
      'Cloud/P2P, Offline-Warteschlange, Geräte',
      'Chmura/P2P, kolejka offline, urządzenia');
  String get catSecuritySub => _('Шифрование, PIN, биометрия',
      'Encryption, PIN, biometrics', 'Verschlüsselung, PIN, Biometrie',
      'Szyfrowanie, PIN, biometria');
  String get cloudRouting => _('Маршрутизация', 'Routing', 'Routing',
      'Trasowanie');
  String get cloudModeAuto => _('Авто (по размеру)', 'Auto (by size)',
      'Automatisch (nach Größe)', 'Automatycznie (wg rozmiaru)');
  String get cloudModeAlways => _('Всегда в облако', 'Always cloud',
      'Immer Cloud', 'Zawsze chmura');
  String get cloudModeNever => _('Только P2P', 'P2P only', 'Nur P2P',
      'Tylko P2P');
  String get selectiveSync => _('Избирательная синхронизация',
      'Selective sync', 'Selektive Synchronisierung',
      'Selektywna synchronizacja');
  String get selectiveSyncSub => _(
      'Не скачивать медиа из облака автоматически — только по запросу',
      'Don\'t auto-download media from the cloud — only on request',
      'Medien nicht automatisch aus der Cloud laden — nur auf Anfrage',
      'Nie pobieraj mediów automatycznie — tylko na żądanie');
  String get encryptCloud => _('Шифровать файлы в облаке',
      'Encrypt files in the cloud', 'Dateien in der Cloud verschlüsseln',
      'Szyfruj pliki w chmurze');
  String get encryptCloudSub => _(
      'AES-256 перед загрузкой в приватный репозиторий',
      'AES-256 before uploading to the private repo',
      'AES-256 vor dem Hochladen ins private Repo',
      'AES-256 przed przesłaniem do prywatnego repo');
  String get deviceHistory => _('История устройств', 'Device history',
      'Geräteverlauf', 'Historia urządzeń');
  String get selfDestruct => _('Самоуничтожение', 'Self-destruct',
      'Selbstzerstörung', 'Samozniszczenie');
  String get ttlOff => _('Без ограничения', 'Off', 'Aus', 'Wyłączone');
  String get ttl1m => _('Через 1 минуту', 'After 1 minute', 'Nach 1 Minute',
      'Po 1 minucie');
  String get ttl1h => _('Через 1 час', 'After 1 hour', 'Nach 1 Stunde',
      'Po 1 godzinie');
  String get ttl1d => _('Через 1 день', 'After 1 day', 'Nach 1 Tag',
      'Po 1 dniu');
  String get ttl1w => _('Через 1 неделю', 'After 1 week', 'Nach 1 Woche',
      'Po 1 tygodniu');
  String get download => _('Скачать', 'Download', 'Herunterladen', 'Pobierz');
  String get dropFilesHere => _('Отпустите, чтобы отправить файлы',
      'Drop to send files', 'Loslassen zum Senden', 'Upuść, aby wysłać');
  String get downloading =>
      _('Скачивание…', 'Downloading…', 'Herunterladen…', 'Pobieranie…');
  String get downloadFailed => _('Не удалось скачать', 'Download failed',
      'Herunterladen fehlgeschlagen', 'Nie udało się pobrać');

  // Подписи категорий (как в Google)
  String get catAccountSub => _('Вход, облако аккаунта',
      'Sign in, account cloud', 'Anmeldung, Konto-Cloud', 'Logowanie, chmura');
  String get catAppearanceSub => _('Тема, цвета, шрифт, дизайн',
      'Theme, colors, font, design', 'Thema, Farben, Schrift, Design',
      'Motyw, kolory, czcionka');
  String get catBackgroundSub => _('Фото-фон, снег/дождь, цвет сообщений',
      'Photo background, snow/rain, message colors',
      'Foto-Hintergrund, Schnee/Regen, Farben',
      'Tło, śnieg/deszcz, kolory');
  String get catNetworkSub => _('Поиск, порт, приём, фон',
      'Discovery, port, receive, background',
      'Suche, Port, Empfang, Hintergrund', 'Wyszukiwanie, port, odbiór');
  String get catRemoteSub => _('Печать с телефона на ПК',
      'Type from phone to PC', 'Vom Telefon zum PC tippen',
      'Pisanie z telefonu na PC');
  String get catPlayerSub => _('Автоплей, громкость',
      'Autoplay, volume', 'Autoplay, Lautstärke', 'Autoodtwarzanie, głośność');
  String get catAboutSub => _('Приветствие, версия, данные',
      'Welcome, version, data', 'Begrüßung, Version, Daten',
      'Powitanie, wersja, dane');
  String get catDeviceSub => _('Имя устройства',
      'Device name', 'Gerätename', 'Nazwa urządzenia');

  // Аккаунт
  String get signInGitHub => _('Войти через GitHub', 'Sign in with GitHub',
      'Mit GitHub anmelden', 'Zaloguj przez GitHub');
  String get signInSubtitle => _(
      'Устройства одного аккаунта соединяются автоматически',
      'Devices of one account connect automatically',
      'Geräte eines Kontos verbinden sich automatisch',
      'Urządzenia jednego konta łączą się automatycznie');
  String get signOut => _('Выйти', 'Sign out', 'Abmelden', 'Wyloguj');
  String get cloudOn => _('Облако аккаунта включено', 'Account cloud is on',
      'Konto-Cloud aktiv', 'Chmura konta włączona');
  String get cloudOnSub => _('Файлы до ~90 МБ доступны с любого устройства',
      'Files up to ~90 MB available on any device',
      'Dateien bis ~90 MB auf jedem Gerät',
      'Pliki do ~90 MB na każdym urządzeniu');
  String get cloudSyncing =>
      _('Синхронизация…', 'Syncing…', 'Synchronisiere…', 'Synchronizacja…');
  String get cloudOff =>
      _('Облако недоступно', 'Cloud unavailable', 'Cloud nicht verfügbar',
          'Chmura niedostępna');
  String get cloudReauth => _('Войдите заново, чтобы выдать доступ (repo)',
      'Sign in again to grant access (repo)',
      'Erneut anmelden für Zugriff (repo)',
      'Zaloguj ponownie, aby nadać dostęp (repo)');
  String get signInAgain =>
      _('Войти заново', 'Sign in again', 'Erneut anmelden', 'Zaloguj ponownie');
  String get loginTitle => _('Вход через GitHub', 'Sign in with GitHub',
      'GitHub-Anmeldung', 'Logowanie GitHub');
  String get loginDone =>
      _('Готово! Вы вошли.', 'Done! You are signed in.',
          'Fertig! Angemeldet.', 'Gotowe! Zalogowano.');
  String loginError(String e) =>
      _('Ошибка: $e', 'Error: $e', 'Fehler: $e', 'Błąd: $e');
  String get loginStep1 =>
      _('1. Скопируй код:', '1. Copy the code:', '1. Code kopieren:',
          '1. Skopiuj kod:');
  String get loginStep2 => _('2. Открой страницу и вставь код:',
      '2. Open the page and paste the code:',
      '2. Seite öffnen und Code einfügen:',
      '2. Otwórz stronę i wklej kod:');
  String get loginOpen => _('Открыть github.com/login/device',
      'Open github.com/login/device', 'github.com/login/device öffnen',
      'Otwórz github.com/login/device');
  String get loginWaiting => _('Ждём подтверждения…', 'Waiting for approval…',
      'Warte auf Bestätigung…', 'Czekam na potwierdzenie…');

  // Устройство / вид
  String get deviceName =>
      _('Имя устройства', 'Device name', 'Gerätename', 'Nazwa urządzenia');
  String get theme => _('Тема', 'Theme', 'Thema', 'Motyw');
  String get oledBg => _('Чёрный фон (OLED)', 'Black background (OLED)',
      'Schwarzer Hintergrund (OLED)', 'Czarne tło (OLED)');
  String get oledBgSub => _('Чистый чёрный в тёмной теме',
      'Pure black in dark theme', 'Reines Schwarz im Dunkelmodus',
      'Czysta czerń w ciemnym motywie');
  String get font => _('Шрифт', 'Font', 'Schrift', 'Czcionka');
  String get fontNormal =>
      _('Обычный', 'Normal', 'Normal', 'Zwykła');
  String get accentColor =>
      _('Акцентный цвет', 'Accent color', 'Akzentfarbe', 'Kolor akcentu');
  String get anyColor => _('Любой цвет', 'Any color', 'Beliebige Farbe',
      'Dowolny kolor');
  String get uiScale => _('Масштаб интерфейса', 'UI scale',
      'Oberflächengröße', 'Skala interfejsu');
  String get bubbleStyle =>
      _('Стиль пузырей', 'Bubble style', 'Blasenstil', 'Styl dymków');
  String get bubbleSoft => _('Мягкий', 'Soft', 'Weich', 'Miękki');
  String get bubbleRound => _('Круглый', 'Round', 'Rund', 'Okrągły');
  String get bubbleSharp => _('Острый', 'Sharp', 'Kantig', 'Ostry');
  String get gradientBg => _('Градиентный фон ленты', 'Gradient chat background',
      'Verlaufshintergrund', 'Gradientowe tło');
  String get chatPhoto => _('Фото-фон ленты', 'Chat photo background',
      'Foto-Hintergrund', 'Zdjęcie w tle');
  String get pickPhoto =>
      _('Выбрать фото', 'Pick photo', 'Foto wählen', 'Wybierz zdjęcie');
  String get removePhoto =>
      _('Убрать фото', 'Remove photo', 'Foto entfernen', 'Usuń zdjęcie');
  String get bgEffectLabel =>
      _('Эффект фона', 'Background effect', 'Hintergrundeffekt', 'Efekt tła');
  String get effectNone => _('Нет', 'None', 'Kein', 'Brak');
  String get effectBlur => _('Блюр', 'Blur', 'Unschärfe', 'Rozmycie');
  String get effectPixel => _('Пиксели', 'Pixels', 'Pixel', 'Piksele');
  String get dimLabel =>
      _('Затемнение', 'Dim', 'Abdunkeln', 'Przyciemnienie');
  String get weatherLabel =>
      _('Погода', 'Weather', 'Wetter', 'Pogoda');
  String get snow => _('Снег', 'Snow', 'Schnee', 'Śnieg');
  String get rain => _('Дождь', 'Rain', 'Regen', 'Deszcz');
  String get wSize => _('Размер', 'Size', 'Größe', 'Rozmiar');
  String get wDensity => _('Частота', 'Density', 'Dichte', 'Gęstość');
  String get wSpeed => _('Скорость', 'Speed', 'Geschwindigkeit', 'Prędkość');
  String get music => _('Музыка', 'Music', 'Musik', 'Muzyka');
  String get noMusic => _('Пока нет музыки в ленте', 'No music in the chat yet',
      'Noch keine Musik', 'Brak muzyki');
  String get playAll => _('Играть всё', 'Play all', 'Alle abspielen', 'Odtwórz wszystko');
  String get shuffle => _('Перемешать', 'Shuffle', 'Zufallswiedergabe', 'Losowo');
  String get repeatOff => _('Без повтора', 'No repeat', 'Keine Wiederholung', 'Bez powtarzania');
  String get repeatAll => _('Повтор плейлиста', 'Repeat playlist', 'Playlist wiederholen', 'Powtarzaj playlistę');
  String get repeatOne => _('Повтор трека', 'Repeat track', 'Titel wiederholen', 'Powtarzaj utwór');
  String get msgColors => _('Цвет сообщений', 'Message colors',
      'Nachrichtenfarben', 'Kolory wiadomości');
  String get outgoing =>
      _('Исходящие', 'Outgoing', 'Gesendet', 'Wychodzące');
  String get incoming =>
      _('Входящие', 'Incoming', 'Empfangen', 'Przychodzące');
  String get reset => _('Сброс', 'Reset', 'Zurücksetzen', 'Reset');
  String get compact =>
      _('Компактный режим', 'Compact mode', 'Kompaktmodus', 'Tryb kompaktowy');
  String get compactSub => _('Плотнее, меньше отступов',
      'Denser, less spacing', 'Dichter, weniger Abstand',
      'Gęściej, mniej odstępów');
  String get haptics =>
      _('Вибрация', 'Haptics', 'Vibration', 'Wibracje');
  String get hapticsSub => _('Отклик при нажатии и отправке',
      'Feedback on taps and sends', 'Rückmeldung bei Tipp und Senden',
      'Odzew przy dotknięciu i wysyłce');
  String get bgBlur =>
      _('Размытие фона', 'Background blur', 'Hintergrund-Unschärfe',
          'Rozmycie tła');
  String get bgDim =>
      _('Затемнение фона', 'Background dim', 'Hintergrund abdunkeln',
          'Przyciemnienie tła');
  String get off => _('Выкл', 'Off', 'Aus', 'Wył');
  String get snowSub => _('Падающий снег поверх фона',
      'Falling snow over the background', 'Fallender Schnee über dem Hintergrund',
      'Padający śnieg na tle');
  String get snowSlow => _('Медленно', 'Slow', 'Langsam', 'Wolno');
  String get snowMedium => _('Средне', 'Medium', 'Mittel', 'Średnio');
  String get snowFast => _('Быстро', 'Fast', 'Schnell', 'Szybko');

  String get animations =>
      _('Анимации', 'Animations', 'Animationen', 'Animacje');
  String get animationsSub => _('Плавное появление и переходы',
      'Smooth appearance and transitions', 'Sanftes Erscheinen und Übergänge',
      'Płynne pojawianie i przejścia');
  String get animStyle => _('Стиль анимации', 'Animation style',
      'Animationsstil', 'Styl animacji');
  String get animSpeed => _('Скорость анимаций', 'Animation speed',
      'Animationsgeschwindigkeit', 'Prędkość animacji');
  String get animRise => _('Подъём', 'Rise', 'Anstieg', 'Podniesienie');
  String get animScale => _('Масштаб', 'Scale', 'Skalierung', 'Skala');
  String get animRiseFade =>
      _('Подъём+Fade', 'Rise+Fade', 'Anstieg+Fade', 'Podniesienie+Fade');
  String get speedSlow => _('Медл.', 'Slow', 'Langsam', 'Wolno');
  String get speedNormal => _('Обычно', 'Normal', 'Normal', 'Zwykle');
  String get speedFast => _('Быстро', 'Fast', 'Schnell', 'Szybko');

  // Сеть
  String get autoDiscovery => _('Авто-поиск устройств', 'Auto-discovery',
      'Auto-Erkennung', 'Auto-wykrywanie');
  String get autoDiscoverySub => _('Находить устройства автоматически',
      'Find devices automatically', 'Geräte automatisch finden',
      'Znajduj urządzenia automatycznie');
  String get discoveryPort =>
      _('Порт поиска', 'Discovery port', 'Suchport', 'Port wyszukiwania');
  String get autoAccept => _('Принимать файлы автоматически',
      'Accept files automatically', 'Dateien automatisch annehmen',
      'Akceptuj pliki automatycznie');
  String get notifyReceive => _('Уведомлять о приёме', 'Notify on receive',
      'Bei Empfang benachrichtigen', 'Powiadom o odbiorze');
  String get backgroundReceive => _('Работать в фоне', 'Run in background',
      'Im Hintergrund laufen', 'Działaj w tle');
  String get backgroundReceiveSub => _(
      'Принимать файлы, даже когда приложение свёрнуто',
      'Receive files even when the app is minimized',
      'Dateien empfangen, auch wenn die App minimiert ist',
      'Odbieraj pliki, nawet gdy aplikacja jest zminimalizowana');
  String get bgTitle => 'TexFi files';
  String get bgText => _('Приём файлов активен', 'Receiving files',
      'Dateiempfang aktiv', 'Odbiór plików aktywny');

  // Удалённый ввод
  String get allowTyping => _('Разрешить печать с телефона',
      'Allow typing from phone', 'Tippen vom Telefon erlauben',
      'Zezwól na pisanie z telefonu');
  String engineLabel(String e) =>
      _('Движок: $e', 'Engine: $e', 'Engine: $e', 'Silnik: $e');
  String get inputOnlyLinux => _('Доступно только на Linux (ПК)',
      'Only on Linux (PC)', 'Nur unter Linux (PC)', 'Tylko na Linux (PC)');
  String get checking => _('Проверка…', 'Checking…', 'Prüfe…', 'Sprawdzam…');
  String get wtypeHint => _(
      'Установите wtype (sudo pacman -S wtype), чтобы печатать с телефона с кириллицей.',
      'Install wtype (sudo pacman -S wtype) to type from the phone.',
      'Installiere wtype (sudo pacman -S wtype) zum Tippen vom Telefon.',
      'Zainstaluj wtype (sudo pacman -S wtype), aby pisać z telefonu.');

  // Плеер
  String get autoplay => _('Автовоспроизведение', 'Autoplay', 'Autoplay',
      'Autoodtwarzanie');
  String get playerVolume =>
      _('Громкость плеера', 'Player volume', 'Lautstärke', 'Głośność');
  String get nowPlaying =>
      _('Сейчас играет', 'Now playing', 'Läuft gerade', 'Teraz gra');
  String get nothingPlaying => _('Ничего не играет', 'Nothing is playing',
      'Nichts läuft', 'Nic nie gra');

  // О приложении / данные
  String get showOnboarding => _('Показать приветствие', 'Show welcome',
      'Begrüßung zeigen', 'Pokaż powitanie');
  String get clearAll => _('Очистить всё «Избранное»', 'Clear all saved',
      'Alles löschen', 'Wyczyść wszystko');
  String get clearConfirmTitle =>
      _('Очистить всё?', 'Clear everything?', 'Alles löschen?',
          'Wyczyścić wszystko?');
  String get clearConfirmText => _(
      'Все сообщения и полученные файлы будут удалены безвозвратно.',
      'All messages and received files will be permanently deleted.',
      'Alle Nachrichten und empfangenen Dateien werden dauerhaft gelöscht.',
      'Wszystkie wiadomości i pliki zostaną trwale usunięte.');
  String get clearBtn => _('Очистить', 'Clear', 'Löschen', 'Wyczyść');
  String get systemLang =>
      _('Системный', 'System', 'System', 'Systemowy');

  // Устройства
  String get devicesTitle =>
      _('Устройства', 'Devices', 'Geräte', 'Urządzenia');
  String get thisDevice =>
      _('Это устройство', 'This device', 'Dieses Gerät', 'To urządzenie');
  String get yourAccount =>
      _('ваш аккаунт', 'your account', 'dein Konto', 'twoje konto');
  String get online => _('онлайн', 'online', 'online', 'online');
  String get offline => _('не в сети', 'offline', 'offline', 'offline');
  String get searchingAccount => _('Осматриваюсь в сети…',
      'Looking around the network…', 'Sehe mich im Netzwerk um…',
      'Rozglądam się po sieci…');
  String get searchingAccountSub => _(
      'Войдите этим же GitHub-аккаунтом на другом устройстве. Для передачи они должны быть в одной сети.',
      'Sign in with the same GitHub account on another device. They must share a network to transfer.',
      'Melde dich mit demselben GitHub-Konto auf einem anderen Gerät an. Zum Übertragen im selben Netzwerk.',
      'Zaloguj się tym samym kontem GitHub na innym urządzeniu. Do przesyłania muszą być w tej samej sieci.');
  String get needLoginTitle =>
      _('Войдите в аккаунт', 'Sign in', 'Anmelden', 'Zaloguj się');
  String get needLoginText => _(
      'Устройства находят друг друга через ваш GitHub-аккаунт. Войдите в Настройках → Аккаунт.',
      'Devices find each other via your GitHub account. Sign in under Settings → Account.',
      'Geräte finden sich über dein GitHub-Konto. Anmelden unter Einstellungen → Konto.',
      'Urządzenia znajdują się przez konto GitHub. Zaloguj w Ustawienia → Konto.');
  String get select => _('Выбрать', 'Select', 'Auswählen', 'Wybierz');
  String get labels => _('Метки', 'Labels', 'Labels', 'Etykiety');
  String get newLabel => _('Новая метка', 'New label', 'Neues Label',
      'Nowa etykieta');
  String get moveToFolder => _('В папку', 'Move to folder', 'In Ordner',
      'Do folderu');
  String selectedCount(int n) => _(
      '$n ${_plural(n, 'выбран', 'выбрано', 'выбрано')}',
      '$n selected', '$n ausgewählt', 'Wybrano: $n');
  String get selectAll => _('Все', 'All', 'Alle', 'Wszystkie');
  String get nobodyAroundTitle => _('Пока никого рядом',
      'Nobody around yet', 'Noch niemand in der Nähe', 'Na razie nikogo obok');
  String get nobodyAroundText => _(
      'Открой TexFi files на другом устройстве в этой же сети — оно появится здесь само.',
      'Open TexFi files on another device on this network — it will show up here by itself.',
      'Öffne TexFi files auf einem anderen Gerät im selben Netzwerk — es erscheint hier von selbst.',
      'Otwórz TexFi files na innym urządzeniu w tej samej sieci — pojawi się tu samo.');
  String peerAppeared(String name) => _(
      '$name на связи',
      '$name is on the line',
      '$name ist verbunden',
      '$name na łączu');
  String get connectByIp =>
      _('Подключиться по IP', 'Connect by IP', 'Per IP verbinden',
          'Połącz przez IP');
  String get byIp => _('По IP', 'By IP', 'Per IP', 'Przez IP');
  String get showQr => _('Мой QR-код', 'My QR code', 'Mein QR-Code',
      'Mój kod QR');
  String get scanQr => _('Сканировать QR', 'Scan QR', 'QR scannen',
      'Skanuj QR');
  String get scanQrError => _(
      'Не удалось запустить камеру. Попробуйте ещё раз.',
      'Could not start the camera. Please try again.',
      'Kamera konnte nicht gestartet werden. Bitte erneut versuchen.',
      'Nie udało się uruchomić aparatu. Spróbuj ponownie.');
  String get cameraPermissionDenied => _(
      'Нет доступа к камере. Разрешите его в настройках системы.',
      'Camera access denied. Allow it in system settings.',
      'Kein Kamerazugriff. Bitte in den Systemeinstellungen erlauben.',
      'Brak dostępu do aparatu. Zezwól w ustawieniach systemu.');
  String get retry => _('Повторить', 'Retry', 'Erneut versuchen', 'Ponów');
  String get ipAddress => _('IP адрес', 'IP address', 'IP-Adresse', 'Adres IP');
  String get port => _('Порт', 'Port', 'Port', 'Port');
  String get connect => _('Подключить', 'Connect', 'Verbinden', 'Połącz');
  String connectedTo(String n) =>
      _('Подключено: $n', 'Connected: $n', 'Verbunden: $n', 'Połączono: $n');
  String connectFail(String ip) => _('Не удалось подключиться к $ip',
      'Could not connect to $ip', 'Verbindung zu $ip fehlgeschlagen',
      'Nie połączono z $ip');

  // Клавиатура на ПК
  String get keyboardTitle => _('Клавиатура на ПК', 'Keyboard on PC',
      'Tastatur am PC', 'Klawiatura na PC');
  String get live => _('Вживую', 'Live', 'Live', 'Na żywo');
  String get send => _('Отправить', 'Send', 'Senden', 'Wyślij');
  String get noPcTitle =>
      _('Нет ПК в сети', 'No PC on the network', 'Kein PC im Netzwerk',
          'Brak PC w sieci');
  String get noPcText => _(
      'Запустите TexFi files на компьютере (Linux) в той же Wi-Fi сети.',
      'Run TexFi files on a computer (Linux) on the same Wi-Fi.',
      'Starte TexFi files auf einem Computer (Linux) im selben WLAN.',
      'Uruchom TexFi files na komputerze (Linux) w tej samej sieci Wi-Fi.');
  String sentToName(String n) => _('Отправлено на $n', 'Sent to $n',
      'Gesendet an $n', 'Wysłano do $n');
  String get notSent =>
      _('Не получилось', 'Failed', 'Fehlgeschlagen', 'Nie udało się');
  String get typeLiveHint => _('Печатайте — символы уходят на ПК сразу',
      'Type — characters go to the PC instantly',
      'Tippe — Zeichen gehen sofort an den PC',
      'Pisz — znaki trafiają od razu na PC');
  String get typeSendHint => _('Напишите текст и нажмите «Отправить»',
      'Write text and tap Send', 'Text schreiben und Senden tippen',
      'Napisz tekst i naciśnij Wyślij');

  // Онбординг
  String get skip => _('Пропустить', 'Skip', 'Überspringen', 'Pomiń');
  String get next => _('Далее', 'Next', 'Weiter', 'Dalej');
  String get start => _('Начать', 'Start', 'Los', 'Zacznij');
  String get obTitle1 => 'TexFi files';
  String get obText1 => _(
      'Ваше «Избранное» — как в Telegram, только своё и без лимитов.',
      'Your Saved Messages — like Telegram, but yours and without limits.',
      'Deine Favoriten — wie Telegram, aber deine und ohne Limits.',
      'Twoje zapisane — jak Telegram, ale własne i bez limitów.');
  String get obTitle2 =>
      _('Шлите что угодно', 'Send anything', 'Sende alles', 'Wyślij cokolwiek');
  String get obText2 => _(
      'Текст, фото, видео и файлы любого размера — между вашими устройствами.',
      'Text, photos, video and files of any size — between your devices.',
      'Text, Fotos, Videos und Dateien jeder Größe — zwischen deinen Geräten.',
      'Tekst, zdjęcia, wideo i pliki dowolnego rozmiaru — między urządzeniami.');
  String get obTitle3 => _('Аккаунт — ваше облако', 'Account is your cloud',
      'Konto ist deine Cloud', 'Konto to twoja chmura');
  String get obText3 => _(
      'Войдите через GitHub, и файлы будут доступны с любого устройства из любой сети.',
      'Sign in with GitHub and your files are available on any device, any network.',
      'Melde dich mit GitHub an — Dateien auf jedem Gerät, in jedem Netzwerk.',
      'Zaloguj przez GitHub — pliki dostępne na każdym urządzeniu i sieci.');
  String get obTitle4 => _('Плеер и кастомизация', 'Player & customization',
      'Player & Anpassung', 'Odtwarzacz i personalizacja');
  String get obText4 => _(
      'Встроенный плеер с обложками, темы, дизайны Apple/Samsung, любые цвета и анимации.',
      'Built-in player with album art, themes, Apple/Samsung skins, any colors and animations.',
      'Player mit Cover, Themes, Apple/Samsung-Designs, Farben und Animationen.',
      'Odtwarzacz z okładkami, motywy, style Apple/Samsung, kolory i animacje.');

  // Приём (снекбар)
  String receivedText(String from) => _('Текст от $from', 'Text from $from',
      'Text von $from', 'Tekst od $from');
  String receivedFile(String from) => _('Файл от $from', 'File from $from',
      'Datei von $from', 'Plik od $from');
}

/// Быстрый доступ: `tr(context).settings`.
AppStrings tr(BuildContext context) =>
    AppStrings(AppScope.of(context).settings.effectiveLanguageCode);
