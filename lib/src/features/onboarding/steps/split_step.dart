import 'package:flutter/material.dart';

import '../../../core/app_motion.dart';
import '../../../core/app_theme.dart';
import '../../../core/formatters.dart';
import 'crew_speaker.dart';
import 'step_scaffold.dart';

/// Paso interactivo: cómo se reparte un gasto.
///
/// La persona toca a los participantes y ve cambiar el monto de cada uno en el
/// momento. Es la mecánica central de la app y se entiende en cinco segundos
/// haciéndola, mientras que leerla en un párrafo no deja nada.
class SplitStep extends StatefulWidget {
  const SplitStep({super.key});

  @override
  State<SplitStep> createState() => _SplitStepState();
}

class _SplitStepState extends State<SplitStep> {
  static const _total = 60.0;
  static const _people = ['Tú', 'Ana', 'Luis', 'Rosa'];

  /// Siempre participas tú: por eso el primero arranca activo y no se puede
  /// desmarcar. Un gasto sin nadie no significa nada y dejarlo llegar a cero
  /// solo produce una división por cero que hay que explicar.
  final _selected = <int>{0, 1, 2};

  @override
  Widget build(BuildContext context) {
    final share = _total / _selected.length;

    return StepScaffold(
      icon: Icons.pie_chart_outline,
      title: 'Divide un gasto',
      subtitle:
          'Registras cuánto costó y entre quiénes va. Toca a las personas para '
          'ver cómo cambia lo que le toca a cada una.',
      speaker: CrewMember.ariana,
      speech:
          'Registras cuánto costó y entre quiénes va. Toca a las personas y mira '
          'cómo cambia lo que le toca a cada una.',
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.receipt_long_outlined,
                    color: context.primaryIconColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Almuerzo del sábado',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        'Grupo Casa',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: context.mutedIconColor),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatCurrency(_total),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < _people.length; i++)
                _PersonChip(
                  name: _people[i],
                  selected: _selected.contains(i),
                  locked: i == 0,
                  onTap: () => _toggle(i),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: context.successIconContainerColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  'A cada uno le toca',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: context.mutedIconColor),
                ),
                const SizedBox(height: 6),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: share, end: share),
                  duration: AppMotion.medium,
                  curve: AppMotion.curve,
                  builder: (context, value, _) => Text(
                    formatCurrency(value),
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: context.successIconColor,
                        ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'entre ${_selected.length} personas',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: context.mutedIconColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toggle(int index) {
    if (index == 0) return;
    setState(() {
      if (!_selected.remove(index)) _selected.add(index);
    });
  }
}

class _PersonChip extends StatelessWidget {
  const _PersonChip({
    required this.name,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? context.successIconColor : Theme.of(context).dividerColor;
    return InkWell(
      onTap: locked ? null : onTap,
      borderRadius: BorderRadius.circular(99),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? context.successIconContainerColor
              : Colors.transparent,
          border: Border.all(color: color, width: selected ? 1.6 : 1),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              size: 18,
              color: selected ? context.successIconColor : context.mutedIconColor,
            ),
            const SizedBox(width: 8),
            Text(
              name,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
