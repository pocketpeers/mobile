import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../core/crew.dart';

/// Estructura comun de los pasos del tutorial.
///
/// Mantiene el mismo encabezado en todos para que lo unico que cambie entre
/// pantallas sea aquello con lo que la persona interactua. Si cada paso se viera
/// distinto, cada uno costaria volver a leerlo entero.
class StepScaffold extends StatelessWidget {
  const StepScaffold({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.speaker,
    this.speech,
    this.footnote,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  /// Quien presenta el paso. Si es null, el paso va sin personaje.
  final CrewMember? speaker;

  /// Lo que dice. Reemplaza al subtitulo cuando hay orador.
  final String? speech;

  /// Aclaracion opcional al pie, para lo que no cabe en el subtitulo.
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: context.primaryIconContainerColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 24, color: context.primaryIconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (speaker != null && speech != null)
            CrewSpeaker(member: speaker!, message: speech!)
          else
            Text(
              subtitle,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(height: 1.5, color: context.mutedIconColor),
            ),
          const SizedBox(height: 24),
          child,
          if (footnote != null) ...[
            const SizedBox(height: 20),
            Text(
              footnote!,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: context.mutedIconColor, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}
