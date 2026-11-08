import 'package:flutter_test/flutter_test.dart';
import 'package:arsad/core/money.dart';

void main() {
  group('Money', () {
    test('parses Riyal values into integer halalas', () {
      expect(Money.parseHalalas('1.00'), 100);
      expect(Money.parseHalalas('12.35'), 1235);
      expect(Money.parseHalalas('0'), 0);
    });
    test('rejects invalid and negative values', () {
      expect(() => Money.parseHalalas('abc'), throwsFormatException);
      expect(() => Money.parseHalalas('-1'), throwsFormatException);
    });
  });
}
