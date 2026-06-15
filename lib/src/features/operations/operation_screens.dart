import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../data/calculations.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../dashboard/dashboard_screen.dart';

class CreateExpenseScreen extends ConsumerStatefulWidget {
  const CreateExpenseScreen({required this.groupId, super.key});

  final int groupId;

  @override
  ConsumerState<CreateExpenseScreen> createState() => _CreateExpenseScreenState();
}

class _CreateExpenseScreenState extends ConsumerState<CreateExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _customAmounts = <int, TextEditingController>{};
  var _splitMode = SplitMode.equal;
  var _dueDate = DateTime.now().add(const Duration(days: 7));
  var _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    for (final controller in _customAmounts.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(groupMembersProvider(widget.groupId));
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo gasto')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Descripcion'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amount,
              decoration: const InputDecoration(labelText: 'Monto'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: _positiveAmount,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined, color: AppColors.blue),
              title: const Text('Fecha limite'),
              subtitle: Text(inputDateFormatter.format(_dueDate)),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: _pickDate,
            ),
            const SizedBox(height: 12),
            SegmentedButton<SplitMode>(
              segments: const [
                ButtonSegment(
                  value: SplitMode.equal,
                  icon: Icon(Icons.balance_outlined),
                  label: Text('Igual'),
                ),
                ButtonSegment(
                  value: SplitMode.custom,
                  icon: Icon(Icons.tune_outlined),
                  label: Text('Personalizado'),
                ),
              ],
              selected: {_splitMode},
              onSelectionChanged: (value) => setState(() => _splitMode = value.first),
            ),
            const SizedBox(height: 16),
            members.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, stackTrace) => const Text('No se pudieron cargar integrantes'),
              data: (items) => _SplitEditor(
                members: items,
                amount: _parsedAmount,
                mode: _splitMode,
                controllers: _customAmounts,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : () => _save(members.valueOrNull ?? const []),
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Registrar gasto'),
            ),
          ],
        ),
      ),
    );
  }

  double get _parsedAmount => double.tryParse(_amount.text.replaceAll(',', '.')) ?? 0;

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Campo requerido';
    return null;
  }

  String? _positiveAmount(String? value) {
    final amount = double.tryParse((value ?? '').replaceAll(',', '.')) ?? 0;
    if (amount <= 0) return 'Ingresa un monto mayor a cero';
    return null;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      initialDate: _dueDate,
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save(List<GroupMember> members) async {
    if (!_formKey.currentState!.validate() || members.isEmpty) return;
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) return;
    final amount = _parsedAmount;
    final splits = _splitMode == SplitMode.equal
        ? equalSplit(amount: amount, members: members)
        : members
            .map(
              (member) => SplitDraft(
                userId: member.userId,
                fullName: member.fullName,
                amount: double.tryParse(
                      (_customAmounts[member.userId]?.text ?? '').replaceAll(',', '.'),
                    ) ??
                    0,
              ),
            )
            .toList();

    if (!customSplitMatches(amount, splits.map((item) => item.amount))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La suma de divisiones debe coincidir con el gasto')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final expense = await ref.read(apiProvider).createExpense(
            name: _name.text.trim(),
            amount: amount,
            userId: session.id,
            groupId: widget.groupId,
            dueDate: _dueDate,
          );
      for (final split in splits.where((item) => item.amount > 0)) {
        await ref.read(apiProvider).createPayment(
              description: '${_name.text.trim()} - ${split.fullName}',
              amount: split.amount,
              userId: split.userId,
              expenseId: expense.id,
            );
      }
      invalidateGroup(ref, widget.groupId);
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

enum SplitMode { equal, custom }

class _SplitEditor extends StatelessWidget {
  const _SplitEditor({
    required this.members,
    required this.amount,
    required this.mode,
    required this.controllers,
  });

  final List<GroupMember> members;
  final double amount;
  final SplitMode mode;
  final Map<int, TextEditingController> controllers;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) return const Text('No hay integrantes para dividir el gasto');
    final equal = equalSplit(amount: amount, members: members);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Division del gasto', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final member in members)
              mode == SplitMode.equal
                  ? ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(member.fullName),
                      trailing: Text(formatCurrency(
                        equal.firstWhere((item) => item.userId == member.userId).amount,
                      )),
                    )
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextFormField(
                        controller: controllers.putIfAbsent(
                          member.userId,
                          () => TextEditingController(),
                        ),
                        decoration: InputDecoration(labelText: member.fullName),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
          ],
        ),
      ),
    );
  }
}

class PaymentDetailScreen extends ConsumerStatefulWidget {
  const PaymentDetailScreen({required this.paymentId, super.key});

  final int paymentId;

  @override
  ConsumerState<PaymentDetailScreen> createState() => _PaymentDetailScreenState();
}

class _PaymentDetailScreenState extends ConsumerState<PaymentDetailScreen> {
  final _amount = TextEditingController();
  final _picker = ImagePicker();
  XFile? _evidence;
  var _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final payment = ref.watch(paymentProvider(widget.paymentId));
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de transaccion')),
      body: payment.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => ErrorView(
          title: 'No se pudo cargar el pago',
          onRetry: () => ref.invalidate(paymentProvider(widget.paymentId)),
        ),
        data: (item) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.description, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    _StatusPill(status: item.status),
                    const SizedBox(height: 16),
                    _PaymentRows(payment: item),
                    Text('Hash blockchain: pendiente de backend'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amount,
              decoration: const InputDecoration(labelText: 'Abono'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickEvidence,
              icon: const Icon(Icons.image_outlined),
              label: Text(_evidence == null ? 'Cargar evidencia' : _evidence!.name),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _registerPayment,
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Registrar abono'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickEvidence() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _evidence = image);
  }

  Future<void> _registerPayment() async {
    final value = double.tryParse(_amount.text.replaceAll(',', '.')) ?? 0;
    if (value <= 0) return;
    setState(() => _saving = true);
    try {
      var photo = '';
      if (_evidence != null) {
        photo = (await ref.read(apiProvider).uploadImage(_evidence!.path)).imageId;
      }
      await ref.read(apiProvider).makePayment(
            paymentId: widget.paymentId,
            amount: value,
            photo: photo,
          );
      ref.invalidate(paymentProvider(widget.paymentId));
      ref.invalidate(dashboardSummaryProvider);
      ref.invalidate(myReputationProvider);
      ref.invalidate(myBadgesProvider);
      ref.invalidate(myReputationHistoryProvider);
      _amount.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Abono registrado')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  final _search = TextEditingController();
  List<Expense>? _results;
  var _searching = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(dashboardSummaryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Reportes')),
      body: dashboard.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => ErrorView(
          title: 'No se pudieron cargar reportes',
          onRetry: () => ref.invalidate(dashboardSummaryProvider),
        ),
        data: (summary) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Buscar gasto', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _search,
                            decoration: const InputDecoration(
                              labelText: 'Nombre exacto del gasto',
                              prefixIcon: Icon(Icons.search),
                            ),
                            onSubmitted: (_) => _searchExpenses(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _searching ? null : _searchExpenses,
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
                    if (_results != null) ...[
                      const SizedBox(height: 12),
                      if (_results!.isEmpty)
                        const Text('No se encontraron resultados para la busqueda')
                      else
                        for (final expense in _results!)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.receipt_long_outlined),
                            title: Text(expense.name),
                            subtitle: Text('Vence ${formatDate(expense.dueDate)}'),
                            trailing: Text(formatCurrency(expense.amount)),
                          ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Informe detallado', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Text('Gasto total: ${formatCurrency(summary.totalExpenses)}'),
                    Text('Pagado: ${formatCurrency(summary.totalPaid)}'),
                    Text('Pendiente: ${formatCurrency(summary.totalPending)}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Distribucion', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 220,
                      child: PieChart(
                        PieChartData(
                          sections: [
                            PieChartSectionData(
                              value: summary.totalPaid,
                              title: 'Pagado',
                              color: AppColors.green,
                            ),
                            PieChartSectionData(
                              value: summary.totalPending,
                              title: 'Pendiente',
                              color: AppColors.blue,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Transacciones', style: Theme.of(context).textTheme.titleMedium),
                    for (final payment in summary.recentPayments)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.mist,
                          foregroundColor: AppColors.green,
                          child: Icon(Icons.swap_horiz_outlined),
                        ),
                        title: Text(payment.description),
                        subtitle: Text(payment.status),
                        trailing: Text(formatCurrency(payment.amountPaid)),
                        onTap: () => context.push('/payments/${payment.id}'),
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

  Future<void> _searchExpenses() async {
    final query = _search.text.trim();
    if (query.isEmpty) {
      setState(() => _results = null);
      return;
    }
    setState(() => _searching = true);
    try {
      final result = await ref.read(apiProvider).searchExpenses(query);
      if (mounted) setState(() => _results = result);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.lightGreen : AppColors.green).withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: isDark ? AppColors.lightGreen : AppColors.green,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PaymentRows extends StatelessWidget {
  const _PaymentRows({required this.payment});

  final Payment payment;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AmountRow(label: 'Monto', value: payment.amount),
        _AmountRow(label: 'Pagado', value: payment.amountPaid),
        _AmountRow(label: 'Pendiente', value: payment.remaining),
      ],
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isDark
                    ? Colors.white.withOpacity(0.66)
                    : AppColors.navy.withOpacity(0.66),
              ),
            ),
          ),
          Text(
            formatCurrency(value),
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.navy,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
