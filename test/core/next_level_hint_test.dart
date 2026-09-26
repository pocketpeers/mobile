import 'package:flutter_test/flutter_test.dart';
import 'package:pocketpeers/src/core/next_level_hint.dart';
import 'package:pocketpeers/src/data/models.dart';

Reputation _reputation({
  int score = 50,
  String level = 'Nuevo',
  int pointsToNextLevel = 0,
  NextLevelGoal? nextLevel,
  bool peerScoreActive = true,
}) =>
    Reputation(
      userId: 1,
      score: score,
      level: level,
      levelDescription: '',
      pointsToNextLevel: pointsToNextLevel,
      onTimePaymentStreak: 0,
      completedPayments: 0,
      nextLevel: nextLevel,
      peerScoreActive: peerScoreActive,
    );

NextLevelGoal _goal({
  String levelName = 'Bronce',
  double missingScore = 0,
  double missingCounterparties = 0,
  bool bandTooWide = false,
}) =>
    NextLevelGoal(
      levelName: levelName,
      missingScore: missingScore,
      missingCounterparties: missingCounterparties,
      bandTooWide: bandTooWide,
    );

void main() {
  test('con 50 puntos en Nuevo no dice que llego al maximo', () {
    // El caso que motivo el cambio: el puntaje ya cubre Bronce y lo que falta
    // es cumplir con otra persona.
    final hint = nextLevelHint(_reputation(
      nextLevel: _goal(missingCounterparties: 0.6),
    ));
    expect(hint, 'Para llegar a Bronce te falta cumplir con 1 persona más del grupo');
  });

  test('junta puntos, personas e historial en una frase', () {
    final hint = nextLevelHint(_reputation(
      nextLevel: _goal(
        levelName: 'Plata',
        missingScore: 11.2,
        missingCounterparties: 1.4,
        bandTooWide: true,
      ),
    ));
    expect(
      hint,
      'Para llegar a Plata te faltan 12 puntos, cumplir con 2 personas más '
      'del grupo y más historial de pagos a tiempo',
    );
  });

  test('solo puntos', () {
    expect(
      nextLevelHint(_reputation(nextLevel: _goal(levelName: 'Oro', missingScore: 1))),
      'Para llegar a Oro te falta 1 punto',
    );
  });

  test('el nivel maximo solo se anuncia sin objetivo siguiente', () {
    expect(nextLevelHint(_reputation(score: 90, level: 'Oro')),
        'Alcanzaste el nivel más alto');
  });

  test('con el motor anterior se usan los puntos', () {
    expect(
      nextLevelHint(_reputation(pointsToNextLevel: 10, peerScoreActive: false)),
      'Te faltan 10 puntos para el siguiente nivel',
    );
    expect(nextLevelHint(_reputation(peerScoreActive: false)), isNull);
  });

  test('lee el objetivo que manda el backend', () {
    final reputation = Reputation.fromJson({
      'score': 71,
      'level': 'Nuevo',
      'peerScoreActive': true,
      'nextLevel': {
        'level': 'BRONZE',
        'levelName': 'Bronce',
        'missingScore': 0.0,
        'missingCounterparties': 1.0,
        'bandTooWide': false,
      },
    });
    expect(reputation.nextLevel?.levelName, 'Bronce');
    expect(reputation.nextLevel?.missingCounterparties, 1.0);
  });
}
