import 'package:flutter/material.dart';

import '../../../core/app_motion.dart';
import '../../../core/app_theme.dart';
import 'crew_speaker.dart';
import 'step_scaffold.dart';

/// Paso interactivo: cómo se mueve el score.
///
/// La persona toca «pagué a tiempo» o «me atrasé» y ve el número moverse con las
/// reglas reales de la aplicación. Aprende la mecánica en diez segundos, sin
/// tener que leer una tabla de puntajes que después nadie recuerda.
///
/// Los valores son los que aplica hoy el motor PBL del backend. Si el score pasa
/// a calcularse con PeerScore, este archivo es el único que hay que cambiar.
class ScoreStep extends StatefulWidget {
  const ScoreStep({super.key});

  @override
  State<ScoreStep> createState() => _ScoreStepState();
}

class _ScoreStepState extends State<ScoreStep> {
  static const _onTimePoints = 3;
  static const _overduePoints = -6;

  static const _levels = [
    _Level('Nuevo', 0),
    _Level('Bronce', 25),
    _Level('Plata', 60),
    _Level('Oro', 85),
  ];

  var _score = 0;
  String? _lastChange;

  @override
  Widget build(BuildContext context) {
    final level = _levelFor(_score);

    return StepScaffold(
      icon: Icons.trending_up_outlined,
      title: 'Tu score de confianza',
      subtitle:
          'Cada pago que registras mueve tu score. Pruébalo: toca los botones y '
          'mira qué pasa.',
      speaker: CrewMember.salvador,
      speech:
          'Cada pago que registras mueve tu score. Pruébalo: toca los botones y '
          'mira qué pasa.',
      footnote:
          'Los demás miembros de tus grupos pueden ver tu nivel. Es tu historial '
          'de cumplimiento, y se construye pagando a tiempo.',
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
                  tween: Tween(begin: 0, end: _score.toDouble()),
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
                  onPressed: () => _apply(_onTimePoints, 'Pagaste a tiempo'),
                  icon: const Icon(Icons.check_outlined, size: 18),
                  label: const Text('Pagué a tiempo'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _apply(_overduePoints, 'Se te venció un pago'),
                  icon: const Icon(Icons.schedule_outlined, size: 18),
                  label: const Text('Me atrasé'),
                ),
              ),
            ],
          ),
          if (_score > 0)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() {
                  _score = 0;
                  _lastChange = null;
                }),
                child: const Text('Empezar de nuevo'),
              ),
            ),
        ],
      ),
    );
  }

  void _apply(int delta, String reason) {
    setState(() {
      // El score real tambien queda acotado a este rango en el backend.
      _score = (_score + delta).clamp(0, 100);
      final sign = delta > 0 ? '+' : '';
      _lastChange = '$reason  ·  $sign$delta puntos';
    });
  }

  _Level _levelFor(int score) {
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

  final int score;
  final List<_Level> levels;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: score / 100),
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
