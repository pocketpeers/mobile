import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_motion.dart';
import '../../core/app_theme.dart';
import '../../core/bounded_poller.dart';
import '../../core/refresh_on_return.dart';
import '../../core/blockchain_hash_chip.dart';
import '../../core/formatters.dart';
import '../../core/remote_image.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../dashboard/dashboard_screen.dart';

/// Cuantos gastos entran en el resumen del grupo.
///
/// La pantalla de grupo tiene que caber junto al ranking, los integrantes y el
/// resumen: mostrar la lista entera la volvia un scroll interminable donde el
/// gasto de ayer quedaba a diez pantallas del titulo. Aqui van los ultimos y el
/// resto vive en su propia pantalla.
const recentExpensesCount = 3;

/// Tolerancia de centavos al comparar saldos.
///
/// Los montos viajan como double: un gasto pagado completo puede volver con un
/// resto de 0.0000001 y sin esto se mostraria como pendiente.
const _cents = 0.005;

// ---------------------------------------------------------------------------
// Estados visibles
// ---------------------------------------------------------------------------

/// Como se ve un estado: el texto que lee el usuario y el color que lo agrupa.
///
/// Los estados del backend (`PENDING`, `PARTIAL`, `COMPLETED`) se mostraban
/// crudos y en ingles. Traducirlos en un solo lugar evita que cada pantalla
/// invente su propia etiqueta.
class StatusVisual {
  const StatusVisual({
    required this.label,
    required this.color,
    required this.containerColor,
    required this.icon,
  });

  final String label;
  final Color color;
  final Color containerColor;
  final IconData icon;
}

bool isExpenseOverdue(Expense expense) {
  final dueDate = expense.dueDate;
  if (dueDate == null) return false;
  if (expense.remainingAmount <= _cents) return false;
  final today = DateTime.now();
  return dueDate.isBefore(DateTime(today.year, today.month, today.day));
}

StatusVisual expenseStatusVisual(BuildContext context, Expense expense) {
  if (!expense.isActive || expense.status == 'CANCELLED') {
    return StatusVisual(
      label: 'Anulado',
      color: context.mutedIconColor,
      containerColor: context.mutedIconContainerColor,
      icon: Icons.block_outlined,
    );
  }
  if (expense.status == 'COMPLETED' || expense.remainingAmount <= _cents) {
    return StatusVisual(
      label: 'Pagado',
      color: context.successIconColor,
      containerColor: context.successIconContainerColor,
      icon: Icons.verified_outlined,
    );
  }
  if (isExpenseOverdue(expense)) {
    return StatusVisual(
      label: 'Vencido',
      color: context.dangerIconColor,
      containerColor: context.dangerIconContainerColor,
      icon: Icons.warning_amber_rounded,
    );
  }
  if (expense.paidAmount > _cents) {
    return StatusVisual(
      label: 'En curso',
      color: context.primaryIconColor,
      containerColor: context.primaryIconContainerColor,
      icon: Icons.timelapse_outlined,
    );
  }
  return StatusVisual(
    label: 'Pendiente',
    color: context.warningIconColor,
    containerColor: context.warningIconContainerColor,
    icon: Icons.schedule_outlined,
  );
}

StatusVisual paymentStatusVisual(BuildContext context, Payment payment) {
  if (payment.confirmed && payment.remaining <= _cents) {
    return StatusVisual(
      label: 'Pagado',
      color: context.successIconColor,
      containerColor: context.successIconContainerColor,
      icon: Icons.verified_outlined,
    );
  }
  if (!payment.confirmed && payment.amountPaid > _cents) {
    // El deudor ya abono, pero el dueno del gasto todavia no da el visto bueno:
    // para el que debe es plata que ya salio, asi que no puede decir solo
    // "pendiente".
    return StatusVisual(
      label:
          payment.remaining <= _cents ? 'Por confirmar' : 'Abono sin confirmar',
      color: context.warningIconColor,
      containerColor: context.warningIconContainerColor,
      icon: Icons.hourglass_bottom_outlined,
    );
  }
  if (payment.amountPaid > _cents) {
    return StatusVisual(
      label: 'Abono parcial',
      color: context.primaryIconColor,
      containerColor: context.primaryIconContainerColor,
      icon: Icons.timelapse_outlined,
    );
  }
  return StatusVisual(
    label: 'Pendiente',
    color: context.mutedIconColor,
    containerColor: context.mutedIconContainerColor,
    icon: Icons.schedule_outlined,
  );
}

/// Etiqueta compacta de estado.
class StatusChip extends StatelessWidget {
  const StatusChip({required this.visual, this.dense = false, super.key});

  final StatusVisual visual;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: visual.containerColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(visual.icon, size: dense ? 13 : 15, color: visual.color),
          const SizedBox(width: 5),
          Text(
            visual.label,
            style: TextStyle(
              color: visual.color,
              fontWeight: FontWeight.w800,
              fontSize: dense ? 11 : 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Aviso de lista vacia, con el mismo aire que los del panel.
class EmptyHint extends StatelessWidget {
  const EmptyHint({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
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

// ---------------------------------------------------------------------------
// Tarjeta de gasto
// ---------------------------------------------------------------------------

/// Un gasto como tarjeta: monto, vencimiento, estado y avance del pago.
///
/// Es la misma pieza en el resumen del grupo y en la lista completa, para que
/// el gasto que el usuario reconocio en una pantalla se vea igual en la otra.
class ExpenseCard extends StatelessWidget {
  const ExpenseCard({
    required this.expense,
    required this.onTap,
    this.onCancel,
    super.key,
  });

  final Expense expense;
  final VoidCallback onTap;

  /// Anular el gasto. Solo lo recibe el administrador del grupo.
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final visual = expenseStatusVisual(context, expense);
    final progress = expense.amount <= 0
        ? 0.0
        : (expense.paidAmount / expense.amount).clamp(0.0, 1.0);
    final overdue = isExpenseOverdue(expense);
    final mutedStyle = TextStyle(fontSize: 12, color: context.mutedIconColor);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: visual.containerColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.receipt_long_outlined,
                        color: visual.color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expense.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              overdue
                                  ? Icons.event_busy_outlined
                                  : Icons.event_outlined,
                              size: 14,
                              color: overdue
                                  ? context.dangerIconColor
                                  : context.mutedIconColor,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                overdue
                                    ? 'Vencio ${formatDate(expense.dueDate)}'
                                    : 'Vence ${formatDate(expense.dueDate)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: mutedStyle.copyWith(
                                  color: overdue
                                      ? context.dangerIconColor
                                      : context.mutedIconColor,
                                  fontWeight: overdue
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatCurrency(expense.amount),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text('${(progress * 100).round()}% pagado',
                          style: mutedStyle),
                    ],
                  ),
                  if (onCancel != null)
                    PopupMenuButton<String>(
                      tooltip: 'Opciones del gasto',
                      icon:
                          Icon(Icons.more_vert, color: context.mutedIconColor),
                      onSelected: (_) => onCancel!(),
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'cancel',
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.block_outlined),
                            title: Text('Anular gasto'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: visual.color.withOpacity(0.14),
                  valueColor: AlwaysStoppedAnimation<Color>(visual.color),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  StatusChip(visual: visual, dense: true),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      expense.remainingAmount <= _cents
                          ? 'Sin saldo pendiente'
                          : 'Falta ${formatCurrency(expense.remainingAmount)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: mutedStyle,
                    ),
                  ),
                  BlockchainHashChip(
                    hash: expense.blockchainHash,
                    anchoredAt: expense.anchoredAt,
                    compact: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Anular un gasto
// ---------------------------------------------------------------------------

/// Pide confirmacion y anula el gasto.
///
/// Vive aqui y no en la pantalla de grupo porque ahora se puede anular desde
/// dos lugares: la lista completa y el detalle del gasto.
Future<void> confirmCancelExpense(
  BuildContext context,
  WidgetRef ref,
  Expense expense,
) async {
  final confirmed = await showAppDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Anular gasto'),
      content: Text(
        '¿Estás seguro que deseas anular el gasto "${expense.name}"? Esto no se puede deshacer.',
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: () => context.pop(true),
          icon: const Icon(Icons.block_outlined),
          label: const Text('Anular'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    await ref.read(apiProvider).cancelExpense(expense.id);
    invalidateGroup(ref, expense.groupId);
    ref.invalidate(expenseProvider(expense.id));
    ref.invalidate(expensePaymentsProvider(expense.id));
    if (!context.mounted) return;
    showAchievementSnackBar(
      context,
      title: 'Gasto anulado',
      message: 'Ya no aparecera en los gastos activos',
      icon: Icons.block_outlined,
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No se pudo anular el gasto: $error')),
    );
  }
}

/// Ordena los gastos del mas nuevo al mas viejo.
///
/// El backend no garantiza orden y el id es lo unico siempre presente, asi que
/// sirve de desempate cuando dos gastos comparten fecha de creacion.
List<Expense> sortExpensesByRecency(List<Expense> expenses) {
  final sorted = [...expenses];
  sorted.sort((a, b) {
    final aDate = a.createdAt;
    final bDate = b.createdAt;
    if (aDate != null && bDate != null && aDate != bDate) {
      return bDate.compareTo(aDate);
    }
    return b.id.compareTo(a.id);
  });
  return sorted;
}

// ---------------------------------------------------------------------------
// Lista completa de gastos
// ---------------------------------------------------------------------------

enum _ExpenseFilter { todos, pendientes, vencidos, pagados }

extension on _ExpenseFilter {
  String get label => switch (this) {
        _ExpenseFilter.todos => 'Todos',
        _ExpenseFilter.pendientes => 'Pendientes',
        _ExpenseFilter.vencidos => 'Vencidos',
        _ExpenseFilter.pagados => 'Pagados',
      };

  bool matches(Expense expense) => switch (this) {
        _ExpenseFilter.todos => true,
        _ExpenseFilter.pendientes => expense.remainingAmount > _cents,
        _ExpenseFilter.vencidos => isExpenseOverdue(expense),
        _ExpenseFilter.pagados => expense.remainingAmount <= _cents,
      };
}

class GroupExpensesScreen extends ConsumerStatefulWidget {
  const GroupExpensesScreen({required this.groupId, super.key});

  final int groupId;

  @override
  ConsumerState<GroupExpensesScreen> createState() =>
      _GroupExpensesScreenState();
}

class _GroupExpensesScreenState extends ConsumerState<GroupExpensesScreen>
    with RefreshOnReturn {
  /// Al volver del detalle de un gasto, recarga la lista.
  @override
  void onReturnToScreen() => invalidateGroup(ref, widget.groupId);

  final _search = TextEditingController();
  var _filter = _ExpenseFilter.todos;
  var _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expenses = ref.watch(groupExpensesProvider(widget.groupId));
    final session = ref.watch(authControllerProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gastos'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(112),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                TextField(
                  controller: _search,
                  onChanged: (value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Buscar gasto',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpiar',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _search.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _ExpenseFilter.values.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final filter = _ExpenseFilter.values[index];
                      return ChoiceChip(
                        label: Text(filter.label),
                        selected: _filter == filter,
                        onSelected: (_) => setState(() => _filter = filter),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      // Cualquier integrante del grupo puede registrar un gasto, no solo quien
      // lo administra. La reputación se construye siendo deudor de otro: si
      // una sola persona origina las obligaciones, esa persona no acumula
      // historial y las demás comparten una única contraparte.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/groups/${widget.groupId}/expenses/new'),
        icon: const Icon(Icons.add_card_outlined),
        label: const Text('Gasto'),
      ),
      body: expenses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => ErrorView(
          title: 'No se pudieron cargar los gastos',
          onRetry: () => ref.invalidate(groupExpensesProvider(widget.groupId)),
        ),
        data: (items) {
          final visible = sortExpensesByRecency(items)
              .where(_filter.matches)
              .where((expense) =>
                  _query.isEmpty || expense.name.toLowerCase().contains(_query))
              .toList();
          final total =
              visible.fold<double>(0, (sum, item) => sum + item.amount);
          final pending = visible.fold<double>(
              0, (sum, item) => sum + item.remainingAmount);

          return RefreshIndicator(
            onRefresh: () async => invalidateGroup(ref, widget.groupId),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                if (items.isNotEmpty) ...[
                  Row(
                    children: [
                      Expanded(
                        child: MetricCard(
                          label: visible.length == 1
                              ? '1 gasto'
                              : '${visible.length} gastos',
                          value: formatCurrency(total),
                          icon: Icons.receipt_long_outlined,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: MetricCard(
                          label: 'Pendiente',
                          value: formatCurrency(pending),
                          icon: Icons.schedule_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                if (visible.isEmpty)
                  EmptyHint(
                    icon: Icons.receipt_long_outlined,
                    title: items.isEmpty ? 'Sin gastos' : 'Nada con ese filtro',
                    message: items.isEmpty
                        ? 'Cuando el grupo registre un gasto lo veras aqui.'
                        : 'Prueba con otro filtro o limpia la busqueda.',
                  )
                else
                  for (var index = 0; index < visible.length; index++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AnimatedSection(
                        index: index,
                        child: ExpenseCard(
                          expense: visible[index],
                          onTap: () => context.push(
                            '/groups/${widget.groupId}/expenses/${visible[index].id}',
                          ),
                          // Anular lo decide quien creó el gasto, no quien
                          // administra el grupo: es el mismo criterio que usa
                          // el backend, y el mismo que para confirmar los
                          // pagos. Ofrecer el botón a quien el servidor va a
                          // rechazar solo produce un error incomprensible.
                          onCancel: visible[index].userId == session?.id
                              ? () => confirmCancelExpense(
                                    context,
                                    ref,
                                    visible[index],
                                  )
                              : null,
                        ),
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detalle de un gasto
// ---------------------------------------------------------------------------

class ExpenseDetailScreen extends ConsumerStatefulWidget {
  const ExpenseDetailScreen({
    required this.groupId,
    required this.expenseId,
    super.key,
  });

  final int groupId;
  final int expenseId;

  @override
  ConsumerState<ExpenseDetailScreen> createState() =>
      _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends ConsumerState<ExpenseDetailScreen>
    with RefreshOnReturn {
  /// Al volver del detalle de una deuda, relee el gasto y sus pagos.
  @override
  void onReturnToScreen() {
    _refreshFromServer();
    ref.invalidate(expenseReceiptsProvider(widget.expenseId));
  }

  /// Recarga el gasto unas pocas veces mientras la pantalla esta abierta.
  ///
  /// No es solo por el hash: los pagos de este gasto los registran otras
  /// personas desde sus telefonos, y sin esto quien mira el detalle no ve
  /// llegar ni un abono ni una confirmacion hasta salir y volver a entrar.
  late final BoundedPoller _poller = BoundedPoller(onTick: _refreshFromServer);

  @override
  void initState() {
    super.initState();
    _poller.start();
  }

  @override
  void dispose() {
    _poller.dispose();
    super.dispose();
  }

  /// Relee del servidor lo que esta pantalla muestra.
  void _refreshFromServer() {
    if (!mounted) return;
    ref.invalidate(expenseProvider(widget.expenseId));
    ref.invalidate(expensePaymentsProvider(widget.expenseId));
  }

  /// Lo que dispara el chip del hash al tocarlo.
  void _refreshBlockchainHashes() {
    _refreshFromServer();
    // Tocar el chip significa que se sigue esperando: la cuenta vuelve a cero.
    _poller.restart();
  }

  @override
  Widget build(BuildContext context) {
    final expense = ref.watch(expenseProvider(widget.expenseId));
    final payments = ref.watch(expensePaymentsProvider(widget.expenseId));
    final receipts = ref.watch(expenseReceiptsProvider(widget.expenseId));
    final members = ref.watch(groupMembersProvider(widget.groupId));
    final session = ref.watch(authControllerProvider).valueOrNull;
    final item = expense.valueOrNull;
    // Anular es potestad del creador del gasto, igual que confirmarlo. Antes se
    // preguntaba por el administrador del grupo, que desde que cualquier
    // miembro puede crear gastos ya no es quien manda sobre ellos.
    final isExpenseCreator = item != null && item.userId == session?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gasto'),
        actions: [
          if (isExpenseCreator && item.isActive)
            IconButton(
              tooltip: 'Anular gasto',
              icon: const Icon(Icons.block_outlined),
              onPressed: () async {
                await confirmCancelExpense(context, ref, item);
                // Anulado, el gasto sale de las listas: quedarse en su detalle
                // dejaria al usuario mirando algo que ya no existe.
                if (context.mounted && context.canPop()) context.pop();
              },
            ),
        ],
      ),
      body: expense.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => ErrorView(
          title: 'No se pudo cargar el gasto',
          onRetry: () => ref.invalidate(expenseProvider(widget.expenseId)),
        ),
        data: (expenseItem) => RefreshIndicator(
          onRefresh: () async {
            _refreshFromServer();
            ref.invalidate(expenseReceiptsProvider(widget.expenseId));
            // Pedir datos a mano significa que se sigue esperando algo.
            _poller.restart();
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AnimatedSection(
                child: _ExpenseHeaderCard(
                  expense: expenseItem,
                  onRefreshHash: _refreshBlockchainHashes,
                ),
              ),
              // El recibo va antes del reparto: quien abre el gasto porque le
              // toca pagar algo primero quiere ver el comprobante y despues
              // cuanto le corresponde.
              ...receipts.maybeWhen(
                data: (items) => items.isEmpty
                    ? const <Widget>[]
                    : <Widget>[
                        const SizedBox(height: 16),
                        AnimatedSection(
                          index: 1,
                          child: _ExpenseReceiptsCard(receipts: items),
                        ),
                      ],
                // Un recibo que no carga no puede tapar las deudas, que son el
                // motivo principal de entrar aqui.
                orElse: () => const <Widget>[],
              ),
              const SizedBox(height: 16),
              AnimatedSection(
                index: 2,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Deudas',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            if (payments.valueOrNull != null)
                              Text(
                                payments.valueOrNull!.length == 1
                                    ? '1 persona'
                                    : '${payments.valueOrNull!.length} personas',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.mutedIconColor,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Toca una deuda para ver la transaccion y su evidencia.',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.mutedIconColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        payments.when(
                          loading: () => const LinearProgressIndicator(),
                          error: (error, stackTrace) =>
                              const Text('No se pudieron cargar las deudas'),
                          data: (items) => items.isEmpty
                              ? const EmptyHint(
                                  icon: Icons.people_outline,
                                  title: 'Sin deudas',
                                  message:
                                      'Este gasto todavia no tiene reparto entre los integrantes.',
                                )
                              : Column(
                                  children: [
                                    for (final payment
                                        in _sortDebts(items, session?.id))
                                      _DebtRow(
                                        payment: payment,
                                        members:
                                            members.valueOrNull ?? const [],
                                        isMine: payment.userId == session?.id,
                                      ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Primero la deuda propia, despues las que siguen abiertas.
  ///
  /// Quien entra al gasto casi siempre viene a ver cuanto le toca: dejar su
  /// fila arriba ahorra buscarse en una lista de diez nombres.
  List<Payment> _sortDebts(List<Payment> payments, int? myUserId) {
    final sorted = [...payments];
    sorted.sort((a, b) {
      if (myUserId != null &&
          (a.userId == myUserId) != (b.userId == myUserId)) {
        return a.userId == myUserId ? -1 : 1;
      }
      final aSettled = a.confirmed && a.remaining <= _cents;
      final bSettled = b.confirmed && b.remaining <= _cents;
      if (aSettled != bSettled) return aSettled ? 1 : -1;
      return b.remaining.compareTo(a.remaining);
    });
    return sorted;
  }

}

class _ExpenseHeaderCard extends StatelessWidget {
  const _ExpenseHeaderCard({required this.expense, this.onRefreshHash});

  final Expense expense;
  final VoidCallback? onRefreshHash;

  @override
  Widget build(BuildContext context) {
    final visual = expenseStatusVisual(context, expense);
    final overdue = isExpenseOverdue(expense);
    final progress = expense.amount <= 0
        ? 0.0
        : (expense.paidAmount / expense.amount).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(expense.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Monto total del gasto',
              style: TextStyle(fontSize: 12, color: context.mutedIconColor),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatCurrency(expense.amount),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusChip(visual: visual),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: overdue
                        ? context.dangerIconContainerColor
                        : context.primaryIconContainerColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        overdue
                            ? Icons.event_busy_outlined
                            : Icons.event_outlined,
                        size: 15,
                        color: overdue
                            ? context.dangerIconColor
                            : context.primaryIconColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        overdue
                            ? 'Vencio ${formatDate(expense.dueDate)}'
                            : 'Vence ${formatDate(expense.dueDate)}',
                        style: TextStyle(
                          color: overdue
                              ? context.dangerIconColor
                              : context.primaryIconColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                BlockchainHashChip(
                  hash: expense.blockchainHash,
                  anchoredAt: expense.anchoredAt,
                  onRefresh: onRefreshHash,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: visual.color.withOpacity(0.14),
                valueColor: AlwaysStoppedAnimation<Color>(visual.color),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TotalTile(
                    label: 'Pagado',
                    value: expense.paidAmount,
                    color: context.successIconColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TotalTile(
                    label: 'Pendiente',
                    value: expense.remainingAmount,
                    color: expense.remainingAmount <= _cents
                        ? context.mutedIconColor
                        : (overdue
                            ? context.dangerIconColor
                            : context.warningIconColor),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Comprobantes escaneados del gasto.
///
/// Hasta ahora el recibo solo existia en el formulario de creacion: se leia con
/// OCR, rellenaba los campos y desaparecia. Quien quedaba con una deuda tenia
/// que creerle al monto sin poder ver de donde salia. Mostrarlo aqui deja el
/// comprobante al alcance de todos los asignados al gasto.
class _ExpenseReceiptsCard extends StatelessWidget {
  const _ExpenseReceiptsCard({required this.receipts});

  final List<Receipt> receipts;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    receipts.length == 1 ? 'Recibo' : 'Recibos',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (receipts.length > 1)
                  Text(
                    '${receipts.length} comprobantes',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.mutedIconColor,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Comprobante leido con OCR al registrar el gasto. Toca la imagen para verla completa.',
              style: TextStyle(fontSize: 12, color: context.mutedIconColor),
            ),
            const SizedBox(height: 12),
            for (var index = 0; index < receipts.length; index++)
              _ReceiptRow(
                receipt: receipts[index],
                isLast: index == receipts.length - 1,
              ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.receipt, required this.isLast});

  final Receipt receipt;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final url = remoteImageUrl(receipt.imagePath);
    final title = receipt.name.trim().isEmpty ? 'Recibo' : receipt.name.trim();
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            // Sin imagen no hay nada que ampliar: el toque no hace nada en vez
            // de abrir un dialogo vacio.
            onTap: url == null ? null : () => _openFullImage(context, url),
            child: RemoteAvatar(
              imageRef: receipt.imagePath,
              fallbackIcon: Icons.receipt_long_outlined,
              size: 64,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text(formatCurrency(receipt.amount))),
                    if (receipt.issueDate != null)
                      Chip(label: Text(formatDate(receipt.issueDate))),
                    if (receipt.receiptNumber.trim().isNotEmpty)
                      Chip(label: Text('N ${receipt.receiptNumber.trim()}')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openFullImage(BuildContext context, String url) {
    showAppDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: InteractiveViewer(
            // El texto de un recibo es chico: sin zoom la vista ampliada sigue
            // sin dejar leer el detalle de los items.
            maxScale: 4,
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No se pudo cargar la imagen del recibo'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TotalTile extends StatelessWidget {
  const _TotalTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(context.isDarkMode ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: context.mutedIconColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatCurrency(value),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Una deuda del gasto: quien debe, cuanto y en que estado va.
class _DebtRow extends StatelessWidget {
  const _DebtRow({
    required this.payment,
    required this.members,
    required this.isMine,
  });

  final Payment payment;
  final List<GroupMember> members;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final visual = paymentStatusVisual(context, payment);
    final member = members.where((item) => item.userId == payment.userId);
    // La descripcion del backend viene como "Gasto - Nombre": si el integrante
    // ya no esta en el grupo, es lo unico que queda para identificarlo.
    final name = member.isNotEmpty
        ? member.first.fullName
        : (payment.description.contains(' - ')
            ? payment.description.split(' - ').last
            : payment.description);
    final photo = member.isNotEmpty ? member.first.photo : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.push('/payments/${payment.id}'),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isMine
                  ? visual.color.withOpacity(0.42)
                  : (context.isDarkMode ? AppColors.darkLine : AppColors.line),
            ),
            color: isMine ? visual.containerColor.withOpacity(0.45) : null,
          ),
          child: Row(
            children: [
              RemoteAvatar(
                imageRef: photo,
                fallbackIcon: Icons.person_outline,
                size: 40,
                borderRadius: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (isMine) ...[
                          const SizedBox(width: 6),
                          Text(
                            '(tú)',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.mutedIconColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusChip(visual: visual, dense: true),
                        BlockchainHashChip(
                          hash: payment.blockchainHash,
                          anchoredAt: payment.anchoredAt,
                          compact: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatCurrency(payment.amount),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  if (payment.remaining > _cents && payment.amountPaid > _cents)
                    Text(
                      'Falta ${formatCurrency(payment.remaining)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.mutedIconColor,
                      ),
                    ),
                ],
              ),
              Icon(Icons.chevron_right, color: context.mutedIconColor),
            ],
          ),
        ),
      ),
    );
  }
}
