import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketpeers/src/core/app_theme.dart';
import 'package:pocketpeers/src/data/models.dart';
import 'package:pocketpeers/src/data/pocketpeers_api.dart';
import 'package:pocketpeers/src/features/groups/invite_member_dialog.dart';
import 'package:pocketpeers/src/features/groups/pending_invitations.dart';
import 'package:pocketpeers/src/state/providers.dart';

/// API falsa: responde con datos fijos y anota lo que se le pidio.
class _FakeApi extends PocketPeersApi {
  final candidates = <String, InvitationCandidate>{};
  final sentInvitations = <GroupInvitation>[];
  final myInvitations = <GroupInvitation>[];
  final invitedUsernames = <String>[];
  final rejectedIds = <int>[];
  final cancelledIds = <int>[];
  var generatedCodes = 0;

  @override
  Future<InvitationCandidate?> findInvitationCandidate({
    required int groupId,
    required String username,
  }) async =>
      candidates[username];

  @override
  Future<GroupInvitation> inviteMember({
    required int groupId,
    required String username,
  }) async {
    invitedUsernames.add(username);
    final invitation = _invitation(id: 50, invitedUsername: username);
    sentInvitations.add(invitation);
    return invitation;
  }

  @override
  Future<List<GroupInvitation>> getGroupInvitations(int groupId) async =>
      List.of(sentInvitations);

  @override
  Future<List<GroupInvitation>> getMyInvitations() async =>
      List.of(myInvitations);

  @override
  Future<void> cancelInvitation({
    required int groupId,
    required int invitationId,
  }) async {
    cancelledIds.add(invitationId);
    sentInvitations.removeWhere((invitation) => invitation.id == invitationId);
  }

  @override
  Future<void> rejectInvitation(int invitationId) async {
    rejectedIds.add(invitationId);
    myInvitations.removeWhere((invitation) => invitation.id == invitationId);
  }

  @override
  Future<String> generateInvitation(int groupId) async {
    generatedCodes++;
    return 'codigo-del-grupo';
  }
}

class _FailingApi extends _FakeApi {
  @override
  Future<List<GroupInvitation>> getGroupInvitations(int groupId) async =>
      throw Exception('404');
}

GroupInvitation _invitation({
  int id = 1,
  String groupName = 'Depa Miraflores',
  String invitedUsername = 'mialaos',
  String invitedFullName = '',
  DateTime? expiresAt,
}) =>
    GroupInvitation(
      id: id,
      groupId: 10,
      groupName: groupName,
      groupPhoto: '',
      invitedUserId: 2,
      invitedUsername: invitedUsername,
      invitedFullName: invitedFullName,
      invitedPhoto: '',
      invitedByUsername: 'admin',
      invitedByFullName: 'Salvador Solano',
      expiresAt: expiresAt,
    );

const _mia = InvitationCandidate(
  userId: 2,
  username: 'mialaos',
  fullName: 'Mia Laos',
  photo: '',
  availability: InvitationAvailability.available,
);

Future<void> _pump(WidgetTester tester, _FakeApi api, Widget child,
    {bool dark = false}) async {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => Scaffold(body: child)),
    GoRoute(path: '/groups/:id', builder: (_, __) => const Scaffold()),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      apiProvider.overrideWithValue(api),
      myInvitationsProvider.overrideWith((ref) => api.getMyInvitations()),
    ],
    // Con el tema de la app: el de Flutter por defecto no tiene el ancho
    // minimo infinito de los FilledButton, y con el las pruebas pasaban
    // mientras la tarjeta reventaba en el telefono.
    child: MaterialApp.router(
      routerConfig: router,
      theme: dark ? AppTheme.dark : AppTheme.light,
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('Invitar por usuario', () {
    testWidgets('muestra a quien se encontro y le manda la invitacion',
        (tester) async {
      final api = _FakeApi()..candidates['mialaos'] = _mia;
      await _pump(tester, api, const InviteMemberDialog(groupId: 10));

      await tester.enterText(find.byType(TextField), '@mialaos');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      // La arroba escrita se quita: ya esta fija delante del campo.
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'mialaos');
      expect(find.text('Mia Laos'), findsOneWidget);
      expect(find.text('@mialaos'), findsOneWidget);

      await tester.tap(find.text('Enviar invitacion'));
      await tester.pumpAndSettle();

      expect(api.invitedUsernames, ['mialaos']);
      expect(find.text('Invitacion enviada a Mia Laos.'), findsOneWidget);
      // La invitacion recien mandada aparece entre las que esperan respuesta.
      expect(find.text('Esperando respuesta (1)'), findsOneWidget);
    });

    testWidgets('avisa cuando el usuario no existe', (tester) async {
      final api = _FakeApi();
      await _pump(tester, api, const InviteMemberDialog(groupId: 10));

      await tester.enterText(find.byType(TextField), 'nadie');
      await tester.tap(find.byTooltip('Buscar'));
      await tester.pumpAndSettle();

      expect(
        find.text('No se encontro el usuario. Revisa que este bien escrito.'),
        findsOneWidget,
      );
      expect(find.text('Enviar invitacion'), findsNothing);
    });

    testWidgets('no deja invitar a quien ya es integrante', (tester) async {
      final api = _FakeApi()
        ..candidates['mialaos'] = const InvitationCandidate(
          userId: 2,
          username: 'mialaos',
          fullName: 'Mia Laos',
          photo: '',
          availability: InvitationAvailability.alreadyMember,
        );
      await _pump(tester, api, const InviteMemberDialog(groupId: 10));

      await tester.enterText(find.byType(TextField), 'mialaos');
      await tester.tap(find.byTooltip('Buscar'));
      await tester.pumpAndSettle();

      expect(find.text('Ya es integrante del grupo.'), findsOneWidget);
      final send = tester.widget<ButtonStyleButton>(find.ancestor(
        of: find.text('Enviar invitacion'),
        matching: find.bySubtype<ButtonStyleButton>(),
      ));
      expect(send.onPressed, isNull);
    });

    testWidgets('cambiar el texto descarta a la persona encontrada',
        (tester) async {
      final api = _FakeApi()..candidates['mialaos'] = _mia;
      await _pump(tester, api, const InviteMemberDialog(groupId: 10));

      await tester.enterText(find.byType(TextField), 'mialaos');
      await tester.tap(find.byTooltip('Buscar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'mialao');
      await tester.pumpAndSettle();

      expect(find.text('Mia Laos'), findsNothing);
      expect(find.text('Enviar invitacion'), findsNothing);
    });

    testWidgets('el codigo se pide recien al abrir su pestana',
        (tester) async {
      final api = _FakeApi();
      await _pump(tester, api, const InviteMemberDialog(groupId: 10));
      expect(api.generatedCodes, 0);

      await tester.tap(find.text('Con codigo'));
      await tester.pumpAndSettle();

      expect(api.generatedCodes, 1);
      expect(find.text('codigo-del-grupo'), findsOneWidget);
    });
  });

  group('Invitaciones recibidas', () {
    testWidgets('la entrada se ve aunque no haya ninguna', (tester) async {
      await _pump(tester, _FakeApi(), const PendingInvitationsSection());

      expect(find.text('Invitaciones recibidas'), findsOneWidget);
      expect(find.text('No tienes invitaciones pendientes'), findsOneWidget);

      await tester.tap(find.text('Invitaciones recibidas'));
      await tester.pumpAndSettle();
      expect(find.text('No has recibido invitaciones'), findsOneWidget);
    });

    for (final dark in [false, true]) {
      testWidgets('lista las recibidas y permite rechazar (oscuro: $dark)',
          (tester) async {
        final api = _FakeApi()..myInvitations.add(_invitation(id: 7));
        await _pump(tester, api, const PendingInvitationsSection(), dark: dark);

        expect(find.text('1 invitacion espera tu respuesta'), findsOneWidget);
        await tester.tap(find.text('Invitaciones recibidas'));
        await tester.pumpAndSettle();

        // Sin excepciones de dibujo: es lo que rompia la tarjeta en el telefono.
        expect(tester.takeException(), isNull);
        expect(find.text('Depa Miraflores'), findsOneWidget);
        expect(find.text('Salvador Solano te invito a unirte'), findsOneWidget);
        expect(find.text('Aceptar'), findsOneWidget);

        await tester.tap(find.text('Rechazar'));
        await tester.pumpAndSettle();
        await tester.tap(find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Rechazar'),
        ));
        await tester.pumpAndSettle();

        expect(api.rejectedIds, [7]);
        expect(find.text('No has recibido invitaciones'), findsOneWidget);
      });
    }

    testWidgets('volver sin confirmar no rechaza', (tester) async {
      final api = _FakeApi()..myInvitations.add(_invitation(id: 7));
      await _pump(tester, api, const ReceivedInvitationsScreen());

      await tester.tap(find.text('Rechazar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();

      expect(api.rejectedIds, isEmpty);
      expect(find.text('Depa Miraflores'), findsOneWidget);
    });
  });

  group('Invitaciones enviadas', () {
    test('el vencimiento se cuenta en dias de calendario', () {
      final now = DateTime(2026, 9, 26, 23, 30);
      expect(invitationExpiryLabel(DateTime(2026, 9, 26, 23, 59), now),
          'Vence hoy');
      // Faltan 31 minutos, pero ya es otro dia.
      expect(invitationExpiryLabel(DateTime(2026, 9, 27, 0, 1), now),
          'Vence mañana');
      expect(invitationExpiryLabel(DateTime(2026, 10, 3, 10), now),
          'Vence en 7 dias');
      expect(invitationExpiryLabel(null, now), 'Pendiente');
    });

    testWidgets('lista las pendientes con su vencimiento', (tester) async {
      final api = _FakeApi()
        ..sentInvitations.add(_invitation(
          id: 4,
          invitedFullName: 'Mia Laos',
          expiresAt: DateTime.now().add(const Duration(days: 5)),
        ));
      await _pump(
        tester,
        api,
        const SentInvitationsList(
          groupId: 10,
          title: 'Invitaciones pendientes',
        ),
      );

      expect(find.text('Invitaciones pendientes (1)'), findsOneWidget);
      expect(find.text('Mia Laos'), findsOneWidget);
      expect(find.text('@mialaos · Vence en 5 dias'), findsOneWidget);
    });

    testWidgets('sin pendientes no dibuja nada', (tester) async {
      await _pump(
        tester,
        _FakeApi(),
        const SentInvitationsList(groupId: 10, title: 'Pendientes'),
      );

      expect(find.textContaining('Pendientes'), findsNothing);
    });

    testWidgets('cancelar pide confirmacion', (tester) async {
      final api = _FakeApi()
        ..sentInvitations.add(_invitation(id: 4, invitedFullName: 'Mia Laos'));
      await _pump(
        tester,
        api,
        const SentInvitationsList(groupId: 10, title: 'Pendientes'),
      );

      await tester.tap(find.byTooltip('Cancelar invitacion'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();
      expect(api.cancelledIds, isEmpty);

      await tester.tap(find.byTooltip('Cancelar invitacion'));
      await tester.pumpAndSettle();
      // El titulo del dialogo dice lo mismo: se toca el boton.
      await tester.tap(find.widgetWithText(FilledButton, 'Cancelar invitacion'));
      await tester.pumpAndSettle();

      expect(api.cancelledIds, [4]);
      expect(find.text('Mia Laos'), findsNothing);
    });
  });

  group('Acceso desde el grupo', () {
    testWidgets('se ve aunque no haya invitaciones', (tester) async {
      await _pump(tester, _FakeApi(), const PendingInvitationsEntry(groupId: 10));

      expect(find.text('Invitaciones pendientes'), findsOneWidget);
      expect(find.text('Ninguna esperando respuesta'), findsOneWidget);

      await tester.tap(find.text('Invitaciones pendientes'));
      await tester.pumpAndSettle();
      expect(find.text('Nadie tiene una invitacion sin responder.'),
          findsOneWidget);

      // Desde ahi se puede invitar directamente.
      await tester.tap(find.text('Invitar'));
      await tester.pumpAndSettle();
      expect(find.text('Agregar integrante'), findsOneWidget);
    });

    testWidgets('muestra cuantas hay y las lista al tocar', (tester) async {
      final api = _FakeApi()
        ..sentInvitations.addAll([
          _invitation(id: 4, invitedFullName: 'Mia Laos'),
          _invitation(id: 5, invitedUsername: 'jperez', invitedFullName: 'Juan Perez'),
        ]);
      await _pump(tester, api, const PendingInvitationsEntry(groupId: 10));

      expect(find.text('2 esperando respuesta'), findsOneWidget);
      await tester.tap(find.text('Invitaciones pendientes'));
      await tester.pumpAndSettle();
      expect(find.text('Mia Laos'), findsOneWidget);
      expect(find.text('Juan Perez'), findsOneWidget);
    });

    testWidgets('si el servidor falla lo dice en vez de ocultarse',
        (tester) async {
      await _pump(tester, _FailingApi(), const PendingInvitationsEntry(groupId: 10));

      expect(find.text('No se pudieron cargar'), findsOneWidget);
    });
  });

  test('lee la invitacion que manda el backend', () {
    final invitation = GroupInvitation.fromJson({
      'id': 3,
      'groupId': 10,
      'groupName': 'Depa',
      'invitedUsername': 'mialaos',
      'invitedByUsername': 'admin',
      'invitedByFullName': '',
      // Asi lo manda el backend: con el desfase del servidor.
      'expiresAt': '2026-10-03T10:00:00-05:00',
    });
    expect(invitation.id, 3);
    // Sin nombre completo se muestra el usuario.
    expect(invitation.invitedByLabel, '@admin');
    expect(invitation.expiresAt!.toUtc(), DateTime.utc(2026, 10, 3, 15));

    expect(
      InvitationCandidate.fromJson({'availability': 'RECENTLY_REJECTED'})
          .availability,
      InvitationAvailability.recentlyRejected,
    );
  });
}
