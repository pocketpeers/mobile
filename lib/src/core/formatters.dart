import 'package:intl/intl.dart';

/// Español de Latinoamérica.
///
/// Se declara el locale en cada formateador en vez de apoyarse en
/// `Intl.defaultLocale`. Esa variable es global: cambiarla en un lugar altera en
/// silencio cómo se ven los montos en toda la app, que es justo lo que pasó
/// cuando se fijó a `'es'` y los importes pasaron de «S/ 90.00» a «90,00 S/».
///
/// No es `es_PE`: en esta versión de intl se comporta como el español de España
/// y pone el símbolo detrás. `es_419` es el que usa la convención peruana de
/// símbolo delante y punto decimal.
const appLocale = 'es_419';

/// Locale para nombres de mes y día. Requiere `initializeDateFormatting`.
const appDateLocale = 'es';

final currencyFormatter = NumberFormat.currency(
  locale: appLocale,
  symbol: 'S/ ',
  decimalDigits: 2,
);
final shortDateFormatter = DateFormat('dd MMM yyyy', appDateLocale);

/// Formato de intercambio con el backend: sin locale a propósito, para que no
/// dependa de cómo esté configurada la app.
final inputDateFormatter = DateFormat('yyyy-MM-dd');

String formatCurrency(num value) => currencyFormatter.format(value);

String formatDate(DateTime? value) {
  if (value == null) return 'Sin fecha';
  return shortDateFormatter.format(value);
}

String formatBlockchainHash(String value) {
  final hash = value.trim();
  if (hash.isEmpty) return 'Pendiente';
  if (hash.length <= 14) return '#$hash';
  return '#${hash.substring(0, 7)}...${hash.substring(hash.length - 4)}';
}
