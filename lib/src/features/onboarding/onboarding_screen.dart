import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_motion.dart';
import '../../core/app_theme.dart';
import '../../core/crew.dart';
import '../../state/providers.dart';
import 'steps/split_step.dart';
import 'steps/score_step.dart';
import 'steps/blockchain_step.dart';

/// Tutorial de primera vez.
///
/// Reemplaza las tres laminas de texto que habia antes. La diferencia de fondo
/// es que aqui la persona toca cosas y ve el efecto: se aprende una mecanica
/// haciendola, no leyendo la regla que la describe.
///
/// Se reutiliza desde Ajustes con [voluntary] en true, y en ese caso no vuelve a
/// marcar el onboarding como completado.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({this.voluntary = false, super.key});

  final bool voluntary;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  var _index = 0;

  static const _stepCount = 5;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _stepCount - 1;

    return Scaffold(
      appBar: AppBar(
        // Retroceder paso a paso, no salir de golpe: quien quiere releer algo no
        // deberia tener que empezar de nuevo.
        leading: _index == 0
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _previous,
              ),
        title: Text(widget.voluntary ? 'Cómo funciona' : 'Bienvenido'),
        actions: [
          TextButton(
            onPressed: _finish,
            child: Text(widget.voluntary ? 'Cerrar' : 'Saltar'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _ProgressBar(index: _index, total: _stepCount),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (value) => setState(() => _index = value),
                children: [
                  const _WelcomeStep(),
                  const SplitStep(),
                  const ScoreStep(),
                  const BlockchainStep(),
                  // El festejo del ultimo paso arranca cuando se llega, no
                  // cuando el PageView construye la pagina por adelantado: si
                  // no, termina antes de que nadie la vea.
                  _FinishStep(active: isLast),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: isLast
                  ? _FinalActions(
                      onCreateGroup: _goToCreateGroup,
                      onExplore: _finish,
                    )
                  : FilledButton.icon(
                      onPressed: _next,
                      icon: const Icon(Icons.arrow_forward_outlined),
                      label: const Text('Siguiente'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _next() => _controller.nextPage(
        duration: AppMotion.medium,
        curve: AppMotion.curve,
      );

  void _previous() => _controller.previousPage(
        duration: AppMotion.medium,
        curve: AppMotion.curve,
      );

  Future<void> _markCompleted() async {
    if (!widget.voluntary) {
      await ref.read(authControllerProvider.notifier).completeOnboarding();
    }
  }

  Future<void> _finish() async {
    await _markCompleted();
    if (mounted) context.go('/dashboard');
  }

  /// El tutorial termina llevando a la primera accion real, no a un panel vacio.
  Future<void> _goToCreateGroup() async {
    await _markCompleted();
    if (mounted) context.go('/groups/new');
  }
}

/// Barra de avance en lugar de puntos.
///
/// Con cinco pasos, los puntos ya no comunican cuanto falta; una barra si.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.index, required this.total});

  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (index + 1) / total),
              duration: AppMotion.medium,
              curve: AppMotion.curve,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: Theme.of(context).dividerColor,
                valueColor:
                    AlwaysStoppedAnimation(context.successIconColor),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Paso ${index + 1} de $total',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: context.mutedIconColor),
          ),
        ],
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        children: [
          // Los personajes abren la pantalla en lugar del logo: la marca ya se
          // vio en el acceso, y aqui lo que se busca es que la primera impresion
          // sea de personas y no de producto.
          const CrewDuo(),
          const SizedBox(height: 20),
          Text(
            'Te damos la bienvenida a PocketPeers',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Text(
            'Aquí llevas la cuenta de lo que compartes con otros: quién puso '
            'qué, quién debe cuánto y quién ya pagó.',
            textAlign: TextAlign.center,
            style:
                Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: context.successIconContainerColor,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule_outlined,
                    size: 16, color: context.successIconColor),
                const SizedBox(width: 8),
                Text(
                  'Cuatro pasos, menos de un minuto',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.successIconColor,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
class _FinishStep extends StatelessWidget {
  const _FinishStep({required this.active});

  /// Si el paso esta a la vista. Ver [CrewDuo.restartKey].
  final bool active;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Cierra con los mismos dos que abrieron el tutorial, ahora
          // festejando. Antes habia un cohete: el unico paso que celebra algo
          // era justo el que no tenia a nadie celebrando.
          CrewDuo(clip: CrewClip.cheer, restartKey: active),
          const SizedBox(height: 24),
          Text(
            'Eso es todo',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Text(
            'Crea un grupo, invita a quienes comparten el gasto y registra el '
            'primero. El resto se explica solo.',
            textAlign: TextAlign.center,
            style:
                Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.primaryIconContainerColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.help_outline,
                    size: 20, color: context.primaryIconColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Puedes volver a ver esto cuando quieras desde Ajustes.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FinalActions extends StatelessWidget {
  const _FinalActions({required this.onCreateGroup, required this.onExplore});

  final VoidCallback onCreateGroup;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FilledButton.icon(
          onPressed: onCreateGroup,
          icon: const Icon(Icons.group_add_outlined),
          label: const Text('Crear mi primer grupo'),
        ),
        TextButton(
          onPressed: onExplore,
          child: const Text('Explorar por mi cuenta'),
        ),
      ],
    );
  }
}
