import 'package:flutter/material.dart';

/// Именованный доступ к стилям текста — `context.text.screenTitle` вместо
/// `Theme.of(context).textTheme.headlineMedium!`.
///
/// Смысл в том, чтобы на экранах не приходилось помнить, какой слот
/// TextTheme за что отвечает: имена здесь описывают роль, а не размер.
class AppTextStyles {
  const AppTextStyles(this._t);
  final TextTheme _t;

  /// Unbounded. Заголовок экрана.
  TextStyle get screenTitle => _t.headlineMedium!;

  /// Mono. Заголовок секции.
  TextStyle get sectionTitle => _t.headlineSmall!;

  /// Mono. Короткая метка кнопки.
  TextStyle get buttonLabel => _t.labelLarge!;

  /// Unbounded. Крупное число.
  TextStyle get statLarge => _t.displayMedium!;
  TextStyle get statSmall => _t.displaySmall!;

  /// Гротеск. Содержимое сообщений и прочий читаемый текст.
  TextStyle get body => _t.bodyMedium!;
  TextStyle get bodyLarge => _t.bodyLarge!;
  TextStyle get bodySmall => _t.bodySmall!;

  /// Гротеск. Заголовок строки списка и подпись под ним.
  TextStyle get tileTitle => _t.titleMedium!;
  TextStyle get tileTitleSmall => _t.titleSmall!;
  TextStyle get caption => _t.labelMedium!;
  TextStyle get captionSmall => _t.labelSmall!;
}

extension AppTextStylesContext on BuildContext {
  AppTextStyles get text => AppTextStyles(Theme.of(this).textTheme);
}
