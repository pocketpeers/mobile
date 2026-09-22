import 'package:flutter/material.dart';

import '../../../core/app_motion.dart';
import '../../../core/app_theme.dart';
import '../../../core/crew.dart';
import 'step_scaffold.dart';

/// Paso interactivo: cómo se mueve el score.
///
/// La persona toca «pagué a tiempo» o «me atrasé» y ve el número moverse con las
/// reglas reales de la aplicación. Aprende la mecánica en diez segundos, sin
/// tener que leer una tabla de puntajes que después nadie recuerda.
///
/// Reproduce PeerScore, que es el motor que calcula el score que la persona verá
/// en su panel. Antes reproducía el contador PBL anterior —empezar en cero, +3
/// por pagar a tiempo, −6 por atrasarse— y eso enseñaba una mecánica que ya no
/// existe: quien terminaba el tutorial abría la app y encontraba un 50 que no
/// sabía de dónde salía.
///
/// La simulación es deliberadamente la parte del algoritmo que se puede enseñar
/// sin datos: el prior y la acumulación de evidencia. Quedan fuera el peso por
/// monto, el decaimiento y el tope por contraparte, que necesitan un historial
/// real. Por eso los botones no dicen montos ni fechas: prometen solo lo que la
/// simulación cumple.
///
/// Los parámetros son los de `ScoreParameters.defaults()` y `PaymentOutcome` en
/// el backend. Si allá se recalibran, aquí hay que seguirlos.
/// La parte de PeerScore que se puede enseñar sin datos.
///
/// Es una clase aparte y no estado del widget para poder probarla: los números
/// que ve alguien en su primer minuto con la app tienen que ser los mismos que
/// le dará el backend después, y eso es una aserción, no una intención.
class ScoreSimulation {
  ScoreSimulation()
      : _alpha = priorStrength * prior,
        _beta = priorStrength * (1 - prior);

  /// Peso del punto de partida, en cantidad equivalente de pagos.
  ///
  /// Es `priorStrength` de `ScoreParameters.defaults()`. Que valga 4 es lo que
  /// hace que los primeros pagos muevan mucho y los siguientes cada vez menos:
  /// son cuatro pagos imaginarios que la evidencia real tiene que ir
  /// desplazando.
  static const priorStrength = 4.0;

  /// De dónde arranca alguien de quien no se sabe nada.
  ///
  /// Es `peerscore.neutral-on-time-rate`. Ni premia ni castiga: 50 sobre 100.
  static const prior = 0.5;

  /// Cuánto cumplimiento acredita cada desenlace, de 0 a 1. Son los valores de
  /// `PaymentOutcome` en el backend.
  static const puntual = 1.0;
  static const vencido = 0.0;

  /// La evidencia acumulada, en los mismos términos que el backend: alfa es lo
  /// que respalda el cumplimiento y beta lo que respalda el incumplimiento.
  double _alpha;
  double _beta;

  /// El score no se guarda: se deriva de la proporción entre ambos. Guardarlo
  /// permitiría que quedara desincronizado de la evidencia que lo produjo, que
  /// es precisamente el error que este paso existe para no volver a enseñar.
  double get score => 100 * _alpha / (_alpha + _beta);

  /// Suma un desenlace y devuelve cuánto movió el score.
  ///
  /// El movimiento se calcula por diferencia y no se conoce de antemano: es
  /// exactamente lo contrario del contador anterior, donde el delta era el dato
  /// fijo y el score la consecuencia.
  double apply(double outcome) {
    final before = score;
    _alpha += outcome;
    _beta += 1 - outcome;
    return score - before;
  }

  /// Vuelve al punto de partida, que es 50 y no cero: cero sería el score de
  /// alguien que incumplió siempre, no el de alguien de quien no se sabe nada.
  void reset() {
    _alpha = priorStrength * prior;
    _beta = priorStrength * (1 - prior);
  }
}

class ScoreStep extends StatefulWidget {
  const ScoreStep({super.key});

  @override
  State<ScoreStep> createState() => _ScoreStepState();
}

class _ScoreStepState extends State<ScoreStep> {
  static const _levels = [
    _Level('Nuevo', 0),
    _Level('Bronce', 25),
    _Level('Plata', 60),
    _Level('Oro', 85),
  ];

  final _simulation = ScoreSimulation();

  String? _lastChange;

  double get _score => _simulation.score;

  @override
  Widget build(BuildContext context) {
    final level = _levelFor(_score);

    return StepScaffold(
      icon: Icons.trending_up_outlined,
      title: 'Tu score de confianza',
      subtitle:
          'Empiezas en 50: todavía no sabemos nada de ti. Cada pago que '
          'registras mueve el número. Pruébalo.',
      speaker: CrewMember.salvador,
      speech:
          'Empiezas en 50: todavía no sabemos nada de ti. Cada pago que '
          'registras mueve el número. Pruébalo.',
      footnote:
          'Los primeros pagos mueven mucho y los siguientes cada vez menos: el '
          'score se vuelve estable cuando ya hay historial. Para subir de nivel '
          'también necesitas cumplir con personas distintas.',
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: context.successIconContainerColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: _score),
                  duration: AppMotion.medium,
                  curve: AppMotion.curve,
                  builder: (context, value, _) => Text(
                    value.round().toString(),
                    style: Theme.of(context)
                        .textTheme
                        .displaySmall
                        ?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: context.successIconColor,
                        ),
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedSwitcher(
                  duration: AppMotion.fast,
                  child: Container(
                    key: ValueKey(level.name),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.successIconColor,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      'Nivel ${level.name}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _LevelBar(score: _score, levels: _levels),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 20,
            child: AnimatedSwitcher(
              duration: AppMotion.fast,
              child: _lastChange == null
                  ? const SizedBox.shrink()
                  : Text(
                      _lastChange!,
                      key: ValueKey(_lastChange),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.mutedIconColor,
                          ),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () =>
                      _apply(ScoreSimulation.puntual, 'Pagaste a tiempo'),
                  icon: const Icon(Icons.check_outlined, size: 18),
                  label: const Text('Pagué a tiempo'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _apply(ScoreSimulation.vencido, 'Se te venció un pago'),
                  icon: const Icon(Icons.schedule_outlined, size: 18),
                  label: const Text('Me atrasé'),
                ),
              ),
            ],
          ),
          if (_lastChange != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() {
                  _simulation.reset();
                  _lastChange = null;
                }),
                child: const Text('Empezar de nuevo'),
              ),
            ),
        ],
      ),
    );
  }

  void _apply(double outcome, String reason) {
    setState(() {
      final change = _simulation.apply(outcome);
      final sign = change >= 0 ? '+' : '−';
      _lastChange = '$reason  ·  $sign${change.abs().toStringAsFixed(1)}';
    });
  }

  _Level _levelFor(double score) {
    var current = _levels.first;
    for (final level in _levels) {
      if (score >= level.minimum) current = level;
    }
    return current;
  }
}

/// Barra con los umbrales marcados.
///
/// Ver dónde están Bronce, Plata y Oro convierte el número en una meta: sin las
/// marcas, un score de 30 no le dice nada a nadie.
class _LevelBar extends StatelessWidget {
  const _LevelBar({required this.score, required this.levels});

  final double score;
  final List<_Level> levels;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: (score / 100).clamp(0.0, 1.0)),
            duration: AppMotion.medium,
            curve: AppMotion.curve,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.35),
              valueColor: AlwaysStoppedAnimation(context.successIconColor),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final level in levels)
              Text(
                level.minimum == 0 ? level.name : '${level.name} ${level.minimum}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: score >= level.minimum
                          ? context.successIconColor
                          : context.mutedIconColor,
                      fontWeight: score >= level.minimum
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Level {
  const _Level(this.name, this.minimum);

  final String name;
  final int minimum;
}
