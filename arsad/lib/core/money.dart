import 'package:intl/intl.dart';

class Money {
  Money._();

  static int parseHalalas(String value) {
    final normalized = value.trim().replaceAll(',', '.');
    final match = RegExp(r'^([0-9]+)(?:\.([0-9]{1,2}))?$').firstMatch(normalized);
    if (match == null) throw const FormatException('أدخل مبلغاً صحيحاً حتى منزلتين عشريتين');
    final whole = int.parse(match.group(1)!);
    final fraction = (match.group(2) ?? '').padRight(2, '0');
    return whole * 100 + (fraction.isEmpty ? 0 : int.parse(fraction));
  }

  static String format(int halalas) =>
      '${NumberFormat('#,##0.00', 'en').format(halalas / 100)} ر.س';
}
