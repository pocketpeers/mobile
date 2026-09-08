import 'package:flutter/material.dart';

import '../../../core/app_motion.dart';
import '../../../core/app_theme.dart';
import '../../../core/crew.dart';
import 'step_scaffold.dart';

/// Paso interactivo: qué significa que el pago quede en blockchain.
///
/// La historia de usuario US-33 pide que el onboarding explique el score y el
/// blockchain «sin intimidar». Esta pantalla no existía: el tutorial anterior no
/// mencionaba la cadena en ninguna parte.
///
/// El enfoque es deliberado: no se explica qué es una blockchain, se explica qué
/// gana la persona. Para alguien que desconfía de lo digital, la palabra técnica
/// asusta y la garantía tranquiliza.
class BlockchainStep extends StatefulWidget {
  const BlockchainStep({super.key});

  @override
  State<BlockchainStep> createState() => _BlockchainStepState();
}

class _BlockchainStepState extends State<BlockchainStep> {
  var _sealed = false;

  @override
  Widget build(BuildContext context) {
    return StepScaffold(
      icon: Icons.verified_outlined,
      title: 'Queda registrado',
      subtitle:
          'Cuando confirmas un pago, queda guardado de una forma que nadie puede '
          'modificar después. Ni siquiera nosotros.',
      speaker: CrewMember.ariana,
      speech:
          'Cuando confirmas un pago queda guardado de una forma que nadie puede '
          'modificar después. Ni siquiera nosotros.',
      footnote: _sealed
          ? 'Ese código es la constancia de tu pago. Cualquiera puede verificarlo, '
              'pero nadie puede alterarlo ni borrarlo.'
          : null,
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _sealed = true),
            child: AnimatedContainer(
              duration: AppMotion.medium,
              curve: AppMotion.curve,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _sealed
                      ? context.successIconColor
                      : Theme.of(context).dividerColor,
                  width: _sealed ? 1.8 : 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.receipt_outlined,
                          color: context.primaryIconColor),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Pago confirmado · S/20',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      AnimatedScale(
                        scale: _sealed ? 1 : 0,
                        duration: AppMotion.medium,
                        curve: Curves.easeOutBack,
                        child: Icon(Icons.verified,
                            color: context.successIconColor),
                      ),
                    ],
                  ),
                  AnimatedCrossFade(
                    duration: AppMotion.medium,
                    crossFadeState: _sealed
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.touch_app_outlined,
                              size: 18, color: context.mutedIconColor),
                          const SizedBox(width: 8),
                          Text(
                            'Toca para sellarlo',
                            style: TextStyle(color: context.mutedIconColor),
                          ),
                        ],
                      ),
                    ),
                    secondChild: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: context.successIconContainerColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Constancia',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: context.mutedIconColor),
                            ),
                            const SizedBox(height: 2),
                            // Ejemplo ilustrativo: no corresponde a ninguna
                            // transaccion real.
                            const Text(
                              '3JYRN7...bZxRwbHdx',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _Point(
            icon: Icons.lock_outline,
            text: 'Nadie puede cambiar un pago después de registrado.',
          ),
          _Point(
            icon: Icons.visibility_outlined,
            text: 'Tú y tu grupo pueden revisar el historial cuando quieran.',
          ),
          _Point(
            icon: Icons.account_balance_outlined,
            text:
                'Con el tiempo, ese historial es la prueba de que cumples — algo '
                'que sirve fuera de la app.',
          ),
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: context.successIconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
