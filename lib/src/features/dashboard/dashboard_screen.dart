import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_motion.dart';
import '../../core/app_theme.dart';
import '../../core/blockchain_hash_chip.dart';
import '../../core/formatters.dart';
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => ErrorView(
          title: 'No se pudo cargar el dashboard',
          onRetry: () => ref.invalidate(dashboardSummaryProvider),
        ),
        data: (data) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardSummaryProvider);
          ref.invalidate(myReputationProvider);
          ref.invalidate(myReputationHistoryProvider);
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
      childAspectRatio: 1.05,
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
class _ReputationHistoryCard extends StatelessWidget {
  const _ReputationHistoryCard({required this.events});

  final List<ReputationEvent> events;

  @override
  Widget build(BuildContext context) {
    final chartEvents = events.take(12).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Evolucion del score',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: chartEvents.isEmpty
                  ? const _DashboardEmptyState(
                      icon: Icons.trending_up_outlined,
                      title: 'Sin evolucion todavia',
                      message:
                          'Tu score se construira con tus primeras transacciones.',
                    )
                  : LineChart(
                      LineChartData(
                        borderData: FlBorderData(show: false),
                        gridData: const FlGridData(show: true),
                        titlesData: const FlTitlesData(
                          topTitles: AxisTitles(),
                          rightTitles: AxisTitles(),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: [
                              for (var i = 0; i < chartEvents.length; i++)
                                FlSpot(i.toDouble(),
                                    chartEvents[i].resultingScore.toDouble()),
                            ],
                            color: context.successIconColor,
                            barWidth: 3,
                            dotData: const FlDotData(show: true),
                          ),
                        ],
                      ),
                    ),
            ),
            if (events.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final event in events.take(3))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    event.pointsDelta >= 0
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    color: event.pointsDelta >= 0
                        ? context.successIconColor
                        : Colors.redAccent,
                  ),
                  title: Text(event.description.isEmpty
                      ? event.type
                      : event.description),
                  trailing: Text(
                      '${event.pointsDelta >= 0 ? '+' : ''}${event.pointsDelta}'),
                ),
            ],
          ],
        ),
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
                      const SizedBox(height: 6),
                      BlockchainHashChip(
                        hash: payment.blockchainHash,
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                if (icon != null)
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: FittedBox(
                      child: PulseIcon(
                        icon: icon!,
                        color: context.successIconColor,
                      ),
                    ),
                  ),
                if (icon != null) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: isDark
                              ? Colors.white.withOpacity(0.66)
                              : AppColors.navy.withOpacity(0.66),
                        ),
                  ),
                ),
              ],
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: isDark ? Colors.white : AppColors.navy,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
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
