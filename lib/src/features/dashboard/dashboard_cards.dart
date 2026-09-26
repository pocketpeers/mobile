import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/next_level_hint.dart';
import '../../core/app_motion.dart';
import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../data/models.dart';

/// Lo que vence pronto.
///
/// Es la sección que le faltaba al panel. La app existe para que la persona no
/// se olvide de pagar, y el panel no decía en ninguna parte qué estaba por
/// vencer: eran seis tarjetas de cifras pasivas y ningún "haz esto".
class UpcomingPaymentsCard extends StatelessWidget {
  const UpcomingPaymentsCard({required this.upcoming, super.key});

  final List<UpcomingPayment> upcoming;

  /// Se muestran pocos y se deja el resto a la pantalla de pagos: un panel con
  /// quince vencimientos deja de ser un resumen.
  static const _maxVisible = 3;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final visible = upcoming.take(_maxVisible).toList();
    final overdueCount = upcoming.where((item) => item.isOverdue(now)).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  overdueCount > 0
                      ? Icons.warning_amber_outlined
                      : Icons.event_outlined,
                  size: 20,
                  color: overdueCount > 0
                      ? Theme.of(context).colorScheme.error
                      : context.primaryIconColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Vence pronto',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (visible.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 18, color: context.successIconColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No tienes pagos pendientes con fecha.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: context.mutedIconColor),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...visible.map((item) => _UpcomingRow(item: item, now: now)),
            if (upcoming.length > _maxVisible)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => context.push('/groups'),
                  child: Text('Ver los ${upcoming.length} pendientes'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.item, required this.now});

  final UpcomingPayment item;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final days = item.daysLeft(now);
    final overdue = days < 0;
    final urgent = days >= 0 && days <= 2;
    final color = overdue
        ? Theme.of(context).colorScheme.error
        : urgent
            ? context.primaryIconColor
            : context.mutedIconColor;

    return InkWell(
      onTap: () => context.push('/payments/${item.paymentId}'),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    _whenLabel(days),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: color,
                          fontWeight: overdue || urgent
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                  ),
                ],
              ),
            ),
            Text(
              formatCurrency(item.remaining),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  /// Texto relativo en lugar de una fecha.
  ///
  /// "En 2 días" se entiende sin calcular; "12/09" obliga a la persona a
  /// compararlo con el día de hoy antes de saber si es urgente.
  String _whenLabel(int days) {
    if (days < -1) return 'Venció hace ${-days} días';
    if (days == -1) return 'Venció ayer';
    if (days == 0) return 'Vence hoy';
    if (days == 1) return 'Vence mañana';
    if (days <= 7) return 'En $days días';
    return 'El ${DateFormat("d 'de' MMMM", 'es').format(
      DateTime.now().add(Duration(days: days)),
    )}';
  }
}

/// El score, en una sola tarjeta.
///
/// Antes estaba repartido en cuatro lugares: el circulo del encabezado y las
/// tarjetas de Score, Nivel y Siguiente nivel. Cuatro de las siete metricas del
/// panel decian lo mismo con distinto recorte.
class ScoreCard extends StatelessWidget {
  const ScoreCard({required this.reputation, required this.fallbackScore, super.key});

  final Reputation? reputation;
  final int fallbackScore;

  @override
  Widget build(BuildContext context) {
    final score = reputation?.score ?? fallbackScore;
    final level = reputation?.level ?? 'Nuevo';
    final hint = reputation == null ? null : nextLevelHint(reputation!);
    final streak = reputation?.onTimePaymentStreak ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: score.toDouble()),
                  duration: AppMotion.slow,
                  curve: AppMotion.curve,
                  builder: (context, value, _) => Text(
                    value.round().toString(),
                    style: Theme.of(context)
                        .textTheme
                        .displaySmall
                        ?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: context.successIconColor,
                          height: 1,
                        ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nivel $level',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        streak > 0
                            ? '$streak pagos puntuales seguidos'
                            : 'Tu historial de cumplimiento',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: context.mutedIconColor),
                      ),
                    ],
                  ),
                ),
                if (streak >= 3)
                  Icon(Icons.local_fire_department_outlined,
                      color: context.successIconColor),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: (score / 100).clamp(0.0, 1.0)),
                duration: AppMotion.slow,
                curve: AppMotion.curve,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: Theme.of(context).dividerColor,
                  valueColor:
                      AlwaysStoppedAnimation(context.successIconColor),
                ),
              ),
            ),
            if (hint != null) ...[
              const SizedBox(height: 8),
              Text(
                hint,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: context.mutedIconColor),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
