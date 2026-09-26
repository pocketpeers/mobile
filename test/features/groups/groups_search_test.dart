import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketpeers/src/data/models.dart';
import 'package:pocketpeers/src/features/groups/group_screens.dart';
import 'package:pocketpeers/src/state/providers.dart';

Group _group(int id, String name, [String description = '']) => Group(
      id: id,
      name: name,
      description: description,
      groupPhoto: '',
      adminId: 1,
    );

void main() {
  testWidgets('filtra los grupos propios mientras se escribe', (tester) async {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const GroupsScreen()),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        groupsProvider.overrideWith((ref) async => [
              _group(1, 'Depa Miraflores', 'Luz y agua'),
              _group(2, 'Viaje a Cusco'),
            ]),
        myInvitationsProvider.overrideWith((ref) async => const []),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    // Ya no hay boton de buscar al lado del campo: solo la lupa de adentro.
    expect(find.byIcon(Icons.search), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'cus');
    await tester.pump();
    expect(find.text('Viaje a Cusco'), findsOneWidget);
    expect(find.text('Depa Miraflores'), findsNothing);

    // Tambien busca en la descripcion.
    await tester.enterText(find.byType(TextField), 'agua');
    await tester.pump();
    expect(find.text('Depa Miraflores'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'playa');
    await tester.pump();
    expect(find.text('Ningun grupo coincide con «playa»'), findsOneWidget);

    await tester.tap(find.byTooltip('Limpiar'));
    await tester.pump();
    expect(find.text('Depa Miraflores'), findsOneWidget);
    expect(find.text('Viaje a Cusco'), findsOneWidget);
  });
}
