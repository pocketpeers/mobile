import 'package:flutter/material.dart';

import 'app_motion.dart';
import 'app_theme.dart';

/// Marcador de posicion que late mientras el contenido carga.
///
/// Sustituye a las barras de progreso apiladas. Una barra dice "espera" pero no
/// dice cuanto ni que viene; un esqueleto con la forma del contenido real deja
/// la pantalla quieta y hace que la llegada de los datos se sienta como un
/// relleno y no como un salto, porque nada cambia de tamano ni se recoloca.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    this.width,
    this.height = 14,
    this.radius = 8,
    super.key,
  });

  /// Nulo significa ocupar todo el ancho disponible.
  final double? width;
  final double height;
  final double radius;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Con animaciones reducidas se queda en un gris fijo. El latido es
    // decorativo: quitarlo no le resta informacion a nadie, y mantenerlo si
    // molesta a quien pidio que el sistema no se mueva.
    final still = animationsDisabled(context);
    final base = context.primaryIconContainerColor;

    final box = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    );

    if (still) return box;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Opacity(
        opacity: 0.45 + (_controller.value * 0.35),
        child: child,
      ),
      child: box,
    );
  }
}

/// Bloque con forma de tarjeta: un titulo y unas cuantas lineas.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({this.lines = 3, this.height, super.key});

  final int lines;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppSkeleton(width: 160, height: 18),
            const SizedBox(height: 14),
            for (var i = 0; i < lines; i++) ...[
              // La ultima linea mas corta, como termina un parrafo de verdad.
              AppSkeleton(width: i == lines - 1 ? 120 : null),
              if (i != lines - 1) const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bloque con forma del resumen del grupo: la rosca y sus cifras al lado.
class SkeletonSummaryCard extends StatelessWidget {
  const SkeletonSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppSkeleton(width: 140, height: 18),
            const SizedBox(height: 18),
            Row(
              children: [
                const AppSkeleton(width: 108, height: 108, radius: 999),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      AppSkeleton(height: 12),
                      SizedBox(height: 12),
                      AppSkeleton(height: 12),
                      SizedBox(height: 12),
                      AppSkeleton(width: 90, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Filas con avatar y dos lineas, para listas de personas.
class SkeletonList extends StatelessWidget {
  const SkeletonList({this.rows = 3, super.key});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < rows; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == rows - 1 ? 0 : 14),
            child: Row(
              children: [
                const AppSkeleton(width: 40, height: 40, radius: 999),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      AppSkeleton(height: 12),
                      SizedBox(height: 8),
                      AppSkeleton(width: 90, height: 10),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Bloque con forma de tarjeta con grafico: un titulo y el area del dibujo.
///
/// La altura se pasa porque cada grafico reserva la suya —160 la evolucion del
/// score, 220 el de barras y el de torta— y es justo esa reserva la que evita
/// que el resto de la pantalla salte cuando fl_chart termina de pintar.
class SkeletonChartCard extends StatelessWidget {
  const SkeletonChartCard({this.height = 220, super.key});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppSkeleton(width: 150, height: 18),
            const SizedBox(height: 16),
            AppSkeleton(height: height, radius: 12),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta con titulo y filas de avatar: listas de pagos o de transacciones.
///
/// Es [SkeletonList] dentro de una tarjeta. Las listas del grupo ya viven en
/// una tarjeta de seccion que pone el marco; en Home y en Reportes la tarjeta
/// es parte de la lista misma, asi que va aqui.
class SkeletonListCard extends StatelessWidget {
  const SkeletonListCard({this.rows = 3, super.key});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppSkeleton(width: 170, height: 18),
            const SizedBox(height: 16),
            SkeletonList(rows: rows),
          ],
        ),
      ),
    );
  }
}
