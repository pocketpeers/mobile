import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

/// Historial de notificaciones del usuario.
///
/// Muestra leídas y no leídas juntas, distinguidas visualmente. Antes solo
/// existían las pendientes: al marcar una como leída desaparecía para siempre
/// aunque siguiera guardada en la base.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    final history = ref.watch(notificationHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          PopupMenuButton<String>(
            onSelected: _onMenuSelected,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'read-all',
                child: ListTile(
                  leading: Icon(Icons.done_all_outlined),
                  title: Text('Marcar todas como leídas'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'clear-read',
                child: ListTile(
                  leading: Icon(Icons.delete_sweep_outlined),
                  title: Text('Borrar las leídas'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          onRetry: () => ref.invalidate(notificationHistoryProvider),
        ),
        data: (items) => items.isEmpty
            ? const _EmptyState()
            : RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(notificationHistoryProvider);
                  await ref.read(notificationHistoryProvider.future);
                },
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) => _NotificationTile(
                    reminder: items[index],
                    onDelete: () => _delete(items[index]),
                    onTap: () => _open(items[index]),
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _onMenuSelected(String action) async {
    if (action == 'read-all') {
      await _run(
        () => ref.read(apiProvider).markAllNotificationsRead(),
        'Todas marcadas como leídas',
      );
      return;
    }
    if (action == 'clear-read') {
      final confirmed = await _confirmClearRead();
      if (confirmed != true) return;
      await _run(
        () => ref.read(apiProvider).deleteReadNotifications(),
        'Notificaciones leídas borradas',
      );
    }
  }

  Future<bool?> _confirmClearRead() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Borrar las leídas'),
        // Se aclara que las pendientes se conservan: sin decirlo, la opción
        // parece más destructiva de lo que es y la gente no la usa.
        content: const Text(
          'Se borrarán las notificaciones que ya viste. Las pendientes se '
          'conservan.',
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => context.pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(PaymentReminder reminder) async {
    await _run(
      () => ref.read(apiProvider).deleteNotification(reminder.id),
      'Notificación borrada',
    );
  }

  Future<void> _open(PaymentReminder reminder) async {
    // Abrir una notificación la da por vista, que es lo que la persona espera.
    if (!reminder.read) {
      try {
        await ref.read(apiProvider).markNotificationRead(reminder.id);
        ref.invalidate(notificationHistoryProvider);
        ref.invalidate(unreadNotificationCountProvider);
      } catch (_) {
        // Si falla marcarla, igual se navega: no poder registrar la lectura no
        // debería impedir ver el pago.
      }
    }
    if (mounted) context.push('/payments/${reminder.paymentId}');
  }

  Future<void> _run(Future<void> Function() action, String successMessage) async {
    try {
      await action();
      ref.invalidate(notificationHistoryProvider);
      ref.invalidate(unreadNotificationCountProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('No se pudo completar la acción')),
        );
    }
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.reminder,
    required this.onDelete,
    required this.onTap,
  });

  final PaymentReminder reminder;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = !reminder.read;
    return Dismissible(
      key: ValueKey(reminder.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: Theme.of(context).colorScheme.error.withOpacity(0.12),
        child: Icon(Icons.delete_outline,
            color: Theme.of(context).colorScheme.error),
      ),
      onDismissed: (_) => onDelete(),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: unread
                ? context.primaryIconContainerColor
                : Theme.of(context).dividerColor.withOpacity(0.35),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _iconFor(reminder.type),
            size: 22,
            color: unread ? context.primaryIconColor : context.mutedIconColor,
          ),
        ),
        title: Text(
          reminder.title,
          style: TextStyle(
            fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(reminder.body),
            const SizedBox(height: 4),
            Text(
              _subtitleFor(reminder),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.mutedIconColor,
                  ),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: unread
            ? Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: context.primaryIconColor,
                  shape: BoxShape.circle,
                ),
              )
            : null,
      ),
    );
  }

  String _subtitleFor(PaymentReminder reminder) {
    final when = reminder.createdAt;
    final date = when == null
        ? ''
        : DateFormat("d 'de' MMMM, HH:mm", 'es').format(when.toLocal());
    if (reminder.groupName.isEmpty) return date;
    return date.isEmpty ? reminder.groupName : '${reminder.groupName} · $date';
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'DUE_IN_48_HOURS':
        return Icons.schedule_outlined;
      case 'DUE_TODAY':
        return Icons.today_outlined;
      case 'EXPENSE_ASSIGNED':
        return Icons.receipt_long_outlined;
      case 'PAYMENT_REGISTERED':
        return Icons.check_circle_outline;
      case 'OVERDUE_MANUAL':
        return Icons.warning_amber_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none_outlined,
                size: 56, color: context.mutedIconColor),
            const SizedBox(height: 16),
            Text(
              'Todavía no tienes notificaciones',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Aquí verás los avisos de tus pagos y gastos compartidos.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: context.mutedIconColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined,
                size: 48, color: context.mutedIconColor),
            const SizedBox(height: 16),
            const Text('No se pudieron cargar las notificaciones'),
            const SizedBox(height: 16),
            FilledButton.icon(
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
