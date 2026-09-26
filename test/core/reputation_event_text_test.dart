import 'package:flutter_test/flutter_test.dart';
import 'package:pocketpeers/src/core/reputation_event_text.dart';
import 'package:pocketpeers/src/data/models.dart';

ReputationEvent _event(String type) => ReputationEvent(
      id: 1,
      userId: 1,
      groupId: 10,
      paymentId: 5,
      type: type,
      pointsDelta: 3,
      resultingScore: 0,
      description: 'Texto en ingles del backend',
    );

void main() {
  test('solo los desenlaces de pago mueven el score', () {
    // Los mismos cuatro que cuenta PaymentOutcome.fromEventType en el backend.
    expect(describeReputationEvent(_event('ON_TIME_PAYMENT')).effect,
        ScoreEffect.up);
    expect(describeReputationEvent(_event('PARTIAL_PAYMENT')).effect,
        ScoreEffect.partial);
    expect(describeReputationEvent(_event('LATE_PAYMENT')).effect,
        ScoreEffect.down);
    expect(describeReputationEvent(_event('OVERDUE_PAYMENT')).effect,
        ScoreEffect.down);
  });

  test('lo de quien crea el gasto no aparece como si subiera', () {
    for (final type in [
      'GROUP_CREATED',
      'RECEIPT_ATTACHED',
      'PAYMENT_CONFIRMED',
      'EARLY_PAYMENT',
      'JUST_IN_TIME_PAYMENT',
      'ZERO_DEBT',
      'MANUAL_ADJUSTMENT',
    ]) {
      final text = describeReputationEvent(_event(type));
      expect(text.effect, ScoreEffect.none, reason: type);
      expect(text.effectLabel, 'No cambia tu score · cuenta para insignias');
    }
  });

  test('nunca muestra el texto en ingles del backend', () {
    expect(describeReputationEvent(_event('RECEIPT_ATTACHED')).title,
        'Registraste un gasto con comprobante');
    expect(describeReputationEvent(_event('TIPO_NUEVO')).title,
        'Actividad en tus grupos');
  });
}
