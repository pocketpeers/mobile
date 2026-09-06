import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'src/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Los nombres de mes y dia en español no vienen cargados por defecto: hay que
  // pedirlos antes de que alguna pantalla formatee una fecha. Sin esto,
  // cualquier DateFormat con locale 'es' lanza LocaleDataException y rompe la
  // pantalla donde aparezca.
  await initializeDateFormatting('es');

  runApp(const ProviderScope(child: PocketPeersApp()));
}
