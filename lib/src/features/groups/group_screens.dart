import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_motion.dart';
import '../../core/app_theme.dart';
import '../../core/badge_visuals.dart';
import '../../core/crew.dart';
import '../../core/formatters.dart';
import '../../core/skeleton.dart';
import '../../core/image_source_picker.dart';
import '../../core/remote_image.dart';
import '../../core/validators.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../dashboard/dashboard_screen.dart';
import '../expenses/expense_screens.dart';
import 'join_group_dialog.dart';

const _groupDescriptionMaxLength = 100;

class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  final _search = TextEditingController();
  List<Group>? _results;
  var _searching = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(groupsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Grupos')),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'join-group',
            onPressed: () => showAppDialog<void>(
              context: context,
              builder: (context) => const JoinGroupDialog(),
            ),
            icon: const Icon(Icons.group_add_outlined),
            label: const Text('Unirme'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'create-group',
            onPressed: () => context.push('/groups/new'),
            icon: const Icon(Icons.add),
            label: const Text('Grupo'),
          ),
        ],
      ),
      body: groups.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => ErrorView(
          title: 'No se pudieron cargar los grupos',
          onRetry: () => ref.invalidate(groupsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
                child: Text('Crea tu primer grupo para empezar'));
          }
          final visibleItems = _results ?? items;
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(groupsProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _search,
                        decoration: const InputDecoration(
                          labelText: 'Buscar grupo',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onSubmitted: (_) => _runSearch(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _searching ? null : _runSearch,
                      style: IconButton.styleFrom(
                        backgroundColor: context.successIconColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            context.successIconColor.withOpacity(0.42),
                        disabledForegroundColor: Colors.white70,
                      ),
                      icon: _searching
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.search),
                    ),
                    if (_results != null)
                      IconButton(
                        onPressed: () => setState(() {
                          _results = null;
                          _search.clear();
                        }),
                        icon: const Icon(Icons.close),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (visibleItems.isEmpty)
                  const Card(
                    child: ListTile(title: Text('No se encontraron grupos')),
                  )
                else
                  for (var i = 0; i < visibleItems.length; i++) ...[
                    AnimatedSection(
                      index: i,
                      child: Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          leading: RemoteAvatar(
                            imageRef: visibleItems[i].groupPhoto,
                            fallbackIcon: Icons.group_outlined,
                            size: 44,
                          ),
                          title: Text(
                            visibleItems[i].name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(visibleItems[i].description),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: context.successIconColor,
                          ),
                          onTap: () =>
                              context.push('/groups/${visibleItems[i].id}'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _runSearch() async {
    final query = _search.text.trim();
    if (query.isEmpty) {
      setState(() => _results = null);
      return;
    }
    setState(() => _searching = true);
    try {
      final result = await ref.read(apiProvider).searchGroups(query);
      if (mounted) setState(() => _results = result);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }
}

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();

  // Foto elegida que todavia no se sube. Se manda recien en _save para que
  // las descartadas no lleguen nunca al servidor.
  //
  // No hay campo con el id remoto como en el dialogo de edicion: un grupo que
  // todavia no existe no puede tener una foto previa, asi que lo unico que
  // puede haber aqui es un archivo local o nada.
  XFile? _pendingPhoto;

  var _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo grupo')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nombre'),
              validator: nameField,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              minLines: 3,
              maxLines: 5,
              maxLength: _groupDescriptionMaxLength,
              inputFormatters: [
                LengthLimitingTextInputFormatter(_groupDescriptionMaxLength),
              ],
              decoration: const InputDecoration(labelText: 'Descripcion'),
              validator: _groupDescription,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                PhotoPreview(
                  pendingFile: _pendingPhoto,
                  imageRef: '',
                  fallbackIcon: Icons.group_outlined,
                  size: 56,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _pickGroupPhoto,
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Foto del grupo'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Crear grupo'),
            ),
          ],
        ),
      ),
    );
  }

  String? _groupDescription(String? value) {
    final required = requiredField(value);
    if (required != null) return required;
    final description = value!.trim();
    if (description.length < 5) return 'Ingresa al menos 5 caracteres';
    if (description.length > _groupDescriptionMaxLength) {
      return 'Ingresa maximo $_groupDescriptionMaxLength caracteres';
    }
    return null;
  }

  Future<void> _pickGroupPhoto() async {
    final image = await pickImageFromCameraOrGallery(context);
    if (image == null) return;
    // Solo se guarda la referencia local: la subida espera a _save.
    setState(() => _pendingPhoto = image);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) return;
    setState(() => _saving = true);
    try {
      var groupPhoto = '';
      final pending = _pendingPhoto;
      if (pending != null) {
        groupPhoto =
            (await ref.read(apiProvider).uploadImage(pending.path)).imageId;
      }
      await ref.read(apiProvider).createGroup(
            name: _name.text.trim(),
            description: _description.text.trim(),
            adminId: session.id,
            groupPhoto: groupPhoto,
          );
      ref.invalidate(groupsProvider);
      ref.invalidate(myReputationProvider);
      ref.invalidate(myBadgesProvider);
      ref.invalidate(myReputationHistoryProvider);
      if (mounted) {
        showAchievementSnackBar(
          context,
          title: 'Grupo creado',
          message: 'Tu grupo ya esta listo para sumar integrantes',
          icon: Icons.group_add_outlined,
          // El tutorial termina empujando a crear el primer grupo, asi que este
          // es el primer logro real de mucha gente. Festeja Ariana, que es
          // quien explica el reparto entre varios.
          leading: const CrewCelebration.jumping(member: CrewMember.ariana),
        );
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class GroupDetailScreen extends ConsumerStatefulWidget {
  const GroupDetailScreen({required this.groupId, super.key});

  final int groupId;

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  static const _blockchainRefreshInterval = Duration(seconds: 3);
  static const _maxBlockchainRefreshAttempts = 20;

  Timer? _blockchainRefreshTimer;
  var _blockchainRefreshLimitReached = false;
  var _blockchainRefreshAttempts = 0;

  @override
  void dispose() {
    _blockchainRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final group = ref.watch(groupProvider(widget.groupId));
    final members = ref.watch(groupMembersProvider(widget.groupId));
    final expenses = ref.watch(groupExpensesProvider(widget.groupId));
    final allPayments = ref.watch(allGroupPaymentsProvider(widget.groupId));
    final summary = ref.watch(groupSummaryProvider(widget.groupId));
    final leaderboard = ref.watch(groupLeaderboardProvider(widget.groupId));
    final overdueMembers = ref.watch(overdueMembersProvider(widget.groupId));
    final session = ref.watch(authControllerProvider).valueOrNull;
    final isAdmin = group.valueOrNull?.adminId == session?.id;
    _syncBlockchainRefresh(
      expenses: expenses.valueOrNull ?? const [],
      payments: allPayments.valueOrNull ?? const [],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(group.valueOrNull?.name ?? 'Grupo'),
        actions: [
          if (isAdmin && group.valueOrNull != null)
            IconButton(
              tooltip: 'Editar grupo',
              onPressed: () => showAppDialog<void>(
                context: context,
                builder: (context) =>
                    _EditGroupDialog(group: group.valueOrNull!),
              ),
              icon: const Icon(Icons.edit_outlined),
            ),
          IconButton(
            tooltip: 'Invitacion',
            onPressed: () => _showInvitation(context, ref),
            icon: const Icon(Icons.ios_share_outlined),
          ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () =>
                  context.push('/groups/${widget.groupId}/expenses/new'),
              icon: const Icon(Icons.add_card_outlined),
              label: const Text('Gasto'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async => invalidateGroup(ref, widget.groupId),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            group.when(
              loading: () => const SkeletonCard(lines: 2),
              error: (error, stackTrace) =>
                  Text('No se pudo cargar el grupo: $error'),
              data: (item) => _GroupHeaderCard(
                group: item,
                members: members.valueOrNull,
                expenseCount: expenses.valueOrNull?.length,
                isAdmin: isAdmin,
              ),
            ),
            const SizedBox(height: 16),
            summary.when(
              // Imita la rosca y sus cifras: al llegar los datos nada se
              // recoloca, solo se rellena.
              loading: () => const SkeletonSummaryCard(),
              error: (error, stackTrace) =>
                  Text('No se pudo calcular el resumen: $error'),
              data: (item) => _GroupSummaryCard(summary: item),
            ),
            if (isAdmin) ...[
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Pagos vencidos',
                child: overdueMembers.when(
                  loading: () => const SkeletonList(rows: 2),
                  error: (error, stackTrace) =>
                      const Text('No se pudieron cargar los pagos vencidos'),
                  data: (items) => _OverdueMembersList(
                    groupId: widget.groupId,
                    members: items,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Ranking',
              child: leaderboard.when(
                loading: () => const SkeletonList(),
                error: (error, stackTrace) =>
                    const Text('No se pudo cargar el ranking'),
                data: (items) =>
                    _LeaderboardList(groupId: widget.groupId, entries: items),
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Integrantes',
              child: members.when(
                loading: () => const SkeletonList(),
                error: (error, stackTrace) =>
                    Text('No se pudieron cargar integrantes'),
                data: (items) => Column(
                  children: [
                    for (final member in items)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: RemoteAvatar(
                          imageRef: member.photo,
                          fallbackIcon: Icons.person_outline,
                          size: 40,
                          borderRadius: 20,
                        ),
                        title: Text(member.fullName),
                        subtitle: Text(member.role),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(
                          '/groups/${widget.groupId}/members/${member.userId}',
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Los gastos no van dentro de una tarjeta de seccion como el resto:
            // cada gasto ya es una tarjeta y anidarlas dejaba borde sobre borde.
            // Encabezado suelto y las tarjetas sueltas debajo.
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Gastos recientes',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if ((expenses.valueOrNull ?? const []).isNotEmpty)
                  TextButton.icon(
                    onPressed: () =>
                        context.push('/groups/${widget.groupId}/expenses'),
                    icon: const Icon(Icons.list_alt_outlined, size: 18),
                    label: Text('Ver todos (${expenses.valueOrNull!.length})'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            expenses.when(
              loading: () => const SkeletonList(rows: 2),
              error: (error, stackTrace) =>
                  const Text('No se pudieron cargar gastos'),
              data: (items) {
                if (items.isEmpty) {
                  return EmptyHint(
                    icon: Icons.receipt_long_outlined,
                    title: 'Sin gastos',
                    message: isAdmin
                        ? 'Registra el primer gasto con el boton de abajo.'
                        : 'Cuando el grupo registre un gasto lo veras aqui.',
                  );
                }
                final recent = sortExpensesByRecency(items)
                    .take(recentExpensesCount)
                    .toList();
                return Column(
                  children: [
                    for (var index = 0; index < recent.length; index++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AnimatedSection(
                          index: index,
                          child: ExpenseCard(
                            expense: recent[index],
                            onTap: () => context.push(
                              '/groups/${widget.groupId}/expenses/${recent[index].id}',
                            ),
                          ),
                        ),
                      ),
                    if (items.length > recent.length)
                      OutlinedButton.icon(
                        onPressed: () =>
                            context.push('/groups/${widget.groupId}/expenses'),
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: Text('Ver los ${items.length} gastos del grupo'),
                      ),
                  ],
                );
              },
            ),
            // El boton flotante de "Gasto" tapa el final de la lista.
            const SizedBox(height: 72),
          ],
        ),
      ),
    );
  }

  Future<void> _showInvitation(BuildContext context, WidgetRef ref) async {
    final token =
        await ref.read(apiProvider).generateInvitation(widget.groupId);
    if (!context.mounted) return;
    await showAppDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Codigo de invitacion'),
        content:
            SelectableText(token.isEmpty ? 'Sin codigo disponible' : token),
        actions: [
          TextButton.icon(
            onPressed: token.isEmpty
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: token));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Codigo copiado')),
                      );
                    }
                  },
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Copiar'),
          ),
          TextButton(
              onPressed: () => context.pop(), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  void _syncBlockchainRefresh({
    required List<Expense> expenses,
    required List<Payment> payments,
  }) {
    // Expense and payment hashes arrive after backend blockchain sync. The group
    // screen polls briefly so users see hashes without manually refreshing.
    final hasPendingHashes =
        expenses.any(_expenseHashPending) || payments.any(_paymentHashPending);
    if (!hasPendingHashes) {
      _stopBlockchainRefresh();
      _blockchainRefreshLimitReached = false;
      return;
    }
    if (_blockchainRefreshLimitReached) return;
    if (_blockchainRefreshTimer != null) return;
    _blockchainRefreshAttempts = 0;
    _blockchainRefreshTimer = Timer.periodic(
      _blockchainRefreshInterval,
      (_) => _refreshPendingBlockchainHashes(),
    );
  }

  bool _expenseHashPending(Expense expense) =>
      expense.blockchainHash.trim().isEmpty;

  bool _paymentHashPending(Payment payment) =>
      payment.blockchainHash.trim().isEmpty;

  void _refreshPendingBlockchainHashes() {
    if (!mounted) return;
    _blockchainRefreshAttempts++;
    final expenses =
        ref.read(groupExpensesProvider(widget.groupId)).valueOrNull ?? const [];
    ref.invalidate(groupExpensesProvider(widget.groupId));
    ref.invalidate(allGroupPaymentsProvider(widget.groupId));
    ref.invalidate(groupSummaryProvider(widget.groupId));
    for (final expense in expenses) {
      ref.invalidate(expenseProvider(expense.id));
      ref.invalidate(expensePaymentsProvider(expense.id));
    }
    if (_blockchainRefreshAttempts >= _maxBlockchainRefreshAttempts) {
      _blockchainRefreshLimitReached = true;
      _stopBlockchainRefresh();
    }
  }

  void _stopBlockchainRefresh() {
    _blockchainRefreshTimer?.cancel();
    _blockchainRefreshTimer = null;
    _blockchainRefreshAttempts = 0;
  }
}

class _EditGroupDialog extends ConsumerStatefulWidget {
  const _EditGroupDialog({required this.group});

  final Group group;

  @override
  ConsumerState<_EditGroupDialog> createState() => _EditGroupDialogState();
}

class _EditGroupDialogState extends ConsumerState<_EditGroupDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late String _groupPhoto;

  // Foto elegida que todavia no se sube. Se manda recien en _save para que
  // las descartadas no lleguen nunca al servidor.
  XFile? _pendingPhoto;

  var _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.group.name);
    _description = TextEditingController(text: widget.group.description);
    _groupPhoto = widget.group.groupPhoto;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar grupo'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PhotoPreview(
                  pendingFile: _pendingPhoto,
                  imageRef: _groupPhoto,
                  fallbackIcon: Icons.group_outlined,
                  size: 72,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _pickGroupPhoto,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Actualizar foto'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: nameField,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: _groupDescriptionMaxLength,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(
                      _groupDescriptionMaxLength,
                    ),
                  ],
                  decoration: const InputDecoration(labelText: 'Descripcion'),
                  validator: _groupDescription,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => context.pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: const Text('Guardar'),
        ),
      ],
    );
  }

  String? _groupDescription(String? value) {
    final required = requiredField(value);
    if (required != null) return required;
    final description = value!.trim();
    if (description.length < 5) return 'Ingresa al menos 5 caracteres';
    if (description.length > _groupDescriptionMaxLength) {
      return 'Ingresa maximo $_groupDescriptionMaxLength caracteres';
    }
    return null;
  }

  Future<void> _pickGroupPhoto() async {
    final image = await pickImageFromCameraOrGallery(context);
    if (image == null) return;
    // Solo se guarda la referencia local: la subida espera a _save. Ya no
    // hace falta bloquear el formulario, porque elegir dejo de ser una
    // operacion de red.
    setState(() => _pendingPhoto = image);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      var groupPhoto = _groupPhoto;
      final pending = _pendingPhoto;
      if (pending != null) {
        groupPhoto =
            (await ref.read(apiProvider).uploadImage(pending.path)).imageId;
      }
      await ref.read(apiProvider).updateGroup(
            groupId: widget.group.id,
            name: _name.text.trim(),
            description: _description.text.trim(),
          );
      if (groupPhoto != widget.group.groupPhoto) {
        await ref.read(apiProvider).updateGroupImage(
              groupId: widget.group.id,
              image: groupPhoto,
            );
      }
      invalidateGroup(ref, widget.group.id);
      if (mounted) {
        showAchievementSnackBar(
          context,
          title: 'Grupo actualizado',
          message: 'Los cambios se guardaron correctamente',
          icon: Icons.verified_outlined,
        );
        context.pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo actualizar el grupo: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _OverdueMembersList extends StatelessWidget {
  const _OverdueMembersList({required this.groupId, required this.members});

  final int groupId;
  final List<OverdueMember> members;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.verified_outlined),
        title: Text('Todos los miembros estan al dia'),
      );
    }

    return Column(
      children: [
        for (final member in members)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: RemoteAvatar(
              imageRef: member.photo,
              fallbackIcon: Icons.person_outline,
              size: 40,
              borderRadius: 20,
              backgroundColor: Colors.redAccent.withOpacity(0.12),
              iconColor: Colors.redAccent,
            ),
            title: Text(member.fullName),
            subtitle: Text(
              'Vencio ${formatDate(member.oldestDueDate)} - ${member.maxDaysOverdue} dias de atraso',
            ),
            trailing: Text(formatCurrency(member.overdueAmount)),
            onTap: () => showAppDialog<void>(
              context: context,
              builder: (context) => _OverdueMemberDebtsDialog(
                groupId: groupId,
                member: member,
              ),
            ),
          ),
      ],
    );
  }
}

class _OverdueMemberDebtsDialog extends ConsumerStatefulWidget {
  const _OverdueMemberDebtsDialog({
    required this.groupId,
    required this.member,
  });

  final int groupId;
  final OverdueMember member;

  @override
  ConsumerState<_OverdueMemberDebtsDialog> createState() =>
      _OverdueMemberDebtsDialogState();
}

class _OverdueMemberDebtsDialogState
    extends ConsumerState<_OverdueMemberDebtsDialog> {
  var _sending = false;

  @override
  Widget build(BuildContext context) {
    final debts = ref.watch(overdueMemberDebtsProvider(
      (groupId: widget.groupId, memberId: widget.member.userId),
    ));
    return AlertDialog(
      title: Text(widget.member.fullName),
      content: SizedBox(
        width: 460,
        child: debts.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, stackTrace) =>
              const Text('No se pudo cargar el detalle de deuda'),
          data: (items) => items.isEmpty
              ? const Text('Todos los miembros estan al dia')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final debt in items)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(debt.expenseName),
                        subtitle: Text(
                          'Debio pagarse ${formatDate(debt.dueDate)} - ${debt.daysOverdue} dias de atraso',
                        ),
                        trailing: Text(formatCurrency(debt.overdueAmount)),
                      ),
                  ],
                ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => context.pop(),
          child: const Text('Cerrar'),
        ),
        FilledButton.icon(
          onPressed: _sending ? null : _sendReminder,
          icon: _sending
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.notifications_active_outlined),
          label: const Text('Enviar recordatorio'),
        ),
      ],
    );
  }

  Future<void> _sendReminder() async {
    setState(() => _sending = true);
    try {
      final result = await ref.read(apiProvider).sendManualOverdueReminder(
            groupId: widget.groupId,
            memberId: widget.member.userId,
          );
      ref.invalidate(overdueMembersProvider(widget.groupId));
      ref.invalidate(overdueMemberDebtsProvider(
        (groupId: widget.groupId, memberId: widget.member.userId),
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message)),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo enviar el recordatorio: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class _LeaderboardList extends StatelessWidget {
  const _LeaderboardList({required this.groupId, required this.entries});

  final int groupId;
  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const Text('Sin integrantes para mostrar');
    // The backend returns the canonical order; the UI only highlights the top
    // three and links each row to the member's public PBL profile.
    final podium = entries.take(3).toList();
    return Column(
      children: [
        if (entries.length == 1)
          const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Eres el unico integrante'),
            subtitle: Text('Agrega mas miembros para activar la competencia'),
          )
        else
          Row(
            children: [
              for (final entry in podium)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _podiumColor(entry.position).withOpacity(0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.emoji_events_outlined,
                            color: _podiumColor(entry.position)),
                        Text('#${entry.position}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w900)),
                        Text(
                          entry.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${entry.score} pts',
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 12),
        for (final entry in entries)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Stack(
              alignment: Alignment.bottomRight,
              children: [
                RemoteAvatar(
                  imageRef: entry.photo,
                  fallbackIcon: Icons.person_outline,
                  size: 44,
                  borderRadius: 22,
                  backgroundColor: entry.currentUser
                      ? context.successIconContainerColor
                      : context.primaryIconContainerColor,
                  iconColor: entry.currentUser
                      ? context.successIconColor
                      : context.primaryIconColor,
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${entry.position}',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ],
            ),
            title: Row(
              children: [
                Expanded(child: Text(entry.fullName)),
                if (entry.currentUser)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Chip(label: Text('Tu')),
                  ),
              ],
            ),
            subtitle: Text('${entry.level} - ${entry.unlockedBadges} badges'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _trendIcon(entry.trend),
                  color: _trendColor(context, entry.trend),
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text('${entry.score}'),
              ],
            ),
            onTap: () =>
                context.push('/groups/$groupId/members/${entry.userId}'),
          ),
      ],
    );
  }

  static Color _podiumColor(int position) {
    if (position == 1) return const Color(0xFFD4AF37);
    if (position == 2) return const Color(0xFF9EA7AD);
    return const Color(0xFFB87333);
  }

  static IconData _trendIcon(String trend) {
    if (trend == 'UP') return Icons.arrow_upward;
    if (trend == 'DOWN') return Icons.arrow_downward;
    return Icons.remove;
  }

  static Color _trendColor(BuildContext context, String trend) {
    if (trend == 'UP') return context.successIconColor;
    if (trend == 'DOWN') return Colors.redAccent;
    return Colors.grey;
  }
}

class PublicMemberProfileScreen extends ConsumerWidget {
  const PublicMemberProfileScreen({
    required this.groupId,
    required this.memberId,
    super.key,
  });

  final int groupId;
  final int memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The public profile intentionally uses the PBL endpoint instead of loading
    // private user settings, so group members only see shareable reputation data.
    final profile = ref.watch(
        publicMemberProfileProvider((groupId: groupId, memberId: memberId)));
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil publico')),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => ErrorView(
          title: 'No se pudo cargar el perfil',
          onRetry: () => ref.invalidate(publicMemberProfileProvider(
              (groupId: groupId, memberId: memberId))),
        ),
        data: (item) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AnimatedSection(
              child: _PublicProfileHeader(profile: item),
            ),
            const SizedBox(height: 16),
            AnimatedSection(
              index: 1,
              child: _PublicProfileStats(profile: item),
            ),
            const SizedBox(height: 16),
            AnimatedSection(
              index: 2,
              child: _PublicProfileBadges(badges: item.badges),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublicProfileHeader extends StatelessWidget {
  const _PublicProfileHeader({required this.profile});

  final PublicMemberProfile profile;

  @override
  Widget build(BuildContext context) {
    final progress = (profile.reputation.score / 100).clamp(0, 1).toDouble();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: context.isDarkMode
              ? const [AppColors.darkSurface, Color(0xFF102F53)]
              : const [AppColors.navy, AppColors.blue],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          RemoteAvatar(
            imageRef: profile.photo,
            fallbackIcon: Icons.person_outline,
            size: 82,
            borderRadius: 41,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.reputation.level,
                  style: TextStyle(color: Colors.white.withOpacity(0.82)),
                ),
                const SizedBox(height: 12),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: AppMotion.slow,
                  curve: AppMotion.curve,
                  builder: (context, value, child) => LinearProgressIndicator(
                    value: value,
                    color: AppColors.lightGreen,
                    backgroundColor: Colors.white.withOpacity(0.18),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.green.withOpacity(0.24),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${profile.reputation.score}',
                  maxLines: 1,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PublicProfileStats extends StatelessWidget {
  const _PublicProfileStats({required this.profile});

  final PublicMemberProfile profile;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resumen', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(profile.reputation.levelDescription),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.65,
              children: [
                MetricCard(
                  label: 'Score',
                  value: '${profile.reputation.score}/100',
                  icon: Icons.trending_up_outlined,
                ),
                MetricCard(
                  label: 'Nivel',
                  value: profile.reputation.level,
                  icon: Icons.workspace_premium_outlined,
                ),
                MetricCard(
                  label: 'Pagos en grupo',
                  value: '${profile.completedPaymentsInGroup}',
                  icon: Icons.verified_outlined,
                ),
                MetricCard(
                  label: 'Badges',
                  value: '${profile.badges.length}',
                  icon: Icons.emoji_events_outlined,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PublicProfileBadges extends StatelessWidget {
  const _PublicProfileBadges({required this.badges});

  final List<PblBadge> badges;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Badges desbloqueados',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (badges.isEmpty)
              const _EmptyProfileState()
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns =
                      MediaQuery.sizeOf(context).width > 700 ? 4 : 2;
                  final itemWidth =
                      (constraints.maxWidth - (columns - 1) * 8) / columns;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final badge in badges)
                        SizedBox(
                          width: itemWidth,
                          child: BadgeMedal(badge: badge, compact: true),
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyProfileState extends StatelessWidget {
  const _EmptyProfileState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.primaryIconContainerColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.emoji_events_outlined, color: context.primaryIconColor),
          const SizedBox(width: 12),
          const Expanded(child: Text('Aun no tiene badges publicos')),
        ],
      ),
    );
  }
}

/// Cabecera del grupo: quien es, de que trata y que tan grande es.
///
/// Antes era la foto y la descripcion sueltas en una fila, sin tarjeta. El
/// nombre vivia solo en la barra superior, asi que la pantalla abria con un
/// parrafo huerfano y no se distinguia de cualquier otra seccion. Aqui la
/// identidad del grupo ocupa el lugar que le corresponde: primero quien es,
/// despues de que trata, y al final su tamano.
class _GroupHeaderCard extends StatelessWidget {
  const _GroupHeaderCard({
    required this.group,
    required this.members,
    required this.expenseCount,
    required this.isAdmin,
  });

  final Group group;

  // Nulos mientras su provider no haya resuelto. La distincion importa: el
  // grupo carga por su cuenta y suele llegar antes que los integrantes y los
  // gastos, asi que una lista vacia aqui significaria "este grupo no tiene a
  // nadie", que de un grupo con creador es falso. Null significa "todavia no
  // se sabe", y eso si se puede representar: omitiendo el dato.
  final List<GroupMember>? members;
  final int? expenseCount;

  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final description = group.description.trim();
    final sizeLabel = _sizeLabel();
    final facepile = members ?? const <GroupMember>[];
    // Sin ningun dato cargado no se dibuja ni el divisor: una franja vacia
    // bajo la descripcion se lee como un error, no como una espera.
    final showFooter = sizeLabel != null || facepile.isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                RemoteAvatar(
                  imageRef: group.groupPhoto,
                  fallbackIcon: Icons.group_outlined,
                  size: 72,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              height: 1.15,
                            ),
                      ),
                      const SizedBox(height: 8),
                      // El rol decide lo que la persona puede hacer aqui
                      // (crear gastos, editar, ver morosos). Decirlo en la
                      // cabecera evita que lo deduzca por que botones faltan.
                      _GroupRoleChip(isAdmin: isAdmin),
                    ],
                  ),
                ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.45,
                      color: context.mutedIconColor,
                    ),
              ),
            ],
            if (showFooter) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (facepile.isNotEmpty) ...[
                    _MemberFacepile(members: facepile),
                    const SizedBox(width: 10),
                  ],
                  if (sizeLabel != null)
                    Expanded(
                      child: Text(
                        sizeLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: context.mutedIconColor,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Resumen de tamano con lo que se sepa hasta el momento.
  ///
  /// Cada mitad se omite por separado mientras su provider no resuelva, en vez
  /// de rellenarse con un cero. Los dos llegan de peticiones distintas, asi que
  /// lo normal es que una este lista antes que la otra: mostrar la que ya se
  /// tiene es mejor que esperar a ambas.
  ///
  /// @return null si no se sabe nada todavia, y entonces no hay nada que pintar
  String? _sizeLabel() {
    final counts = <String>[
      if (members case final list?)
        list.length == 1 ? '1 integrante' : '${list.length} integrantes',
      if (expenseCount case final count?)
        count == 1 ? '1 gasto' : '$count gastos',
    ];
    return counts.isEmpty ? null : counts.join('  ·  ');
  }
}

/// Etiqueta del rol propio dentro del grupo.
class _GroupRoleChip extends StatelessWidget {
  const _GroupRoleChip({required this.isAdmin});

  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final color = isAdmin ? context.successIconColor : context.primaryIconColor;
    final container = isAdmin
        ? context.successIconContainerColor
        : context.primaryIconContainerColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: container,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAdmin ? Icons.shield_outlined : Icons.person_outline,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            isAdmin ? 'Administrador' : 'Integrante',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Las caras del grupo, superpuestas.
///
/// Un numero dice cuantos son; las caras dicen quienes. Se muestran unas pocas
/// y el resto se resume, porque la lista completa ya vive mas abajo.
class _MemberFacepile extends StatelessWidget {
  const _MemberFacepile({required this.members});

  final List<GroupMember> members;

  static const _maxVisible = 4;
  static const _size = 28.0;
  static const _step = 19.0;

  @override
  Widget build(BuildContext context) {
    final visible = members.take(_maxVisible).toList();
    final extra = members.length - visible.length;
    final slots = visible.length + (extra > 0 ? 1 : 0);
    // El borde toma el color de la tarjeta para que las caras se recorten
    // entre si en lugar de pegarse.
    final borderColor =
        context.isDarkMode ? AppColors.darkSurface : Colors.white;

    return SizedBox(
      width: (slots - 1) * _step + _size,
      height: _size,
      child: Stack(
        children: [
          for (var i = 0; i < visible.length; i++)
            Positioned(
              left: i * _step,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor, width: 2),
                ),
                child: RemoteAvatar(
                  imageRef: visible[i].photo,
                  fallbackIcon: Icons.person_outline,
                  size: _size - 4,
                  borderRadius: (_size - 4) / 2,
                ),
              ),
            ),
          if (extra > 0)
            Positioned(
              left: visible.length * _step,
              child: Container(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.mutedIconContainerColor,
                  border: Border.all(color: borderColor, width: 2),
                ),
                child: Center(
                  child: Text(
                    '+$extra',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: context.mutedIconColor,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupSummaryCard extends StatelessWidget {
  const _GroupSummaryCard({required this.summary});

  final GroupSummary summary;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Resumen',
      child: Column(
        children: [
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.35,
            crossAxisSpacing: 8,
            children: [
              MetricCard(
                  label: 'Total', value: formatCurrency(summary.totalExpenses)),
              MetricCard(
                  label: 'Pagado', value: formatCurrency(summary.totalPaid)),
              MetricCard(
                  label: 'Pendiente',
                  value: formatCurrency(summary.totalPending)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: PieChart(
              PieChartData(
                sections: [
                  PieChartSectionData(
                    value: summary.totalPaid,
                    title: 'Pagado',
                    color: context.successIconColor,
                  ),
                  PieChartSectionData(
                    value: summary.totalPending,
                    title: 'Pendiente',
                    color: context.primaryIconColor,
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Quien debe a quien',
                style: Theme.of(context).textTheme.titleSmall),
          ),
          for (final debt in summary.debts)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: context.successIconContainerColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.payments_outlined,
                    color: context.successIconColor),
              ),
              title: Text(debt.name),
              subtitle: const Text('Debe al grupo'),
              trailing: Text(formatCurrency(debt.amount)),
            ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
