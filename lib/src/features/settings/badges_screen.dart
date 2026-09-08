import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_motion.dart';
import '../../core/app_theme.dart';
import '../../core/badge_visuals.dart';
import '../../core/crew.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import 'badge_progress.dart';

/// Las insignias del usuario, agrupadas por cercanía.
///
/// Antes las doce aparecían juntas en el perfil, ganadas y bloqueadas mezcladas.
/// Eso hacía dos daños a la vez: las conseguidas se diluían entre las que
/// faltaban, y las bloqueadas no se leían como metas porque nada decía a qué
/// distancia estaban.
class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badges = ref.watch(myBadgesProvider);
    final reputation = ref.watch(myReputationProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Insignias')),
      body: badges.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No se pudieron cargar las insignias'),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(myBadgesProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
        data: (items) {
          final groups = BadgeGroups.from(items, reputation.valueOrNull);
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myBadgesProvider);
              ref.invalidate(myReputationProvider);
              await ref.read(myBadgesProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Summary(groups: groups),
                if (groups.withinReach.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const _SectionTitle(
                    icon: Icons.flag_outlined,
                    title: 'A tu alcance',
                    subtitle: 'Lo más cerca que estás de desbloquear',
                  ),
                  const SizedBox(height: 12),
                  for (final progress in groups.withinReach)
                    _ProgressTile(progress: progress),
                ],
                if (groups.unlocked.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _SectionTitle(
                    icon: Icons.emoji_events_outlined,
                    title: 'Conseguidas',
                    subtitle: '${groups.unlocked.length} de ${groups.total}',
                  ),
                  const SizedBox(height: 12),
                  for (final badge in groups.unlocked)
                    _BadgeTile(badge: badge, unlocked: true),
                ],
                if (groups.later.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const _SectionTitle(
                    icon: Icons.lock_outline,
                    title: 'Más adelante',
                    subtitle: 'Para cuando lleves más camino',
                  ),
                  const SizedBox(height: 12),
                  for (final badge in groups.later)
                    _BadgeTile(badge: badge, unlocked: false),
                ],
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Cuántas llevas, arriba de todo.
class _Summary extends StatelessWidget {
  const _Summary({required this.groups});

  final BadgeGroups groups;

  @override
  Widget build(BuildContext context) {
    final done = groups.unlocked.length;
    final total = groups.total;
    final fraction = total == 0 ? 0.0 : done / total;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$done',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: context.successIconColor,
                        height: 1,
                      ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 4),
                  child: Text(
                    'de $total',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: context.mutedIconColor,
                        ),
                  ),
                ),
                const Spacer(),
                // Solo cuando hay algo que celebrar. Con cero insignias un
                // personaje festejando al lado del cero se lee como burla.
                //
                // Vuelve a festejar cuando el numero cambia: quien entra aqui
                // despues de desbloquear una la ve reaccionar a esa insignia y
                // no a la pantalla.
                if (done > 0)
                  CrewCelebration.cheering(
                    member: CrewMember.salvador,
                    height: 72,
                    restartKey: done,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: fraction),
                duration: AppMotion.slow,
                curve: AppMotion.curve,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: Theme.of(context).dividerColor,
                  valueColor: AlwaysStoppedAnimation(context.successIconColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: context.mutedIconColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            subtitle,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: context.mutedIconColor),
          ),
        ),
      ],
    );
  }
}

/// Insignia bloqueada, con cuánto le falta.
class _ProgressTile extends StatelessWidget {
  const _ProgressTile({required this.progress});

  final BadgeProgress progress;

  @override
  Widget build(BuildContext context) {
    final badge = progress.badge;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BadgeIcon(code: badge.code, unlocked: false),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    badge.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    badge.description,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: context.mutedIconColor),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: progress.fraction),
                      duration: AppMotion.slow,
                      curve: AppMotion.curve,
                      builder: (context, value, _) => LinearProgressIndicator(
                        value: value,
                        minHeight: 6,
                        backgroundColor: Theme.of(context).dividerColor,
                        valueColor:
                            AlwaysStoppedAnimation(context.primaryIconColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        progress.label,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: context.primaryIconColor,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const Spacer(),
                      Text(
                        '${progress.current}/${progress.target}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: context.mutedIconColor,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Insignia conseguida, o bloqueada sin progreso medible.
class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge, required this.unlocked});

  final PblBadge badge;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _BadgeIcon(code: badge.code, unlocked: unlocked),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    badge.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: unlocked ? null : context.mutedIconColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    badge.description,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: context.mutedIconColor),
                  ),
                  if (unlocked && badge.unlockedAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      // Cuándo la ganaste: una insignia con fecha es un recuerdo,
                      // sin fecha es solo un icono.
                      'Conseguida el ${DateFormat("d 'de' MMMM 'de' y", 'es').format(badge.unlockedAt!)}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: context.successIconColor,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            if (unlocked)
              Icon(Icons.check_circle, color: context.successIconColor),
          ],
        ),
      ),
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({required this.code, required this.unlocked});

  final String code;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: unlocked
            ? context.successIconContainerColor
            : Theme.of(context).dividerColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        badgeIconForCode(code),
        size: 24,
        color: unlocked ? context.successIconColor : context.mutedIconColor,
      ),
    );
  }
}
