import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../core/image_source_picker.dart';
import '../../core/remote_image.dart';
import '../../core/validators.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../dashboard/dashboard_screen.dart';
import 'join_group_dialog.dart';

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
            onPressed: () => showDialog<void>(
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
                      icon: _searching
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
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
                  for (final group in visibleItems) ...[
                    Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        leading: RemoteAvatar(
                          imageRef: group.groupPhoto,
                          fallbackIcon: Icons.group_outlined,
                          size: 44,
                        ),
                        title: Text(
                          group.name,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(group.description),
                        trailing: Icon(Icons.chevron_right,
                            color: context.successIconColor),
                        onTap: () => context.push('/groups/${group.id}'),
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
  String _groupPhoto = '';
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
              decoration: const InputDecoration(labelText: 'Descripcion'),
              validator: _groupDescription,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                RemoteAvatar(
                  imageRef: _groupPhoto,
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
    if (value!.trim().length < 5) return 'Ingresa al menos 5 caracteres';
    return null;
  }

  Future<void> _pickGroupPhoto() async {
    final image = await pickImageFromCameraOrGallery(context);
    if (image == null) return;
    final uploaded = await ref.read(apiProvider).uploadImage(image.path);
    setState(() => _groupPhoto = uploaded.imageId);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(apiProvider).createGroup(
            name: _name.text.trim(),
            description: _description.text.trim(),
            adminId: session.id,
            groupPhoto: _groupPhoto,
          );
      ref.invalidate(groupsProvider);
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({required this.groupId, super.key});

  final int groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(groupProvider(groupId));
    final members = ref.watch(groupMembersProvider(groupId));
    final expenses = ref.watch(groupExpensesProvider(groupId));
    final summary = ref.watch(groupSummaryProvider(groupId));
    final leaderboard = ref.watch(groupLeaderboardProvider(groupId));
    final session = ref.watch(authControllerProvider).valueOrNull;
    final isAdmin = group.valueOrNull?.adminId == session?.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(group.valueOrNull?.name ?? 'Grupo'),
        actions: [
          IconButton(
            tooltip: 'Invitacion',
            onPressed: () => _showInvitation(context, ref),
            icon: const Icon(Icons.ios_share_outlined),
          ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/groups/$groupId/expenses/new'),
              icon: const Icon(Icons.add_card_outlined),
              label: const Text('Gasto'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async => invalidateGroup(ref, groupId),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            group.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, stackTrace) =>
                  Text('No se pudo cargar el grupo: $error'),
              data: (item) => Row(
                children: [
                  RemoteAvatar(
                    imageRef: item.groupPhoto,
                    fallbackIcon: Icons.group_outlined,
                    size: 56,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(item.description)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            summary.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, stackTrace) =>
                  Text('No se pudo calcular el resumen: $error'),
              data: (item) => _GroupSummaryCard(summary: item),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Ranking',
              child: leaderboard.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, stackTrace) =>
                    const Text('No se pudo cargar el ranking'),
                data: (items) =>
                    _LeaderboardList(groupId: groupId, entries: items),
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Integrantes',
              child: members.when(
                loading: () => const LinearProgressIndicator(),
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
                        onTap: () => showDialog<void>(
                          context: context,
                          builder: (context) => _PublicMemberProfileDialog(
                            groupId: groupId,
                            memberId: member.userId,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Gastos',
              child: expenses.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, stackTrace) =>
                    Text('No se pudieron cargar gastos'),
                data: (items) => items.isEmpty
                    ? const ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Sin gastos'))
                    : Column(
                        children: [
                          for (final expense in items)
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: Text(expense.name),
                              subtitle:
                                  Text('Vence ${formatDate(expense.dueDate)}'),
                              trailing: Text(formatCurrency(expense.amount)),
                              children: [
                                _ExpensePayments(expenseId: expense.id),
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

  Future<void> _showInvitation(BuildContext context, WidgetRef ref) async {
    final token = await ref.read(apiProvider).generateInvitation(groupId);
    if (!context.mounted) return;
    await showDialog<void>(
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
}

class _LeaderboardList extends StatelessWidget {
  const _LeaderboardList({required this.groupId, required this.entries});

  final int groupId;
  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const Text('Sin integrantes para mostrar');
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
                        Text('${entry.score} pts'),
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
            onTap: () => showDialog<void>(
              context: context,
              builder: (context) => _PublicMemberProfileDialog(
                groupId: groupId,
                memberId: entry.userId,
              ),
            ),
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

class _PublicMemberProfileDialog extends ConsumerWidget {
  const _PublicMemberProfileDialog(
      {required this.groupId, required this.memberId});

  final int groupId;
  final int memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(
        publicMemberProfileProvider((groupId: groupId, memberId: memberId)));
    return AlertDialog(
      title: const Text('Perfil publico'),
      content: SizedBox(
        width: 420,
        child: profile.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, stackTrace) =>
              const Text('No se pudo cargar el perfil'),
          data: (item) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  RemoteAvatar(
                    imageRef: item.photo,
                    fallbackIcon: Icons.person_outline,
                    size: 44,
                    borderRadius: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.fullName,
                            style: Theme.of(context).textTheme.titleMedium),
                        Text(
                            '${item.reputation.level} - ${item.reputation.score}/100'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(item.reputation.levelDescription),
              const SizedBox(height: 12),
              Text(
                  'Pagos completados en grupo: ${item.completedPaymentsInGroup}'),
              const SizedBox(height: 12),
              Text('Badges publicos',
                  style: Theme.of(context).textTheme.titleSmall),
              if (item.badges.isEmpty)
                const Text('Sin badges desbloqueados')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final badge in item.badges)
                      Chip(
                        avatar: const Icon(Icons.verified_outlined, size: 18),
                        label: Text(badge.name),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => context.pop(), child: const Text('Cerrar')),
      ],
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

class _ExpensePayments extends ConsumerWidget {
  const _ExpensePayments({required this.expenseId});

  final int expenseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payments = ref.watch(expensePaymentsProvider(expenseId));
    return payments.when(
      loading: () => const LinearProgressIndicator(),
      error: (error, stackTrace) =>
          const ListTile(title: Text('No se cargaron pagos')),
      data: (items) => Column(
        children: [
          for (final payment in items)
            ListTile(
              contentPadding: const EdgeInsets.only(left: 16),
              leading:
                  Icon(Icons.arrow_forward, color: context.primaryIconColor),
              title: Text(payment.description),
              subtitle: Text(payment.confirmed
                  ? payment.status
                  : '${payment.status} - sin confirmar'),
              trailing: Text(formatCurrency(
                  payment.confirmed ? payment.remaining : payment.amount)),
              onTap: () => context.push('/payments/${payment.id}'),
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
