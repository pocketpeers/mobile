import 'package:flutter_test/flutter_test.dart';
import 'package:pocketpeers/src/features/onboarding/steps/score_step.dart';

/// El tutorial promete cómo se moverá el score de alguien que todavía no lo
/// tiene. Estas pruebas fijan esos números contra los del backend: si allá se
/// recalibra `ScoreParameters` y aquí no, lo que la persona aprendió deja de
/// describir lo que le pasa, que es el problema que esta pantalla ya tuvo una
/// vez con el contador PBL.
void main() {
  group('ScoreSimulation', () {
    test('empieza en 50, no en cero', () {
      // Cero es el score de quien incumplió siempre. Alguien nuevo no es eso:
      // es alguien de quien no se sabe nada, y eso son 50.
      expect(ScoreSimulation().score, closeTo(50.0, 0.001));
    });

    test('los primeros pagos mueven mucho y los siguientes cada vez menos', () {
      final simulation = ScoreSimulation();

      final first = simulation.apply(ScoreSimulation.puntual);
      final second = simulation.apply(ScoreSimulation.puntual);
      final third = simulation.apply(ScoreSimulation.puntual);

      // 100·3/5, 100·4/6, 100·5/7: el prior de peso 4 se va diluyendo.
      expect(simulation.score, closeTo(71.4286, 0.001));
      expect(first, greaterThan(second));
      expect(second, greaterThan(third));
    });

    test('un vencimiento resta, y la recuperación es posible', () {
      final simulation = ScoreSimulation();
      simulation.apply(ScoreSimulation.puntual);
      simulation.apply(ScoreSimulation.puntual);

      final penalty = simulation.apply(ScoreSimulation.vencido);
      expect(penalty, lessThan(0));

      // Que se pueda volver a subir no es un detalle: un score del que no se
      // sale castiga sin dar nada a cambio, y nadie cambia de conducta por eso.
      final recovery = simulation.apply(ScoreSimulation.puntual);
      expect(recovery, greaterThan(0));
    });

    test('nunca se sale del rango válido', () {
      final simulation = ScoreSimulation();
      for (var i = 0; i < 200; i++) {
        simulation.apply(ScoreSimulation.vencido);
      }
      expect(simulation.score, greaterThanOrEqualTo(0));

      for (var i = 0; i < 400; i++) {
        simulation.apply(ScoreSimulation.puntual);
      }
      expect(simulation.score, lessThanOrEqualTo(100));
    });

    test('reset vuelve al punto de partida, no a cero', () {
      final simulation = ScoreSimulation();
      simulation.apply(ScoreSimulation.vencido);
      simulation.apply(ScoreSimulation.vencido);

      simulation.reset();

      expect(simulation.score, closeTo(50.0, 0.001));
    });

    test('los parámetros son los que el backend aplica hoy', () {
      // Se afirman aquí a propósito. Son la única copia de estos valores fuera
      // de Java, y una prueba que los nombra es lo que convierte un cambio de
      // calibración en un fallo visible en vez de un desfase silencioso.
      expect(ScoreSimulation.priorStrength, 4.0);
      expect(ScoreSimulation.prior, 0.5);
      expect(ScoreSimulation.puntual, 1.0);
      expect(ScoreSimulation.vencido, 0.0);
    });
  });
}
