import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketpeers/src/core/crew.dart';

List<String> assetsOf(WidgetTester tester) => tester
    .widgetList<Image>(find.byType(Image))
    .map((image) => (image.image as AssetImage).assetName)
    .toList();

Future<void> pumpIn(
  WidgetTester tester,
  Widget child, {
  bool disableAnimations = false,
}) {
  return tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
}

void main() {
  testWidgets('jump: 4,5,4,5,4,5 y aterriza en 0', (tester) async {
    await pumpIn(
      tester,
      const CrewCelebration.jumping(member: CrewMember.salvador),
    );

    final seen = <String>[assetsOf(tester).single];
    for (var i = 0; i < 7; i++) {
      await tester.pump(const Duration(milliseconds: 180));
      seen.add(assetsOf(tester).single);
    }
    expect(
      seen.map((a) => a.split('_').last.split('.').first).toList(),
      ['4', '5', '4', '5', '4', '5', '0', '0'],
    );
    expect(seen.first, 'assets/images/crew/happy_salvador_4.png');
  });

  testWidgets('cheer: sube 0,1,2,3 y descansa en 0', (tester) async {
    await pumpIn(
      tester,
      const CrewCelebration.cheering(member: CrewMember.ariana),
    );

    final seen = <String>[assetsOf(tester).single];
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      seen.add(assetsOf(tester).single);
    }
    expect(
      seen.map((a) => a.split('_').last.split('.').first).toList(),
      ['0', '1', '2', '3', '2', '3', '1', '0', '0'],
    );
    expect(seen.first, 'assets/images/crew/happy_ariana_0.png');
  });

  testWidgets('duo festejando usa los dos personajes felices', (tester) async {
    await pumpIn(tester, const CrewDuo(clip: CrewClip.cheer));
    expect(assetsOf(tester), [
      'assets/images/crew/happy_ariana_0.png',
      'assets/images/crew/happy_salvador_0.png',
    ]);
  });

  testWidgets('hablar sigue igual: saluda con el 2', (tester) async {
    await pumpIn(
      tester,
      const CrewSpeaker(member: CrewMember.salvador, message: 'hola'),
    );
    expect(assetsOf(tester).single, 'assets/images/crew/salvador_2.png');
    await tester.pump(const Duration(milliseconds: 240));
    expect(assetsOf(tester).single, 'assets/images/crew/salvador_1.png');
  });

  testWidgets('con animaciones reducidas se queda en reposo', (tester) async {
    await pumpIn(
      tester,
      const CrewCelebration.jumping(member: CrewMember.salvador),
      disableAnimations: true,
    );
    expect(assetsOf(tester).single, 'assets/images/crew/happy_salvador_0.png');
    await tester.pump(const Duration(milliseconds: 600));
    expect(assetsOf(tester).single, 'assets/images/crew/happy_salvador_0.png');
  });

  testWidgets('restartKey vuelve a lanzar el festejo', (tester) async {
    await pumpIn(
      tester,
      const CrewCelebration.cheering(member: CrewMember.salvador, restartKey: 1),
    );
    await tester.pump(const Duration(milliseconds: 2000));
    expect(assetsOf(tester).single, 'assets/images/crew/happy_salvador_0.png');

    await pumpIn(
      tester,
      const CrewCelebration.cheering(member: CrewMember.salvador, restartKey: 2),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(assetsOf(tester).single, 'assets/images/crew/happy_salvador_1.png');
  });
}
