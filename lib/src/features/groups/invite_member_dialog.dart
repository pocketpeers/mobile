import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_error_message.dart';
import '../../core/app_motion.dart';
import '../../core/app_theme.dart';
import '../../core/remote_image.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

enum _InviteMode { username, code }

/// Dialogo para sumar a alguien al grupo, por su usuario o con el codigo.
///
/// Por usuario va primero porque es lo mas directo cuando el administrador ya
/// sabe a quien invitar: la persona recibe la invitacion en la app y decide.
/// El codigo sigue para compartirlo por fuera, con quien todavia no se sabe
/// su usuario.
class InviteMemberDialog extends ConsumerStatefulWidget {
  const InviteMemberDialog({required this.groupId, this.groupName, super.key});

  final int groupId;
  final String? groupName;

  @override
  ConsumerState<InviteMemberDialog> createState() => _InviteMemberDialogState();
}

class _InviteMemberDialogState extends ConsumerState<InviteMemberDialog> {
  var _mode = _InviteMode.username;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: CircleAvatar(
        radius: 26,
        backgroundColor: context.primaryIconContainerColor,
        child: Icon(
          Icons.person_add_alt_1_outlined,
          color: context.primaryIconColor,
          size: 28,
        ),
      ),
      title: const Text('Agregar integrante'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<_InviteMode>(
                segments: const [
                  ButtonSegment(
                    value: _InviteMode.username,
                    icon: Icon(Icons.alternate_email),
                    label: Text('Por usuario'),
                  ),
                  ButtonSegment(
                    value: _InviteMode.code,
                    icon: Icon(Icons.key_outlined),
                    label: Text('Con codigo'),
                  ),
                ],
                selected: {_mode},
                showSelectedIcon: false,
                onSelectionChanged: (value) =>
                    setState(() => _mode = value.first),
              ),
              const SizedBox(height: 16),
              // Cada modo conserva lo que tenia al volver a el: sin esto, pasar
              // a ver el codigo borraba la busqueda a medio escribir.
              // TickerMode apaga las animaciones de la pestana oculta: si no, la
              // ruedita de carga del codigo giraba sin que nadie la viera.
              Offstage(
                offstage: _mode != _InviteMode.username,
                child: TickerMode(
                  enabled: _mode == _InviteMode.username,
                  child: _InviteByUsername(groupId: widget.groupId),
                ),
              ),
              Offstage(
                offstage: _mode != _InviteMode.code,
                child: TickerMode(
                  enabled: _mode == _InviteMode.code,
                  child: _InviteByCode(
                    groupId: widget.groupId,
                    groupName: widget.groupName,
                    active: _mode == _InviteMode.code,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Por usuario
// ---------------------------------------------------------------------------

class _InviteByUsername extends ConsumerStatefulWidget {
  const _InviteByUsername({required this.groupId});

  final int groupId;

  @override
  ConsumerState<_InviteByUsername> createState() => _InviteByUsernameState();
}

class _InviteByUsernameState extends ConsumerState<_InviteByUsername> {
  final _username = TextEditingController();
  InvitationCandidate? _candidate;
  var _searching = false;
  var _sending = false;
  var _notFound = false;
  String? _error;

  /// Nombre de la ultima persona invitada, para confirmarlo en pantalla.
  String? _sentTo;

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  String get _query {
    final text = _username.text.trim();
    return text.startsWith('@') ? text.substring(1).trim() : text;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final candidate = _candidate;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Le llegara la invitacion en la app y podra aceptarla o rechazarla.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: context.mutedIconColor),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _username,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.search,
          // La arroba ya esta fija delante: si la persona la escribe o pega
          // «@mialaos», no se ve «@@mialaos». Los usuarios no llevan espacios.
          inputFormatters: [
            FilteringTextInputFormatter.deny(RegExp(r'^@+')),
            FilteringTextInputFormatter.deny(RegExp(r'\s')),
          ],
          decoration: InputDecoration(
            labelText: 'Nombre de usuario',
            prefixText: '@',
            suffixIcon: IconButton(
              tooltip: 'Buscar',
              onPressed: _searching ? null : _search,
              icon: _searching
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
            ),
          ),
          // Cambiar el texto invalida lo encontrado: si no, se podria mandar
          // la invitacion a la persona de la busqueda anterior.
          onChanged: (_) {
            if (_candidate != null || _notFound || _error != null) {
              setState(() {
                _candidate = null;
                _notFound = false;
                _error = null;
              });
            }
          },
          onSubmitted: (_) => _search(),
        ),
        if (_sentTo != null && candidate == null && !_notFound) ...[
          const SizedBox(height: 12),
          _Notice(
            icon: Icons.check_circle_outline,
            color: context.successIconColor,
            text: 'Invitacion enviada a $_sentTo.',
          ),
        ],
        if (_notFound) ...[
          const SizedBox(height: 12),
          _Notice(
            icon: Icons.person_off_outlined,
            color: context.mutedIconColor,
            text: 'No se encontro el usuario. Revisa que este bien escrito.',
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          _Notice(
            icon: Icons.error_outline,
            color: context.dangerIconColor,
            text: _error!,
          ),
        ],
        if (candidate != null) ...[
          const SizedBox(height: 12),
          _CandidateCard(candidate: candidate),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed:
                candidate.availability == InvitationAvailability.available &&
                        !_sending
                    ? () => _send(candidate)
                    : null,
            icon: _sending
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: const Text('Enviar invitacion'),
          ),
        ],
        SentInvitationsList(
          groupId: widget.groupId,
          title: 'Esperando respuesta',
        ),
      ],
    );
  }

  Future<void> _search() async {
    final query = _query;
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _candidate = null;
      _notFound = false;
      _error = null;
      _sentTo = null;
    });
    try {
      final candidate = await ref.read(apiProvider).findInvitationCandidate(
            groupId: widget.groupId,
            username: query,
          );
      if (!mounted) return;
      setState(() {
        _candidate = candidate;
        _notFound = candidate == null;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = apiErrorMessage(
              error,
              fallback: 'No se pudo buscar al usuario. Intenta otra vez.',
            ));
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _send(InvitationCandidate candidate) async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      // Se manda el usuario confirmado, no lo que haya en el campo.
      await ref.read(apiProvider).inviteMember(
            groupId: widget.groupId,
            username: candidate.username,
          );
      ref.invalidate(groupInvitationsProvider(widget.groupId));
      if (!mounted) return;
      setState(() {
        _sentTo = candidate.fullName.trim().isNotEmpty
            ? candidate.fullName.trim()
            : '@${candidate.username}';
        _candidate = null;
        _username.clear();
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = apiErrorMessage(
              error,
              fallback: 'No se pudo enviar la invitacion. Intenta otra vez.',
            ));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

/// A quien se encontro: nombre y foto para confirmar antes de invitar.
class _CandidateCard extends StatelessWidget {
  const _CandidateCard({required this.candidate});

  final InvitationCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = candidate.fullName.trim();
    final note = switch (candidate.availability) {
      InvitationAvailability.available => null,
      InvitationAvailability.alreadyMember => 'Ya es integrante del grupo.',
      InvitationAvailability.alreadyInvited =>
        'Ya tiene una invitacion pendiente.',
      InvitationAvailability.recentlyRejected =>
        'Rechazo una invitacion hace poco. Podras invitarla de nuevo en unos '
            'dias.',
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.primaryIconContainerColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RemoteAvatar(
                imageRef: candidate.photo,
                fallbackIcon: Icons.person_outline,
                size: 48,
                borderRadius: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? '@${candidate.username}' : name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (name.isNotEmpty)
                      Text(
                        '@${candidate.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: context.mutedIconColor),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (note != null) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    size: 18, color: context.warningIconColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(note, style: theme.textTheme.bodySmall),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Cuanto le queda a una invitacion, en dias de calendario.
///
/// En dias y no en horas: «vence en 38 horas» obliga a hacer la cuenta, y lo
/// que el administrador quiere saber es si todavia hay tiempo.
String invitationExpiryLabel(DateTime? expiresAt, DateTime now) {
  if (expiresAt == null) return 'Pendiente';
  final local = expiresAt.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final days = day.difference(today).inDays;
  if (days <= 0) return 'Vence hoy';
  if (days == 1) return 'Vence mañana';
  return 'Vence en $days dias';
}

/// Las invitaciones que este grupo mando y nadie respondio todavia.
///
/// La usan el dialogo de agregar y la tarjeta de integrantes del grupo: antes
/// solo estaba en el dialogo, y para saber si alguien seguia sin responder
/// habia que abrir «Agregar integrante» sin querer agregar a nadie.
class SentInvitationsList extends ConsumerStatefulWidget {
  const SentInvitationsList({
    required this.groupId,
    this.title,
    this.topSpacing = 20,
    super.key,
  });

  final int groupId;

  /// Titulo de la lista; se le agrega cuantas son. Sin titulo, solo las filas.
  final String? title;
  final double topSpacing;

  @override
  ConsumerState<SentInvitationsList> createState() =>
      _SentInvitationsListState();
}

class _SentInvitationsListState extends ConsumerState<SentInvitationsList> {
  final _cancelling = <int>{};

  @override
  Widget build(BuildContext context) {
    final invitations =
        ref.watch(groupInvitationsProvider(widget.groupId)).valueOrNull;
    if (invitations == null || invitations.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: widget.topSpacing),
        if (widget.title != null) ...[
          Text(
            '${widget.title} (${invitations.length})',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
        ],
        for (final invitation in invitations)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: RemoteAvatar(
              imageRef: invitation.invitedPhoto,
              fallbackIcon: Icons.person_outline,
              size: 36,
              borderRadius: 18,
            ),
            title: Text(
              _nameOf(invitation),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '@${invitation.invitedUsername} · '
              '${invitationExpiryLabel(invitation.expiresAt, now)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: _cancelling.contains(invitation.id)
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    tooltip: 'Cancelar invitacion',
                    onPressed: () => _cancel(invitation),
                    icon: const Icon(Icons.close),
                  ),
          ),
      ],
    );
  }

  String _nameOf(GroupInvitation invitation) =>
      invitation.invitedFullName.trim().isNotEmpty
          ? invitation.invitedFullName.trim()
          : '@${invitation.invitedUsername}';

  Future<void> _cancel(GroupInvitation invitation) async {
    // Con confirmacion: la X queda al lado del nombre y un toque de mas
    // anulaba una invitacion que la persona quiza estaba por aceptar.
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar invitacion'),
        content: Text(
          '${_nameOf(invitation)} ya no podra aceptarla. Puedes volver a '
          'invitarla cuando quieras.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancelar invitacion'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancelling.add(invitation.id));
    try {
      await ref.read(apiProvider).cancelInvitation(
            groupId: widget.groupId,
            invitationId: invitation.id,
          );
      ref.invalidate(groupInvitationsProvider(widget.groupId));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(apiErrorMessage(
            error,
            fallback: 'No se pudo cancelar la invitacion.',
          )),
        ));
      }
    } finally {
      if (mounted) setState(() => _cancelling.remove(invitation.id));
    }
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Con codigo
// ---------------------------------------------------------------------------

/// El codigo fijo del grupo y como usarlo.
///
/// Se pide recien al abrir esta pestana: quien solo invita por usuario no
/// necesita que se genere.
class _InviteByCode extends ConsumerStatefulWidget {
  const _InviteByCode({
    required this.groupId,
    required this.groupName,
    required this.active,
  });

  final int groupId;
  final String? groupName;
  final bool active;

  @override
  ConsumerState<_InviteByCode> createState() => _InviteByCodeState();
}

class _InviteByCodeState extends ConsumerState<_InviteByCode> {
  String? _token;
  var _loading = false;
  var _failed = false;
  var _copied = false;
  Timer? _copiedTimer;

  @override
  void initState() {
    super.initState();
    if (widget.active) _load();
  }

  @override
  void didUpdateWidget(covariant _InviteByCode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && _token == null && !_loading && !_failed) _load();
  }

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    _loading = true;
    if (_failed && mounted) setState(() => _failed = false);
    try {
      final token =
          await ref.read(apiProvider).generateInvitation(widget.groupId);
      if (!mounted) return;
      setState(() {
        _token = token.trim();
        _failed = _token!.isEmpty;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      _loading = false;
    }
  }

  Future<void> _copy() async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: token));
    if (!mounted) return;
    // Aviso dentro del propio boton: un SnackBar quedaria detras del dialogo.
    setState(() => _copied = true);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupName = widget.groupName?.trim() ?? '';
    final ready = _token != null && !_failed;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          groupName.isEmpty
              ? 'Comparte este codigo con la persona que quieres sumar.'
              : 'Comparte este codigo con la persona que quieres sumar a '
                  '«$groupName».',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: context.mutedIconColor),
        ),
        const SizedBox(height: 16),
        _codeBox(context),
        const SizedBox(height: 12),
        if (_failed)
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          )
        else
          FilledButton.icon(
            onPressed: ready ? _copy : null,
            icon: Icon(_copied ? Icons.check : Icons.copy_outlined),
            label: Text(_copied ? 'Copiado' : 'Copiar codigo'),
          ),
        const SizedBox(height: 20),
        Text('Como se une', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        const _InviteStep(
          number: 1,
          text: 'Copia el codigo y enviaselo por el chat que prefieras.',
        ),
        const _InviteStep(
          number: 2,
          text: 'En la pestaña Grupos, toca «Unirme» y pega el codigo.',
        ),
        const _InviteStep(
          number: 3,
          text: 'Firma la declaracion jurada y ya forma parte del grupo.',
        ),
      ],
    );
  }

  Widget _codeBox(BuildContext context) {
    final theme = Theme.of(context);
    final Widget child;
    if (_failed) {
      child = Row(
        children: [
          Icon(Icons.error_outline, color: context.dangerIconColor),
          const SizedBox(width: 8),
          const Expanded(child: Text('No se pudo obtener el codigo.')),
        ],
      );
    } else if (_token == null) {
      child = const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    } else {
      child = SelectableText(
        _token!,
        textAlign: TextAlign.center,
        style: theme.textTheme.titleMedium?.copyWith(
          fontFamily: 'monospace',
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: context.primaryIconColor,
        ),
      );
    }
    return Material(
      color: context.primaryIconContainerColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _token != null && !_failed ? _copy : null,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 64),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.primaryIconColor.withOpacity(0.35),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _InviteStep extends StatelessWidget {
  const _InviteStep({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: context.primaryIconContainerColor,
            child: Text(
              '$number',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.primaryIconColor,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}


/// Acceso a las invitaciones pendientes desde la pantalla del grupo.
///
/// Siempre visible para el administrador, tambien con cero. Antes la lista
/// aparecia solo si habia alguna y el servidor respondia: sin invitaciones, o
/// con un backend que aun no tenia el endpoint, no se veia nada y no habia
/// forma de saber si faltaban datos o faltaba la funcion.
class PendingInvitationsEntry extends ConsumerWidget {
  const PendingInvitationsEntry({
    required this.groupId,
    this.groupName,
    super.key,
  });

  final int groupId;
  final String? groupName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitations = ref.watch(groupInvitationsProvider(groupId));
    final count = invitations.valueOrNull?.length ?? 0;
    final subtitle = invitations.when(
      loading: () => 'Cargando…',
      error: (_, __) => 'No se pudieron cargar',
      data: (items) => switch (items.length) {
        0 => 'Ninguna esperando respuesta',
        1 => '1 esperando respuesta',
        final n => '$n esperando respuesta',
      },
    );
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: context.primaryIconContainerColor,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.schedule_send_outlined,
            size: 22, color: context.primaryIconColor),
      ),
      title: const Text('Invitaciones pendientes'),
      subtitle: Text(
        subtitle,
        style: invitations.hasError
            ? TextStyle(color: context.dangerIconColor)
            : null,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (count > 0)
            Badge(
              label: Text('$count'),
              backgroundColor: context.primaryIconColor,
              textColor: context.isDarkMode ? AppColors.navy : Colors.white,
            ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => showAppDialog<void>(
        context: context,
        builder: (_) => _PendingInvitationsDialog(
          groupId: groupId,
          groupName: groupName,
        ),
      ),
    );
  }
}

class _PendingInvitationsDialog extends ConsumerWidget {
  const _PendingInvitationsDialog({required this.groupId, this.groupName});

  final int groupId;
  final String? groupName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitations = ref.watch(groupInvitationsProvider(groupId));
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Invitaciones pendientes'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, minWidth: 280),
        child: SingleChildScrollView(
          child: invitations.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_outlined,
                    size: 36, color: context.dangerIconColor),
                const SizedBox(height: 8),
                Text(
                  apiErrorMessage(
                    error,
                    fallback: 'No se pudieron cargar las invitaciones.',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () =>
                      ref.invalidate(groupInvitationsProvider(groupId)),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
            data: (items) => items.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.mark_email_read_outlined,
                            size: 36, color: context.mutedIconColor),
                        const SizedBox(height: 8),
                        Text(
                          'Nadie tiene una invitacion sin responder.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: context.mutedIconColor),
                        ),
                      ],
                    ),
                  )
                : SentInvitationsList(groupId: groupId, topSpacing: 0),
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
        FilledButton.icon(
          onPressed: () {
            // El contexto de este dialogo deja de servir al cerrarlo; el del
            // navegador sigue vivo y desde ahi se abre el siguiente.
            final navigator = Navigator.of(context);
            navigator.pop();
            showAppDialog<void>(
              context: navigator.context,
              builder: (_) =>
                  InviteMemberDialog(groupId: groupId, groupName: groupName),
            );
          },
          icon: const Icon(Icons.person_add_alt_1_outlined),
          label: const Text('Invitar'),
        ),
      ],
    );
  }
}
