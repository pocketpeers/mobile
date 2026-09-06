import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pocketpeers/src/core/formatters.dart';

/// Protege el formato de los montos.
///
/// Existe por una regresion concreta: fijar `Intl.defaultLocale = 'es'` para que
/// las fechas salieran en español cambio los importes de «S/ 90.00» a
/// «90,00 S/» en toda la aplicacion, sin tocar una sola linea de moneda.
void main() {
  setUpAll(() => initializeDateFormatting(appDateLocale));

  test('el simbolo va delante del monto', () {
    expect(formatCurrency(90), startsWith('S/'));
    expect(formatCurrency(90), 'S/ 90.00');
  });

  test('usa punto decimal y coma para los miles', () {
    expect(formatCurrency(1234.5), 'S/ 1,234.50');
  });

  test('siempre muestra dos decimales', () {
    expect(formatCurrency(5), 'S/ 5.00');
    expect(formatCurrency(0), 'S/ 0.00');
  });

  test('los negativos conservan el formato', () {
    expect(formatCurrency(-90), contains('90.00'));
  });

  test('las fechas salen con el mes en español', () {
    expect(formatDate(DateTime(2026, 9, 5)), contains('2026'));
    expect(formatDate(null), 'Sin fecha');
  });
}
