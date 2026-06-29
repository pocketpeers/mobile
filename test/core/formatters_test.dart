import 'package:flutter_test/flutter_test.dart';
import 'package:pocketpeers/src/core/formatters.dart';

void main() {
  test('formatCurrency uses soles with two decimals', () {
    expect(formatCurrency(12.5), contains('S/'));
    expect(formatCurrency(12.5), contains('12.50'));
  });

  test('formatDate returns fallback for missing date', () {
    expect(formatDate(null), 'Sin fecha');
  });

  test('formatDate formats provided date', () {
    expect(formatDate(DateTime(2026, 6, 25)), contains('2026'));
  });

  group('formatBlockchainHash', () {
    test('returns pending for blank hashes', () {
      expect(formatBlockchainHash('   '), 'Pendiente');
    });

    test('keeps short hashes with leading hash mark', () {
      expect(formatBlockchainHash('abc123'), '#abc123');
    });

    test('shortens long hashes', () {
      expect(formatBlockchainHash('1234567890abcdef'), '#1234567...cdef');
    });
  });
}
