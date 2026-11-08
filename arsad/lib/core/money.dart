import 'package:intl/intl.dart';

class Money {
  Money._();
  static int parseHalalas(String value) {
    final amount = double.tryParse(value.trim().replaceAll(',', '.'));
    if (amount == null || !amount.isFinite || amount < 0) throw const FormatException('قيمة مالية غير صحيحة');
    return (amount * 100).round();
  }
  static String format(int halalas) => '${NumberFormat('#,##0.00', 'en').format(halalas / 100)} ر.س';
}
