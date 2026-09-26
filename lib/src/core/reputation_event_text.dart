import '../data/models.dart';

/// Que le hizo un evento al score.
enum ScoreEffect {
  /// Pago puntual: empuja el score hacia arriba.
  up,

  /// Pago tardio o vencido: lo empuja hacia abajo.
  down,

  /// Pago parcial: cuenta como 60% cumplido, asi que sube o baja segun el
  /// score que ya se tenia.
  partial,

  /// No es evidencia de reputacion: solo cuenta para insignias.
  none,
}

class ReputationEventText {
  const ReputationEventText({
    required this.title,
    required this.effect,
    required this.effectLabel,
  });

  final String title;
  final ScoreEffect effect;
  final String effectLabel;
}

/// El evento en palabras, con lo que de verdad le hizo al score.
///
/// Antes se mostraba la descripcion que guarda el backend, que esta en ingles,
/// con una flecha verde hacia arriba para todo lo que no fuera un vencimiento.
/// Quien creaba un gasto veia «Expense registered with its supporting receipt»
/// con la flecha hacia arriba y su score quieto en 50: esos eventos solo
/// desbloquean insignias, y PeerScore no los cuenta (ver
/// `PaymentOutcome.fromEventType` en el backend).
ReputationEventText describeReputationEvent(ReputationEvent event) {
  switch (event.type) {
    case 'ON_TIME_PAYMENT':
      return const ReputationEventText(
        title: 'Pagaste a tiempo',
        effect: ScoreEffect.up,
        effectLabel: 'Sube tu score',
      );
    case 'PARTIAL_PAYMENT':
      return const ReputationEventText(
        title: 'Pagaste una parte a tiempo',
        effect: ScoreEffect.partial,
        effectLabel: 'Cuenta como cumplimiento parcial',
      );
    case 'LATE_PAYMENT':
      return const ReputationEventText(
        title: 'Pagaste despues del plazo',
        effect: ScoreEffect.down,
        effectLabel: 'Baja tu score',
      );
    case 'OVERDUE_PAYMENT':
      return const ReputationEventText(
        title: 'Se vencio un pago sin pagar',
        effect: ScoreEffect.down,
        effectLabel: 'Baja tu score',
      );
  }

  final title = switch (event.type) {
    'EARLY_PAYMENT' => 'Pagaste con mas de 2 dias de anticipacion',
    'JUST_IN_TIME_PAYMENT' => 'Pagaste en la ultima hora del plazo',
    'GROUP_CREATED' => 'Creaste un grupo',
    'RECEIPT_ATTACHED' => 'Registraste un gasto con comprobante',
    'PAYMENT_CONFIRMED' => 'Se confirmo tu pago',
    'ZERO_DEBT' => 'Cerraste el mes sin deudas',
    'MANUAL_ADJUSTMENT' => 'Ajuste manual',
    _ => 'Actividad en tus grupos',
  };
  return ReputationEventText(
    title: title,
    effect: ScoreEffect.none,
    effectLabel: 'No cambia tu score · cuenta para insignias',
  );
}
