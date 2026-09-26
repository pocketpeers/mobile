import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/reputation_event_text.dart';
import '../../core/app_motion.dart';
import '../../core/app_theme.dart';
import '../../core/metric_card_extent.dart';
import '../../core/blockchain_hash_chip.dart';
import '../../core/formatters.dart';
import '../../core/skeleton.dart';
import '../../data/models.dart';
import 'dashboard_cards.dart';
import '../../state/providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardSummaryProvider);
    final reputation = ref.watch(myReputationProvider);
    final history = ref.watch(myReputationHistoryProvider);
    final scoreSeries = ref.watch(myScoreSeriesProvider);
    return Scaffold(
      // Home era la unica pestana sin AppBar: Grupos, Reportes y Ajustes ya
      // tenian la suya. Ponersela alinea la navegacion y libera el encabezado
      // degradado, que estaba cargando el titulo y el acceso a notificaciones
      // ademas del balance y el score.
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Home'),
        actions: [
          _NotificationBell(
            unread: ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0,
          ),
        ],
      ),
      body: summary.when(
        loading: () => const _DashboardSkeleton(),
        error: (error, stackTrace) => ErrorView(
          title: 'No se pudo cargar el dashboard',
          onRetry: () => ref.invalidate(dashboardSummaryProvider),
        ),
        data: (data) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardSummaryProvider);
          ref.invalidate(myReputationProvider);
          ref.invalidate(myReputationHistoryProvider);
          ref.invalidate(myScoreSeriesProvider);
          ref.invalidate(myBadgesProvider);
          ref.invalidate(unreadNotificationCountProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Orden por urgencia: primero cuanto tienes, luego que debes hacer,
            // despues como vas, y al final el detalle historico.
            AnimatedSection(
              child: _DashboardHeader(summary: data),
            ),
            const SizedBox(height: 16),
            AnimatedSection(
              index: 1,
              child: UpcomingPaymentsCard(upcoming: data.upcoming),
            ),
            const SizedBox(height: 16),
            AnimatedSection(
              index: 2,
              child: ScoreCard(
                reputation: reputation.valueOrNull,
                fallbackScore: data.score,
              ),
            ),
            const SizedBox(height: 16),
            AnimatedSection(index: 3, child: _MetricGrid(summary: data)),
            const SizedBox(height: 16),
            AnimatedSection(
              index: 4,
              child: _ReputationHistoryCard(
                series: scoreSeries.valueOrNull ?? const [],
                events: history.valueOrNull ?? const [],
              ),
            ),
            const SizedBox(height: 16),
            AnimatedSection(index: 5, child: _MonthlyChart(summary: data)),
            const SizedBox(height: 16),
            AnimatedSection(
              index: 6,
              child: _RecentTransactions(payments: data.recentPayments),
            ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Home mientras llega el resumen.
///
/// Repite el orden y las medidas de la lista con datos —encabezado, vence
/// pronto, score, las tres metricas, los dos graficos y las transacciones— para
/// que al llegar el resumen cada bloque se rellene donde ya estaba, en vez de
/// aparecer de golpe empujando al resto.
class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        // El encabezado no es una tarjeta sino el bloque degradado, asi que va
        // suelto y con su mismo radio.
        AppSkeleton(height: 126, radius: 8),
        SizedBox(height: 16),
        SkeletonCard(lines: 3),
        SizedBox(height: 16),
        SkeletonCard(lines: 2),
        SizedBox(height: 16),
        _SkeletonMetricGrid(),
        SizedBox(height: 16),
        SkeletonChartCard(height: 160),
        SizedBox(height: 16),
        SkeletonChartCard(),
        SizedBox(height: 16),
        SkeletonListCard(),
      ],
    );
  }
}

/// Las tres metricas de dinero, con la rejilla exacta de [_MetricGrid].
class _SkeletonMetricGrid extends StatelessWidget {
  const _SkeletonMetricGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      // Altura segun el texto, no segun el ancho. Ver metricCardExtent.
      mainAxisExtent: metricCardExtent(context, labelLines: 2),
      children: const [
        _SkeletonMetricCard(),
        _SkeletonMetricCard(),
        _SkeletonMetricCard(),
      ],
    );
  }
}

class _SkeletonMetricCard extends StatelessWidget {
  const _SkeletonMetricCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                AppSkeleton(width: 32, height: 32, radius: 8),
                SizedBox(width: 8),
                Expanded(child: AppSkeleton(height: 10)),
              ],
            ),
            AppSkeleton(width: 56, height: 16),
          ],
        ),
      ),
    );
  }
}

/// Encabezado del panel: solo el balance.
///
/// El circulo del score salio de aqui. Repetia el numero que la tarjeta de
/// reputacion muestra completo, y competia con el balance por la atencion en la
/// primera pantalla.
class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy, AppColors.blue],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Balance',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white.withOpacity(0.72),
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  formatCurrency(summary.balance),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Balance actual entre cobros y deudas',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.82),
                      ),
                ),
              ],
            ),
          ),
          Icon(
            summary.balance >= 0
                ? Icons.trending_up_outlined
                : Icons.trending_down_outlined,
            size: 40,
            color: Colors.white.withOpacity(0.55),
          ),
        ],
      ),
    );
  }
}

/// Acceso a las notificaciones, con el contador de no leidas.
///
/// Vive en la barra superior y no en una tarjeta del panel: es un acceso, no
/// contenido. Ocupar una seccion entera para tres titulos desplazaba hacia abajo
/// lo que la persona viene a ver.
class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.unread});

  final int unread;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => context.push('/notifications'),
      tooltip: unread > 0
          ? '$unread notificaciones sin leer'
          : 'Notificaciones',
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_outlined),
          if (unread > 0)
            Positioned(
              right: -3,
              top: -3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error,
                  borderRadius: BorderRadius.circular(99),
                  // El borde separa el contador del icono. Toma el color del
                  // fondo de la barra para que funcione en tema claro y oscuro.
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  unread > 9 ? '9+' : '$unread',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    // Tres metricas, no siete. Salieron Balance, que ya esta en el encabezado,
    // y Score, Nivel, Racha y Siguiente nivel, que ahora viven juntos en la
    // tarjeta de reputacion. Lo que queda son las tres cifras de dinero que no
    // se repiten en ningun otro lado.
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      // Altura segun el texto, no segun el ancho. Ver metricCardExtent.
      mainAxisExtent: metricCardExtent(context, labelLines: 2),
      children: [
        MetricCard(
          label: 'Gastos',
          value: formatCurrency(summary.totalExpenses),
          icon: Icons.receipt_long_outlined,
        ),
        MetricCard(
          label: 'Pagado',
          value: formatCurrency(summary.totalPaid),
          icon: Icons.check_circle_outline,
        ),
        MetricCard(
          label: 'Pendiente',
          value: formatCurrency(summary.totalPending),
          icon: Icons.schedule_outlined,
        ),
      ],
    );
  }
}
/// Evolucion del score, con la banda de confianza detras.
///
/// La linea son cortes de tiempo que el backend recalcula con la evidencia que
/// existia en cada momento, no el `resultingScore` guardado en cada evento. Ese
/// campo pertenece al contador PBL anterior, que arrancaba en cero y sumaba
/// puntos fijos; graficarlo mientras la tarjeta de arriba muestra PeerScore
/// contaba dos historias distintas del mismo historial, y la persona no tenia
/// forma de saber cual de las dos era la suya.
///
/// La banda va dibujada y no solo el numero porque el score es una estimacion:
/// una linea sola afirmaria una precision que el motor no tiene, sobre todo al
/// principio, cuando casi todo el valor viene del prior y no de lo que la
/// persona hizo.
class _ReputationHistoryCard extends ConsumerWidget {
  const _ReputationHistoryCard({required this.series, required this.events});

  final List<ScoreSeriesPoint> series;
  final List<ReputationEvent> events;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(scoreRangeDaysProvider);
    // El evento solo trae el id del grupo; el nombre sale de la lista que ya
    // esta cargada para el resto de la app.
    final groupNames = {
      for (final group in ref.watch(groupsProvider).valueOrNull ?? const [])
        group.id: group.name,
    };
    // El historial llega del mas antiguo al mas reciente. Lo ultimo que hizo la
    // persona esta al final, no al principio: leer los tres primeros mostraba
    // los tres eventos mas viejos de la ventana de noventa dias.
    final recent = events.reversed.take(3).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Evolucion del score',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            // Debajo del titulo y no a su lado: en un telefono de 360 px los
            // dos juntos no entran sin partir el titulo en dos lineas.
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 30, label: Text('Ultimo mes')),
                ButtonSegment(value: 90, label: Text('3 meses')),
              ],
              selected: {days},
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onSelectionChanged: (value) =>
                  ref.read(scoreRangeDaysProvider.notifier).state = value.first,
            ),
            if (series.length >= 2) ...[
              const SizedBox(height: 2),
              Text(
                'La franja es el margen de confianza: se angosta a medida que el '
                'sistema te conoce.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: context.mutedIconColor),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: series.length < 2
                  ? const _DashboardEmptyState(
                      icon: Icons.trending_up_outlined,
                      title: 'Sin evolucion todavia',
                      message:
                          'Tu score se construira con tus primeras transacciones.',
                    )
                  : _ScoreSeriesChart(series: series),
            ),
            if (recent.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final event in recent)
                // La fecha y el efecto, y no el `pointsDelta`. Ese numero es el
                // del motor anterior: mostrar un «+3» al lado de una linea que
                // en ese momento subio 4.7 invita a sumar puntos que no existen.
                _ReputationEventTile(
                  event: event,
                  groupName: groupNames[event.groupId],
                ),
            ],
          ],
        ),
      ),
    );
  }

}

/// Un evento del historial: que paso, donde y que le hizo al score.
class _ReputationEventTile extends StatelessWidget {
  const _ReputationEventTile({required this.event, this.groupName});

  final ReputationEvent event;
  final String? groupName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = describeReputationEvent(event);
    final (icon, color, container) = switch (text.effect) {
      ScoreEffect.up => (
          Icons.trending_up,
          context.successIconColor,
          context.successIconContainerColor,
        ),
      ScoreEffect.down => (
          Icons.trending_down,
          context.dangerIconColor,
          context.dangerIconContainerColor,
        ),
      ScoreEffect.partial => (
          Icons.trending_flat,
          context.warningIconColor,
          context.warningIconContainerColor,
        ),
      // Sin flecha: una flecha, aunque sea gris, se lee como que algo se movio.
      ScoreEffect.none => (
          Icons.emoji_events_outlined,
          context.mutedIconColor,
          context.mutedIconContainerColor,
        ),
    };
    final place = [
      if (groupName != null && groupName!.trim().isNotEmpty) groupName!.trim(),
      formatDate(event.occurredAt),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: container, shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text.title,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  text.effectLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    // El gris del "no cambia" es el mismo del lugar y la fecha:
                    // solo se colorea lo que de verdad movio el score.
                    color: text.effect == ScoreEffect.none
                        ? context.mutedIconColor
                        : color,
                    fontWeight: text.effect == ScoreEffect.none
                        ? null
                        : FontWeight.w600,
                  ),
                ),
                Text(
                  place,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: context.mutedIconColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreSeriesChart extends StatelessWidget {
  const _ScoreSeriesChart({required this.series});

  final List<ScoreSeriesPoint> series;

  @override
  Widget build(BuildContext context) {
    final line = context.successIconColor;

    // El eje no se fija en 0-100: con scores tipicos entre 45 y 75 toda la
    // variacion quedaria aplastada contra el centro. Se encuadra la banda con un
    // margen, acotado al rango valido del score.
    var low = series.first.bandLow;
    var high = series.first.bandHigh;
    for (final point in series) {
      if (point.bandLow < low) low = point.bandLow;
      if (point.bandHigh > high) high = point.bandHigh;
    }
    final margin = ((high - low) * 0.1).clamp(2.0, 10.0);
    final minY = (low - margin).clamp(0.0, 100.0);
    final maxY = (high + margin).clamp(0.0, 100.0);

    List<FlSpot> spotsOf(double Function(ScoreSeriesPoint) value) => [
          for (var i = 0; i < series.length; i++)
            FlSpot(i.toDouble(), value(series[i])),
        ];

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              // Solo los extremos: con doce cortes, etiquetar todos deja un
              // amasijo de fechas superpuestas en el ancho de un telefono.
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if (index != 0 && index != series.length - 1) {
                  return const SizedBox.shrink();
                }
                final at = series[index].at;
                if (at == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    shortDayMonthFormatter.format(at),
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: context.mutedIconColor),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            // Solo la linea del score lleva etiqueta. Los bordes de la banda son
            // las barras 0 y 1, y anotarlos repetiria tres veces el mismo toque.
            getTooltipItems: (spots) => [
              for (final spot in spots)
                if (spot.barIndex == 2)
                  LineTooltipItem(
                    '${spot.y.round()}  ·  ${series[spot.x.round()].levelName}',
                    TextStyle(
                      color: line,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  )
                else
                  null,
            ],
          ),
        ),
        lineBarsData: [
          // Los dos bordes de la banda, invisibles: fl_chart expresa un area
          // sombreada como el relleno entre dos series, asi que tienen que
          // existir como barras aunque no se dibujen.
          LineChartBarData(
            spots: spotsOf((point) => point.bandLow),
            color: Colors.transparent,
            barWidth: 0,
            dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: spotsOf((point) => point.bandHigh),
            color: Colors.transparent,
            barWidth: 0,
            dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: spotsOf((point) => point.score),
            color: line,
            barWidth: 3,
            isCurved: true,
            // Sin esto la curva puede sobrepasar los puntos y dibujar un score
            // mayor al que el motor calculo.
            preventCurveOverShooting: true,
            dotData: FlDotData(show: series.length <= 14),
          ),
        ],
        betweenBarsData: [
          BetweenBarsData(
            fromIndex: 0,
            toIndex: 1,
            color: line.withOpacity(0.14),
          ),
        ],
      ),
    );
  }
}

class _MonthlyChart extends StatelessWidget {
  const _MonthlyChart({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final entries = summary.monthlyExpenses.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gastos mensuales',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            if (entries.isEmpty)
              const _DashboardEmptyState(
                icon: Icons.bar_chart_outlined,
                title: 'Sin gastos registrados',
                message:
                    'Cuando crees gastos, aqui veras la actividad mensual.',
              )
            else
              SizedBox(
                height: 220,
                child: BarChart(
                  BarChartData(
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= entries.length) {
                              return const SizedBox.shrink();
                            }
                            return Text(entries[index].key.substring(5));
                          },
                        ),
                      ),
                    ),
                    barGroups: [
                      for (var i = 0; i < entries.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: entries[i].value,
                              color: i.isEven
                                  ? context.primaryIconColor
                                  : context.successIconColor,
                              width: 18,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RecentTransactions extends StatelessWidget {
  const _RecentTransactions({required this.payments});

  final List<Payment> payments;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Transacciones recientes',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (payments.isEmpty)
              const _DashboardEmptyState(
                icon: Icons.swap_horiz_outlined,
                title: 'Sin transacciones',
                message: 'Tus pagos y cobros recientes apareceran aqui.',
              )
            else
              for (final payment in payments)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: context.primaryIconContainerColor,
                    foregroundColor: context.primaryIconColor,
                    child: const Icon(Icons.receipt_long_outlined),
                  ),
                  title: Text(payment.description),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(payment.confirmed
                          ? payment.status
                          : '${payment.status} - sin confirmar'),
                      // La fecha del pago, que no es la del anclaje: esa va
                      // debajo del hash. Aqui interesa cuando ocurrio la
                      // operacion; alli, cuando quedo probada.
                      if (payment.createdAt != null)
                        Text(
                          formatDateTime(payment.createdAt),
                          style: TextStyle(
                              fontSize: 12, color: context.mutedIconColor),
                        ),
                      const SizedBox(height: 6),
                      BlockchainHashChip(
                        hash: payment.blockchainHash,
                        anchoredAt: payment.anchoredAt,
                        compact: true,
                      ),
                    ],
                  ),
                  trailing: Text(formatCurrency(
                      payment.confirmed ? payment.amountPaid : 0)),
                  onTap: () => context.push('/payments/${payment.id}'),
                ),
          ],
        ),
      ),
    );
  }
}

class _DashboardEmptyState extends StatelessWidget {
  const _DashboardEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.primaryIconContainerColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.primaryIconColor.withOpacity(0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PulseIcon(icon: icon, color: context.primaryIconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(message),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    required this.label,
    required this.value,
    this.icon,
    super.key,
  });

  final String label;
  final String value;
  final IconData? icon;

  static const _iconSize = 32.0;
  static const _stackedIconSize = 24.0;
  static const _iconGap = 8.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          color: isDark
              ? Colors.white.withOpacity(0.66)
              : AppColors.navy.withOpacity(0.66),
        );
    final valueText = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        value,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: isDark ? Colors.white : AppColors.navy,
              fontWeight: FontWeight.w900,
            ),
      ),
    );

    return Card(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // En tres columnas sobre un telefono la tarjeta mide unos 100 px, y
          // con el icono al lado a la etiqueta le quedaban menos de 30: Flutter
          // partia la palabra por la mitad («Gasto/s», «Pendi/ente»). Si alguna
          // palabra de la etiqueta no entra junto al icono, el icono sube y la
          // etiqueta va debajo, en una sola linea. Si todas entran, se queda al
          // lado y puede partirse en dos lineas por los espacios.
          final stacked = icon != null &&
              _longestWordWidth(context, labelStyle) >
                  constraints.maxWidth - 32 - _iconSize - _iconGap;
          return Padding(
            // Apilado se come un poco del relleno vertical para que el icono
            // quepa en el mismo alto que metricCardExtent reserva para dos
            // lineas de etiqueta.
            padding: stacked
                ? const EdgeInsets.fromLTRB(12, 12, 12, 12)
                : const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: stacked
                  ? [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _icon(context, _stackedIconSize),
                          const SizedBox(height: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(label, maxLines: 1, style: labelStyle),
                          ),
                        ],
                      ),
                      valueText,
                    ]
                  : [
                      Row(
                        children: [
                          if (icon != null) _icon(context, _iconSize),
                          if (icon != null) const SizedBox(width: _iconGap),
                          Expanded(
                            child: Text(
                              label,
                              // Tope de dos lineas: sin el, una etiqueta larga
                              // sin icono se parte en tres y la tarjeta desborda.
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: labelStyle,
                            ),
                          ),
                        ],
                      ),
                      valueText,
                    ],
            ),
          );
        },
      ),
    );
  }

  Widget _icon(BuildContext context, double size) {
    return SizedBox(
      width: size,
      height: size,
      child: FittedBox(
        child: PulseIcon(icon: icon!, color: context.successIconColor),
      ),
    );
  }

  /// Ancho de la palabra mas larga de la etiqueta, con el tamaño de letra activo.
  double _longestWordWidth(BuildContext context, TextStyle? style) {
    var widest = 0.0;
    for (final word in label.split(' ')) {
      final painter = TextPainter(
        text: TextSpan(text: word, style: style),
        maxLines: 1,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      if (painter.width > widest) widest = painter.width;
      painter.dispose();
    }
    return widest;
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({required this.title, required this.onRetry, super.key});

  final String title;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
