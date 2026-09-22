import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pocketpeers/src/core/formatters.dart';

void main() {
  // Los formateadores de fecha llevan el locale escrito, y intl exige cargar
  // sus datos antes de usarlo. Sin esta linea, formatDate lanza
  // LocaleDataException en las pruebas aunque funcione en la aplicacion, donde
  // main() ya lo inicializa.
  setUpAll(() => initializeDateFormatting(appDateLocale));

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
