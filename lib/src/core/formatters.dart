import 'package:intl/intl.dart';

final currencyFormatter =
    NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);
final shortDateFormatter = DateFormat('dd MMM yyyy');
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
