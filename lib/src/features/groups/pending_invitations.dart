import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_error_message.dart';
import '../../core/app_motion.dart';
import '../../core/app_theme.dart';
import '../../core/crew.dart';
import '../../core/remote_image.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import 'membership_declaration_screen.dart';

/// Acceso a las invitaciones recibidas, siempre arriba en la pestana Grupos.
///
/// Siempre visible, tambien sin invitaciones: antes las tarjetas aparecian
/// solo si habia alguna, y cuando algo fallaba al dibujarlas o al pedirlas la
/// persona no veia nada y no sabia si le habian invitado o no.
class PendingInvitationsSection extends ConsumerWidget {
  const PendingInvitationsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitations = ref.watch(myInvitationsProvider);
    final count = invitations.valueOrNull?.length ?? 0;
    final highlight = count > 0;
    final subtitle = invitations.when(
      loading: () => 'Cargando…',
      error: (_, __) => 'No se pudieron cargar',
      data: (items) => switch (items.length) {
        0 => 'No tienes invitaciones pendientes',
        1 => '1 invitacion espera tu respuesta',
        final n => '$n invitaciones esperan tu respuesta',
      },
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        // Con invitaciones, el borde del color principal: es lo unico de la
        // pantalla que espera algo de la persona.
        shape: highlight
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: context.primaryIconColor.withOpacity(0.6),
                  width: 1.4,
                ),
              )
            : null,
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.primaryIconContainerColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              highlight ? Icons.mark_email_unread_outlined : Icons.mail_outline,
              color: context.primaryIconColor,
            ),
          ),
          title: const Text(
            'Invitaciones recibidas',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            subtitle,
            style: invitations.hasError
                ? TextStyle(color: context.dangerIconColor)
                : null,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (highlight)
                Badge(
                  label: Text('$count'),
                  backgroundColor: context.primaryIconColor,
                  textColor: context.isDarkMode ? AppColors.navy : Colors.white,
                ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: context.successIconColor),
            ],
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const ReceivedInvitationsScreen(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Las invitaciones que esperan respuesta de la persona de la sesion.
class ReceivedInvitationsScreen extends ConsumerWidget {
  const ReceivedInvitationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitations = ref.watch(myInvitationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Invitaciones recibidas')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myInvitationsProvider),
        child: invitations.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _Message(
            icon: Icons.cloud_off_outlined,
            color: context.dangerIconColor,
            title: 'No se pudieron cargar',
            message: apiErrorMessage(
              error,
              fallback: 'Revisa tu conexion e intenta otra vez.',
            ),
            action: TextButton.icon(
              onPressed: () => ref.invalidate(myInvitationsProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ),
          data: (items) => items.isEmpty
              ? _Message(
                  icon: Icons.mail_outline,
                  color: context.mutedIconColor,
                  title: 'No has recibido invitaciones',
                  message: 'Cuando el administrador de un grupo te invite '
                      'por tu usuario, la invitacion aparecera aqui.',
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final invitation in items) ...[
                      _InvitationCard(
                        key: ValueKey(invitation.id),
                        invitation: invitation,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

/// Estado vacio o de error, desplazable para que funcione deslizar y recargar.
class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 96, 32, 32),
      children: [
        Icon(icon, size: 48, color: color),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: context.mutedIconColor),
        ),
        if (action != null) ...[
          const SizedBox(height: 12),
          Center(child: action!),
        ],
      ],
    );
  }
}

class _InvitationCard extends ConsumerStatefulWidget {
  const _InvitationCard({required this.invitation, super.key});

  final GroupInvitation invitation;

  @override
  ConsumerState<_InvitationCard> createState() => _InvitationCardState();
}

class _InvitationCardState extends ConsumerState<_InvitationCard> {
  var _busy = false;

  GroupInvitation get _invitation => widget.invitation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: context.primaryIconColor.withOpacity(0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                RemoteAvatar(
                  imageRef: _invitation.groupPhoto,
                  fallbackIcon: Icons.group_outlined,
                  size: 44,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _invitation.groupName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_invitation.invitedByLabel} te invito a unirte',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: context.mutedIconColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Expanded en los dos: el tema le da a FilledButton un ancho minimo
            // infinito (Size.fromHeight(48)), y suelto dentro de un Row eso
            // rompia el dibujo de toda la tarjeta.
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : _reject,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Rechazar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _accept,
                    icon: _busy
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Aceptar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Aceptar es entrar al grupo, asi que pasa por la misma declaracion jurada
  /// que se firma al entrar con codigo.
  Future<void> _accept() async {
    final signed = await signMembershipDeclaration(
      context,
      groupName: _invitation.groupName,
    );
    if (signed == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).acceptInvitation(
            invitationId: _invitation.id,
            acceptedDeclarationVersion: signed.version,
            signatureImage: signed.signaturePng,
          );
      ref.invalidate(groupsProvider);
      invalidateGroup(ref, _invitation.groupId);
      if (!mounted) return;
      showAchievementSnackBar(
        context,
        title: 'Te uniste a ${_invitation.groupName}',
        message: 'Ya puedes ver sus gastos y pagos',
        icon: Icons.group_add_outlined,
        leading: const CrewCelebration.jumping(member: CrewMember.ariana),
      );
      context.push('/groups/${_invitation.groupId}');
      // Al final: al recargar la lista esta tarjeta desaparece, y despues ya
      // no hay contexto desde el cual navegar.
      ref.invalidate(myInvitationsProvider);
    } catch (error) {
      _showError(error, 'No se pudo aceptar la invitacion.');
      // Si ya no estaba vigente, que desaparezca de la lista.
      if (mounted) ref.invalidate(myInvitationsProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rechazar invitacion'),
        content: Text(
          'No te uniras a «${_invitation.groupName}». Si mas adelante quieres '
          'entrar, pidele al administrador que te invite de nuevo.',
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => context.pop(true),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).rejectInvitation(_invitation.id);
      ref.invalidate(myInvitationsProvider);
    } catch (error) {
      _showError(error, 'No se pudo rechazar la invitacion.');
      if (mounted) ref.invalidate(myInvitationsProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(Object error, String fallback) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(apiErrorMessage(error, fallback: fallback)),
    ));
  }
}
