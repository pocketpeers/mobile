import 'dart:math' as math;

import '../data/models.dart';

/// Que le falta a la persona para subir de nivel, en una frase.
///
/// Antes se miraba solo `pointsToNextLevel`, que cuenta puntos y nada mas. El
/// nivel pide ademas cumplir con varias personas distintas, asi que alguien con
/// 50 puntos —ya por encima de los 25 de Bronce— tenia 0 puntos pendientes y la
/// app le decia «Alcanzaste el nivel más alto» sin haber salido de Nuevo.
///
/// Devuelve null si no hay nada que decir (motor anterior sin dato de puntos).
String? nextLevelHint(Reputation reputation) {
  final goal = reputation.nextLevel;
  if (goal != null) return _goalHint(goal);

  if (reputation.peerScoreActive) {
    // Con PeerScore, sin objetivo siguiente es que ya esta en el maximo.
    return 'Alcanzaste el nivel más alto';
  }
  // Motor anterior: el nivel si dependia solo de los puntos.
  if (reputation.pointsToNextLevel > 0) {
    return 'Te faltan ${reputation.pointsToNextLevel} puntos para el '
        'siguiente nivel';
  }
  return reputation.level == 'Oro' ? 'Alcanzaste el nivel más alto' : null;
}

String _goalHint(NextLevelGoal goal) {
  final level = goal.levelName.isEmpty ? 'el siguiente nivel' : goal.levelName;
  // Hacia arriba, igual que el backend con los puntos: si falta 0.3 de una
  // persona, falta una persona.
  final points = goal.missingScore.ceil();
  final people = goal.missingCounterparties > 0
      ? math.max(1, goal.missingCounterparties.ceil())
      : 0;

  final parts = <String>[
    if (points > 0) points == 1 ? '1 punto' : '$points puntos',
    if (people > 0)
      people == 1
          ? 'cumplir con 1 persona más del grupo'
          : 'cumplir con $people personas más del grupo',
    if (goal.bandTooWide) 'más historial de pagos a tiempo',
  ];
  if (parts.isEmpty) return 'Estás por llegar a $level';

  final verb = points > 1 ? 'te faltan' : 'te falta';
  return 'Para llegar a $level $verb ${_join(parts)}';
}

String _join(List<String> parts) {
  if (parts.length == 1) return parts.single;
  return '${parts.sublist(0, parts.length - 1).join(', ')} y ${parts.last}';
}
