import '../../data/models.dart';

/// Cuánto le falta a una insignia bloqueada.
///
/// Es lo que convierte una insignia gris en una meta. «Racha de 3» a un pago de
/// distancia y «Racha de 100» a noventa y ocho se ven idénticas si solo se dice
/// que están bloqueadas.
class BadgeProgress {
  const BadgeProgress({
    required this.badge,
    required this.current,
    required this.target,
    required this.unit,
  });

  final PblBadge badge;

  /// Cuánto lleva la persona y cuánto necesita, en la unidad de la insignia.
  final int current;
  final int target;

  /// Qué se cuenta: pagos puntuales seguidos, pagos completados, puntos.
  final String unit;

  int get remaining => (target - current).clamp(0, target);

  double get fraction => target == 0 ? 0 : (current / target).clamp(0.0, 1.0);

  /// Frase para mostrar bajo la barra.
  String get label {
    if (remaining == 0) return 'Ya cumples la condición';
    if (remaining == 1) return 'Te falta 1 $unit';
    return 'Te faltan $remaining $unit';
  }
}

/// Calcula el progreso de las insignias que se pueden medir.
///
/// No todas se pueden: «Madrugador» depende de pagar con 48 horas de
/// anticipación y «Historial limpio» de cerrar el mes sin deudas. Esas no tienen
/// un contador que avance, así que devuelven null y se muestran solo con su
/// condición escrita. Inventarles una barra seria mentir sobre el avance.
///
/// Las cuatro insignias nuevas caen en el mismo grupo, por razones distintas.
/// «Con papel en mano» y «Palabra cumplida» se cuentan con eventos que este
/// modelo no trae. «Mes impecable» se resuelve sobre una ventana de treinta
/// días y no sobre un contador. Y «Segunda oportunidad» exige haberse atrasado
/// alguna vez: sin ese dato, mostrarle «te faltan 5 pagos puntuales» a quien
/// nunca cayó le prometería una insignia que no puede ganar.
BadgeProgress? progressFor(PblBadge badge, Reputation? reputation) {
  if (badge.unlocked || reputation == null) return null;

  final streak = reputation.onTimePaymentStreak;
  final completed = reputation.completedPayments;
  final score = reputation.score;

  switch (badge.code.toUpperCase()) {
    case 'FIRST_PAYMENT':
      return BadgeProgress(
        badge: badge,
        current: completed,
        target: 1,
        unit: 'pago',
      );
    case 'STREAK_3':
      return _streak(badge, streak, 3);
    case 'STREAK_10':
      return _streak(badge, streak, 10);
    case 'STREAK_50':
      return _streak(badge, streak, 50);
    case 'STREAK_100':
      return _streak(badge, streak, 100);
    case 'SILVER_LEVEL':
      return _level(badge, score, 60);
    case 'GOLD_LEVEL':
      return _level(badge, score, 85);
    default:
      return null;
  }
}

BadgeProgress _streak(PblBadge badge, int streak, int target) => BadgeProgress(
      badge: badge,
      current: streak,
      target: target,
      unit: target - streak == 1 ? 'pago puntual seguido' : 'pagos puntuales seguidos',
    );

BadgeProgress _level(PblBadge badge, int score, int target) => BadgeProgress(
      badge: badge,
      current: score,
      target: target,
      unit: target - score == 1 ? 'punto' : 'puntos',
    );

/// Las insignias repartidas en los tres grupos que muestra la pantalla.
class BadgeGroups {
  const BadgeGroups({
    required this.unlocked,
    required this.withinReach,
    required this.later,
  });

  final List<PblBadge> unlocked;

  /// Bloqueadas con progreso medible, de la más cercana a la más lejana.
  final List<BadgeProgress> withinReach;

  /// El resto: sin progreso medible o demasiado lejos.
  final List<PblBadge> later;

  /// Reparte el catálogo.
  ///
  /// «A tu alcance» se limita a unas pocas a proposito. Si entraran todas las
  /// medibles, «Racha de 100» apareceria junto a «Racha de 3» y el grupo dejaria
  /// de significar algo.
  static BadgeGroups from(
    List<PblBadge> badges,
    Reputation? reputation, {
    int reachLimit = 3,
  }) {
    final unlocked = badges.where((b) => b.unlocked).toList();
    final locked = badges.where((b) => !b.unlocked).toList();

    final measurable = <BadgeProgress>[];
    final unmeasurable = <PblBadge>[];
    for (final badge in locked) {
      final progress = progressFor(badge, reputation);
      if (progress == null) {
        unmeasurable.add(badge);
      } else {
        measurable.add(progress);
      }
    }

    // Por cuánto falta en términos absolutos, no por porcentaje: un pago de
    // distancia es alcanzable hoy, aunque en proporción se vea lejos.
    measurable.sort((a, b) => a.remaining.compareTo(b.remaining));

    final withinReach = measurable.take(reachLimit).toList();
    final later = <PblBadge>[
      ...measurable.skip(reachLimit).map((p) => p.badge),
      ...unmeasurable,
    ];

    return BadgeGroups(
      unlocked: unlocked,
      withinReach: withinReach,
      later: later,
    );
  }

  int get total => unlocked.length + withinReach.length + later.length;
}
