import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardSummaryProvider);
    final reputation = ref.watch(myReputationProvider);
    final history = ref.watch(myReputationHistoryProvider);
    return summary.when(
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
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _DashboardHeader(summary: data, reputation: reputation.valueOrNull),
            const SizedBox(height: 16),
            _MetricGrid(summary: data, reputation: reputation.valueOrNull),
            const SizedBox(height: 16),
            _ReputationHistoryCard(events: history.valueOrNull ?? const []),
            const SizedBox(height: 16),
            _MonthlyChart(summary: data),
            const SizedBox(height: 16),
            _RecentTransactions(payments: data.recentPayments),
          ],
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.summary, required this.reputation});

  final DashboardSummary summary;
  final Reputation? reputation;

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
                  'Home',
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
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.green.withOpacity(0.22),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${reputation?.score ?? summary.score}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
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
  const _MetricGrid({required this.summary, required this.reputation});

  final DashboardSummary summary;
  final Reputation? reputation;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.65,
      children: [
        MetricCard(
          label: 'Balance',
          value: formatCurrency(summary.balance),
          icon: Icons.account_balance_wallet_outlined,
        ),
        MetricCard(
          label: 'Gastos',
          value: formatCurrency(summary.totalExpenses),
          icon: Icons.receipt_long_outlined,
        ),
        MetricCard(
          label: 'Pendiente',
          value: formatCurrency(summary.totalPending),
          icon: Icons.schedule_outlined,
        ),
        MetricCard(
          label: 'Score',
          value: '${reputation?.score ?? summary.score}/100',
          icon: Icons.trending_up_outlined,
        ),
        MetricCard(
          label: 'Nivel',
          value: reputation?.level ?? 'Nuevo',
          icon: Icons.workspace_premium_outlined,
        ),
        MetricCard(
          label: 'Racha',
          value: '${reputation?.onTimePaymentStreak ?? 0}',
          icon: Icons.local_fire_department_outlined,
        ),
        MetricCard(
          label: 'Siguiente nivel',
          value: '${reputation?.pointsToNextLevel ?? 0} pts',
          icon: Icons.flag_outlined,
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
            Text('Evolucion del score', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: chartEvents.isEmpty
                  ? const Center(child: Text('Tu score se construira con tus primeras transacciones'))
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
                                FlSpot(i.toDouble(), chartEvents[i].resultingScore.toDouble()),
                            ],
                            color: AppColors.green,
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
                    event.pointsDelta >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                    color: event.pointsDelta >= 0 ? AppColors.green : Colors.red,
                  ),
                  title: Text(event.description.isEmpty ? event.type : event.description),
                  trailing: Text('${event.pointsDelta >= 0 ? '+' : ''}${event.pointsDelta}'),
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
            Text('Gastos mensuales', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: entries.isEmpty
                  ? const Center(child: Text('Sin gastos registrados'))
                  : BarChart(
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
                                  color: i.isEven ? AppColors.blue : AppColors.green,
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
            Text('Transacciones recientes', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (payments.isEmpty)
              const ListTile(title: Text('Sin transacciones'))
            else
              for (final payment in payments)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.mist,
                    foregroundColor: AppColors.blue,
                    child: Icon(Icons.receipt_long_outlined),
                  ),
                  title: Text(payment.description),
                  subtitle: Text(payment.status),
                  trailing: Text(formatCurrency(payment.amountPaid)),
                  onTap: () => context.push('/payments/${payment.id}'),
                ),
          ],
        ),
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
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.green.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: isDark ? AppColors.lightGreen : AppColors.green,
                      size: 18,
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
