import 'package:intl/intl.dart';
import '../l10n/app_strings.dart';

String humanSize(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var i = 0;
  double v = bytes.toDouble();
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  final s = v >= 100 || i == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  return '$s ${units[i]}';
}

String clockTime(DateTime dt) => DateFormat('HH:mm').format(dt);

String daySeparator(DateTime dt, AppStrings t) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(dt.year, dt.month, dt.day);
  final diff = today.difference(that).inDays;
  if (diff == 0) return t.today;
  if (diff == 1) return t.yesterday;
  return DateFormat('d MMMM').format(dt);
}
