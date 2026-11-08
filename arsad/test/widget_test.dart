import 'package:flutter_test/flutter_test.dart';
import 'package:arsad/core/money.dart';

void main() {
  test('ARSAD formats integer halalas', () {
    expect(Money.format(3250), contains('32.50'));
  });
}
