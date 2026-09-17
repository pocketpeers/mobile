import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_motion.dart';
import '../../core/app_theme.dart';
import '../../core/blockchain_hash_chip.dart';
import '../../core/crew.dart';
import '../../core/formatters.dart';
import '../../core/image_source_picker.dart';
import '../../core/remote_image.dart';
import '../../core/skeleton.dart';
import '../../core/validators.dart';
import '../../data/calculations.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../dashboard/dashboard_screen.dart';

class CreateExpenseScreen extends ConsumerStatefulWidget {
  const CreateExpenseScreen({required this.groupId, super.key});

  final int groupId;

  @override
  ConsumerState<CreateExpenseScreen> createState() =>
      _CreateExpenseScreenState();
}

class _CreateExpenseScreenState extends ConsumerState<CreateExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _customAmounts = <int, TextEditingController>{};
  final _selectedMemberIds = <int>{};
  var _splitMode = SplitMode.equal;
  var _dueDate = DateTime.now().add(const Duration(days: 7));
  var _saving = false;
  var _scanningReceipt = false;
  var _selectionTouched = false;
  ReceiptOcr? _ocrReceipt;
  String _receiptImageId = '';

  /// Aviso del backend cuando la boleta leida ya respalda otro gasto.
  ///
  /// Mientras no sea nulo el registro queda bloqueado. El control vive en el
  /// OCR y no en el guardado porque para cuando el guardado falla el gasto y
  /// sus pagos ya existen, y el rechazo del comprobante no los deshace.
  String? _duplicateReceiptMessage;

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.invalidate(groupMembersProvider(widget.groupId)));
  }

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
    final group = ref.watch(groupProvider(widget.groupId));
    final session = ref.watch(authControllerProvider).valueOrNull;
    final isAdmin = group.valueOrNull?.adminId == session?.id;
    final Widget body;
    if (group.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (!isAdmin) {
      body =
          const Center(child: Text('Solo el administrador puede crear gastos'));
    } else {
      body = Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Descripcion'),
              validator: _expenseName,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amount,
              decoration: const InputDecoration(labelText: 'Monto'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: positiveAmountField,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading:
                  Icon(Icons.event_outlined, color: context.primaryIconColor),
              title: const Text('Fecha limite'),
              subtitle: Text(inputDateFormatter.format(_dueDate)),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: _pickDate,
            ),
            const SizedBox(height: 12),
            _ReceiptOcrCard(
              receiptImageId: _receiptImageId,
              receipt: _ocrReceipt,
              scanning: _scanningReceipt,
              onScan: _scanReceipt,
              onClear: _clearReceiptScan,
            ),
            if (_duplicateReceiptMessage != null) ...[
              const SizedBox(height: 12),
              _DuplicateReceiptBanner(
                message: _duplicateReceiptMessage!,
                onReplace: _clearReceiptScan,
              ),
            ],
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
              onSelectionChanged: (value) =>
                  setState(() => _splitMode = value.first),
            ),
            const SizedBox(height: 16),
            members.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, stackTrace) =>
                  const Text('No se pudieron cargar integrantes'),
              data: (items) {
                final selectedIds = _selectedIdsFor(items);
                return _SplitEditor(
                  members: items,
                  selectedMemberIds: selectedIds,
                  amount: _parsedAmount,
                  mode: _splitMode,
                  controllers: _customAmounts,
                  onSelectAll: () => _selectAllMembers(items),
                  onUnselectAll: _unselectAllMembers,
                  onMemberSelectionChanged: _setMemberSelected,
                );
              },
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              // Bloqueado mientras la boleta este marcada como repetida: es el
              // boton que crea el gasto y reparte los pagos de una sola vez.
              onPressed: _saving || _duplicateReceiptMessage != null
                  ? null
                  : () => _save(members.valueOrNull ?? const []),
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
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo gasto')),
      body: body,
    );
  }

  double get _parsedAmount => parseAmount(_amount.text);

  String? _expenseName(String? value) {
    final required = requiredField(value);
    if (required != null) return required;
    if (value!.trim().length < 3) return 'Ingresa al menos 3 caracteres';
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

  Future<void> _scanReceipt() async {
    final image = await pickImageFromCameraOrGallery(context);
    if (image == null) return;
    setState(() => _scanningReceipt = true);
    var uploadedImageId = '';
    try {
      // The receipt image is uploaded first so OCR and the final receipt record
      // can refer to the same backend image id.
      final uploaded = await ref.read(apiProvider).uploadImage(image.path);
      uploadedImageId = uploaded.imageId;
      if (mounted) {
        setState(() => _receiptImageId = uploadedImageId);
      }
      final receipt =
          await ref.read(apiProvider).ocrFromImage(uploaded.imageId);
      if (!mounted) return;

      if (receipt.duplicate) {
        // No se rellena el formulario: esos importes son de un gasto que ya
        // existe, y copiarlos aqui invitaria a registrarlo de nuevo.
        setState(() {
          _receiptImageId = uploadedImageId;
          _ocrReceipt = receipt;
          _duplicateReceiptMessage = receipt.duplicateMessage ??
              'Esta boleta ya esta registrada en otro gasto';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_duplicateReceiptMessage!),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 6),
          ),
        );
        return;
      }

      setState(() {
        _receiptImageId = uploadedImageId;
        _ocrReceipt = receipt;
        _duplicateReceiptMessage = null;
        if (receipt.name.trim().isNotEmpty) {
          _name.text = receipt.name.trim();
        }
        if (receipt.amount > 0) {
          _amount.text = receipt.amount.toStringAsFixed(2);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Datos detectados por OCR')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _receiptImageId = uploadedImageId;
        _ocrReceipt = null;
        _duplicateReceiptMessage = null;
      });
      final isTimeout = error is DioException &&
          (error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout ||
              error.type == DioExceptionType.sendTimeout);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            uploadedImageId.isEmpty
                ? 'No se pudo cargar el recibo'
                : isTimeout
                    ? 'Recibo cargado, pero OCR tardo demasiado. Intenta otra vez.'
                    : 'Recibo cargado, pero no se pudo leer con OCR',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _scanningReceipt = false);
    }
  }

  void _clearReceiptScan() {
    setState(() {
      _receiptImageId = '';
      _ocrReceipt = null;
      _duplicateReceiptMessage = null;
    });
  }

  Future<void> _save(List<GroupMember> members) async {
    if (!_formKey.currentState!.validate() || members.isEmpty) return;
    if (_duplicateReceiptMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_duplicateReceiptMessage!)),
      );
      return;
    }
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) return;
    final group = ref.read(groupProvider(widget.groupId)).valueOrNull;
    if (group?.adminId != session.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Solo el administrador puede crear gastos')),
      );
      return;
    }
    final amount = _parsedAmount;
    final selectedIds = _selectedIdsFor(members);
    final selectedMembers =
        members.where((member) => selectedIds.contains(member.userId)).toList();
    // Only selected members receive payment obligations; the split validation
    // below makes sure those obligations still add up to the expense total.
    if (selectedMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos un integrante')),
      );
      return;
    }
    final splits = _splitMode == SplitMode.equal
        ? equalSplit(amount: amount, members: selectedMembers)
        : selectedMembers
            .map(
              (member) => SplitDraft(
                userId: member.userId,
                fullName: member.fullName,
                photo: member.photo,
                amount: parseAmount(_customAmounts[member.userId]?.text ?? ''),
              ),
            )
            .toList();

    if (splits.any((split) => split.amount <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Cada integrante seleccionado debe tener un monto mayor a cero')),
      );
      return;
    }

    if (!customSplitMatches(amount, splits.map((item) => item.amount))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('La suma de divisiones debe coincidir con el gasto')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final expense = await ref.read(apiProvider).createExpenseWithPayments(
            name: _name.text.trim(),
            amount: amount,
            userId: session.id,
            groupId: widget.groupId,
            dueDate: _dueDate,
            splits: splits,
          );
      final receiptError = await _attachReceiptToExpense(expense, amount);
      invalidateGroup(ref, widget.groupId);
      if (mounted) {
        // Un solo mensaje, no dos. Antes el fallo del comprobante mostraba su
        // aviso y acto seguido salia "Gasto creado", asi que la pantalla se
        // contradecia a si misma en el caso que mas importa entender.
        if (receiptError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(receiptError),
              backgroundColor: Theme.of(context).colorScheme.error,
              duration: const Duration(seconds: 6),
            ),
          );
        } else {
          showAchievementSnackBar(
            context,
            title: 'Gasto creado',
            message: 'Se generaron los pagos para el grupo',
            icon: Icons.receipt_long_outlined,
          );
        }
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Adjunta el comprobante y devuelve el error si no se pudo, o null si fue
  /// bien o si no habia nada que adjuntar.
  ///
  /// Devuelve en vez de avisar porque quien llama es el unico que sabe que mas
  /// va a decir: mostrar el fallo aqui dejaba al guardado anunciando exito
  /// justo despues.
  Future<String?> _attachReceiptToExpense(
      Expense expense, double expenseAmount) async {
    if (_receiptImageId.isEmpty) return null;
    final receipt = _ocrReceipt;
    final receiptAmount =
        receipt != null && receipt.amount > 0 ? receipt.amount : expenseAmount;
    // Do not attach OCR data that claims a larger amount than the expense the
    // user just confirmed.
    if (receiptAmount > expenseAmount) return null;
    try {
      await ref.read(apiProvider).createExpenseReceipt(
            expenseId: expense.id,
            name: (receipt?.name.trim().isNotEmpty ?? false)
                ? receipt!.name.trim()
                : expense.name,
            amount: receiptAmount,
            issueDate: receipt?.issueDate ?? DateTime.now(),
            receiptNumber: receipt?.receiptNumber ?? '',
            issuerRuc: receipt?.issuerRuc ?? '',
            imagePath: _receiptImageId,
          );
      return null;
    } catch (error) {
      return _receiptErrorMessage(error);
    }
  }

  /// El 409 merece su propio texto.
  ///
  /// El backend rechaza el comprobante cuando esa misma boleta ya respalda otro
  /// gasto, y el mensaje que manda dice cual. Mostrar "no se pudo adjuntar" en
  /// ese caso ocultaria justamente lo que el usuario necesita saber, y quien
  /// reuso la boleta sin querer no tendria como darse cuenta.
  String _receiptErrorMessage(Object error) {
    if (error is DioException && error.response?.statusCode == 409) {
      final body = error.response?.data;
      if (body is Map && body['message'] is String) {
        return body['message'] as String;
      }
      return 'Esa boleta ya esta registrada en otro gasto';
    }
    return 'El gasto se creo, pero no se pudo adjuntar el recibo';
  }

  Set<int> _selectedIdsFor(List<GroupMember> members) {
    final availableIds = members.map((member) => member.userId).toSet();
    if (!_selectionTouched) return availableIds;
    return _selectedMemberIds.where(availableIds.contains).toSet();
  }

  void _selectAllMembers(List<GroupMember> members) {
    setState(() {
      _selectionTouched = true;
      _selectedMemberIds
        ..clear()
        ..addAll(members.map((member) => member.userId));
    });
  }

  void _unselectAllMembers() {
    setState(() {
      _selectionTouched = true;
      _selectedMemberIds.clear();
    });
  }

  void _setMemberSelected(int userId, bool selected) {
    setState(() {
      _selectionTouched = true;
      if (selected) {
        _selectedMemberIds.add(userId);
      } else {
        _selectedMemberIds.remove(userId);
      }
    });
  }
}

enum SplitMode { equal, custom }

class _ReceiptOcrCard extends StatelessWidget {
  const _ReceiptOcrCard({
    required this.receiptImageId,
    required this.receipt,
    required this.scanning,
    required this.onScan,
    required this.onClear,
  });

  final String receiptImageId;
  final ReceiptOcr? receipt;
  final bool scanning;
  final VoidCallback onScan;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasReceipt = receiptImageId.isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                RemoteAvatar(
                  imageRef: receiptImageId,
                  fallbackIcon: Icons.receipt_long_outlined,
                  size: 52,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('OCR de recibo',
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        hasReceipt
                            ? 'Imagen cargada para este gasto'
                            : 'Carga una imagen para completar datos automaticamente',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (hasReceipt)
                  IconButton(
                    onPressed: scanning ? null : onClear,
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            if (receipt != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (receipt!.name.isNotEmpty)
                    Chip(label: Text(receipt!.name)),
                  if (receipt!.amount > 0)
                    Chip(label: Text(formatCurrency(receipt!.amount))),
                  if (receipt!.issueDate != null)
                    Chip(label: Text(formatDate(receipt!.issueDate))),
                ],
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: scanning ? null : onScan,
              icon: scanning
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.document_scanner_outlined),
              label: Text(scanning ? 'Leyendo recibo' : 'Escanear recibo'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplitEditor extends StatelessWidget {
  const _SplitEditor({
    required this.members,
    required this.selectedMemberIds,
    required this.amount,
    required this.mode,
    required this.controllers,
    required this.onSelectAll,
    required this.onUnselectAll,
    required this.onMemberSelectionChanged,
  });

  final List<GroupMember> members;
  final Set<int> selectedMemberIds;
  final double amount;
  final SplitMode mode;
  final Map<int, TextEditingController> controllers;
  final VoidCallback onSelectAll;
  final VoidCallback onUnselectAll;
  final void Function(int userId, bool selected) onMemberSelectionChanged;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return const Text('No hay integrantes para dividir el gasto');
    }
    final selectedMembers = members
        .where((member) => selectedMemberIds.contains(member.userId))
        .toList();
    final equal = equalSplit(amount: amount, members: selectedMembers);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Division del gasto',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${selectedMemberIds.length} de ${members.length} integrantes',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: onSelectAll,
                  child: const Text('Seleccionar todos'),
                ),
                TextButton(
                  onPressed: onUnselectAll,
                  child: const Text('Quitar todos'),
                ),
              ],
            ),
            if (selectedMembers.isEmpty) ...[
              const SizedBox(height: 8),
              const Text('Selecciona al menos un integrante para crear pagos'),
            ],
            const SizedBox(height: 8),
            for (final member in members)
              _SplitMemberRow(
                member: member,
                selected: selectedMemberIds.contains(member.userId),
                mode: mode,
                equalAmount: _equalAmountFor(equal, member.userId),
                controller: controllers.putIfAbsent(
                  member.userId,
                  () => TextEditingController(),
                ),
                onChanged: (selected) =>
                    onMemberSelectionChanged(member.userId, selected),
              ),
          ],
        ),
      ),
    );
  }

  double _equalAmountFor(List<SplitDraft> equal, int userId) {
    for (final item in equal) {
      if (item.userId == userId) return item.amount;
    }
    return 0;
  }
}

class _SplitMemberRow extends StatelessWidget {
  const _SplitMemberRow({
    required this.member,
    required this.selected,
    required this.mode,
    required this.equalAmount,
    required this.controller,
    required this.onChanged,
  });

  final GroupMember member;
  final bool selected;
  final SplitMode mode;
  final double equalAmount;
  final TextEditingController controller;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    if (mode == SplitMode.equal) {
      return CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: selected,
        onChanged: (value) => onChanged(value ?? false),
        secondary: RemoteAvatar(
          imageRef: member.photo,
          fallbackIcon: Icons.person_outline,
          size: 36,
          borderRadius: 18,
        ),
        title: Text(member.fullName),
        subtitle: selected
            ? Text(formatCurrency(equalAmount))
            : const Text('No participa'),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Checkbox(
            value: selected,
            onChanged: (value) => onChanged(value ?? false),
          ),
          Expanded(
            child: TextFormField(
              controller: controller,
              enabled: selected,
              decoration: InputDecoration(
                labelText: member.fullName,
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(8),
                  child: RemoteAvatar(
                    imageRef: member.photo,
                    fallbackIcon: Icons.person_outline,
                    size: 32,
                    borderRadius: 16,
                  ),
                ),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: selected ? positiveAmountField : null,
            ),
          ),
        ],
      ),
    );
  }
}

class PaymentDetailScreen extends ConsumerStatefulWidget {
  const PaymentDetailScreen({required this.paymentId, super.key});

  final int paymentId;

  @override
  ConsumerState<PaymentDetailScreen> createState() =>
      _PaymentDetailScreenState();
}

class _PaymentDetailScreenState extends ConsumerState<PaymentDetailScreen> {
  static const _blockchainRefreshInterval = Duration(seconds: 3);
  static const _maxBlockchainRefreshAttempts = 12;

  final _amount = TextEditingController();
  XFile? _evidence;
  Timer? _blockchainRefreshTimer;
  var _saving = false;
  var _confirming = false;
  var _forceBlockchainRefresh = false;
  var _blockchainRefreshLimitReached = false;
  var _blockchainRefreshAttempts = 0;

  @override
  void dispose() {
    _blockchainRefreshTimer?.cancel();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final payment = ref.watch(paymentProvider(widget.paymentId));
    final session = ref.watch(authControllerProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de transaccion')),
      body: payment.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => ErrorView(
          title: 'No se pudo cargar el pago',
          onRetry: () => ref.invalidate(paymentProvider(widget.paymentId)),
        ),
        data: (item) {
          final expense = ref.watch(expenseProvider(item.expenseId));
          _syncBlockchainRefresh(item);
          final expenseOwnerId = expense.valueOrNull?.userId;

          // Quien mira decide que se muestra; los permisos de abajo deciden que
          // esta habilitado. Son cosas distintas: al deudor que ya cubrio su
          // deuda hay que seguir mostrandole sus controles, apagados y con el
          // motivo, mientras que a quien no es el deudor no le sirve de nada
          // verlos ni siquiera apagados.
          //
          // Quien confirma es el creador del gasto, que no siempre coincide con
          // el administrador del grupo: el backend valida exactamente eso en
          // ConfirmPaymentCommand, y la vista no debe prometer algo distinto.
          final isDebtor = session?.id == item.userId;
          final isExpenseOwner =
              expenseOwnerId != null && session?.id == expenseOwnerId;

          final isCompletedAndConfirmed = item.confirmed && item.remaining <= 0;
          final canRegisterPayment = session?.id == item.userId &&
              !isCompletedAndConfirmed &&
              item.remaining > 0;
          final canConfirmPayment = session?.id == expenseOwnerId &&
              !item.confirmed &&
              item.status != 'PENDING';
          final canViewEvidence = item.evidencePhotos.isNotEmpty;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.description,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _StatusPill(status: item.status),
                          _StatusPill(
                              status: item.confirmed
                                  ? 'CONFIRMADO'
                                  : 'SIN CONFIRMAR'),
                          BlockchainHashChip(hash: item.blockchainHash),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _PaymentRows(payment: item),
                      if (expense.isLoading) ...[
                        const SizedBox(height: 8),
                        const LinearProgressIndicator(),
                      ],
                    ],
                  ),
                ),
              ),
              if (canViewEvidence) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Evidencia',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        _PaymentEvidenceGrid(imageRefs: item.evidencePhotos),
                      ],
                    ),
                  ),
                ),
              ],
              // Abonar y adjuntar evidencia son actos del deudor. A quien no lo
              // es no se le muestran: antes aparecian apagados, ocupando la
              // pantalla con acciones que nunca iba a poder ejecutar.
              if (isDebtor) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _amount,
                  enabled: canRegisterPayment,
                  decoration: InputDecoration(
                    labelText: 'Abono',
                    helperText: isCompletedAndConfirmed
                        ? 'Este pago ya fue confirmado por completo'
                        : canRegisterPayment
                            ? null
                            : item.confirmed
                                ? 'El abono anterior fue confirmado; puedes registrar otro abono parcial'
                                : 'Ya cubriste el monto; falta que confirmen la recepcion',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: canRegisterPayment ? _pickEvidence : null,
                  icon: const Icon(Icons.image_outlined),
                  label: Text(
                      _evidence == null ? 'Cargar evidencia' : _evidence!.name),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed:
                      canRegisterPayment && !_saving ? _registerPayment : null,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.payments_outlined),
                  label: const Text('Registrar abono'),
                ),
              ],
              // Confirmar la recepcion es del acreedor. Cuando el creador del
              // gasto se asigno una cuota a si mismo cumple los dos papeles, y
              // entonces ve todo.
              if (isExpenseOwner) ...[
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: canConfirmPayment && !_confirming
                      ? () => _confirmPayment(item)
                      : null,
                  icon: _confirming
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.verified_outlined),
                  label: const Text('Confirmar recepcion'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickEvidence() async {
    final image = await pickImageFromCameraOrGallery(context);
    if (image != null) setState(() => _evidence = image);
  }

  Future<void> _registerPayment() async {
    final value = parseAmount(_amount.text);
    if (value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un monto mayor a cero')),
      );
      return;
    }
    final payment = ref.read(paymentProvider(widget.paymentId)).valueOrNull;
    if (payment != null && value > payment.remaining) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('El abono no puede superar el monto pendiente')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      var photo = '';
      if (_evidence != null) {
        // Evidence is optional, but when present it is uploaded before the
        // payment update so the backend can store the image reference.
        photo =
            (await ref.read(apiProvider).uploadImage(_evidence!.path)).imageId;
      }
      await ref.read(apiProvider).makePayment(
            paymentId: widget.paymentId,
            amount: value,
            photo: photo,
          );
      _refreshPaymentState(widget.paymentId);
      ref.invalidate(dashboardSummaryProvider);
      ref.invalidate(myReputationProvider);
      ref.invalidate(myBadgesProvider);
      ref.invalidate(myReputationHistoryProvider);
      _amount.clear();
      if (mounted) {
        showAchievementSnackBar(
          context,
          title: 'Abono registrado',
          message: 'Tu progreso de pago fue actualizado',
          icon: Icons.payments_outlined,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmPayment(Payment payment) async {
    setState(() => _confirming = true);
    try {
      // Confirmation is the business moment that may update reputation, badges
      // and the payment smart-contract state in the backend.
      await ref.read(apiProvider).confirmPayment(payment.id);
      _refreshPaymentState(payment.id, payment: payment);
      ref.invalidate(dashboardSummaryProvider);
      ref.invalidate(myReputationProvider);
      ref.invalidate(myBadgesProvider);
      ref.invalidate(myReputationHistoryProvider);
      if (mounted) {
        showAchievementSnackBar(
          context,
          title: 'Pago confirmado',
          message: 'La transacción ha sido confirmada',
          icon: Icons.verified_outlined,
          // Solo aqui, no en el abono: el abono es avance y la confirmacion es
          // el final de la deuda. Festejar los dos igual borraria la
          // diferencia entre ir pagando y haber terminado de pagar.
          leading: const CrewCelebration.jumping(
            member: CrewMember.salvador,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  void _refreshPaymentState(int paymentId, {Payment? payment}) {
    final currentPayment =
        payment ?? ref.read(paymentProvider(paymentId)).valueOrNull;
    ref.invalidate(paymentProvider(paymentId));
    _startBlockchainRefresh(force: true);
    if (currentPayment == null) return;
    ref.invalidate(expenseProvider(currentPayment.expenseId));
    ref.invalidate(expensePaymentsProvider(currentPayment.expenseId));
    final expense =
        ref.read(expenseProvider(currentPayment.expenseId)).valueOrNull;
    if (expense != null) invalidateGroup(ref, expense.groupId);
  }

  void _syncBlockchainRefresh(Payment payment) {
    // Blockchain writes are asynchronous on the backend. Keep refreshing while
    // the transaction hash is missing, then stop once the hash appears.
    if (payment.blockchainHash.trim().isEmpty) {
      _startBlockchainRefresh();
    } else if (!_forceBlockchainRefresh) {
      _stopBlockchainRefresh();
      _blockchainRefreshLimitReached = false;
    }
  }

  void _startBlockchainRefresh({bool force = false}) {
    _forceBlockchainRefresh = _forceBlockchainRefresh || force;
    if (_blockchainRefreshLimitReached && !force) return;
    if (force) _blockchainRefreshLimitReached = false;
    if (_blockchainRefreshTimer != null) return;
    _blockchainRefreshAttempts = 0;
    _blockchainRefreshTimer = Timer.periodic(
      _blockchainRefreshInterval,
      (_) => _refreshBlockchainHash(),
    );
  }

  void _refreshBlockchainHash() {
    if (!mounted) return;
    _blockchainRefreshAttempts++;
    final payment = ref.read(paymentProvider(widget.paymentId)).valueOrNull;
    ref.invalidate(paymentProvider(widget.paymentId));
    if (payment != null) {
      ref.invalidate(expenseProvider(payment.expenseId));
      ref.invalidate(expensePaymentsProvider(payment.expenseId));
    }
    if (_blockchainRefreshAttempts >= _maxBlockchainRefreshAttempts) {
      _blockchainRefreshLimitReached = true;
      _stopBlockchainRefresh();
    }
  }

  void _stopBlockchainRefresh() {
    _blockchainRefreshTimer?.cancel();
    _blockchainRefreshTimer = null;
    _forceBlockchainRefresh = false;
    _blockchainRefreshAttempts = 0;
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
        loading: () => const _ReportsSkeleton(),
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
                    Text('Buscar gasto',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _search,
                            decoration: const InputDecoration(
                              labelText: 'Nombre del gasto',
                              prefixIcon: Icon(Icons.search),
                            ),
                            onSubmitted: (_) => _searchExpenses(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _searching ? null : _searchExpenses,
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
                    if (_results != null) ...[
                      const SizedBox(height: 12),
                      if (_results!.isEmpty)
                        const Text(
                            'No se encontraron resultados para la busqueda')
                      else
                        for (final expense in _results!)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.receipt_long_outlined),
                            title: Text(expense.name),
                            subtitle: Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text('Vence ${formatDate(expense.dueDate)}'),
                                BlockchainHashChip(
                                  hash: expense.blockchainHash,
                                  compact: true,
                                ),
                              ],
                            ),
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
                    Text('Informe detallado',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Text(
                        'Gasto total: ${formatCurrency(summary.totalExpenses)}'),
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
                    Text('Distribucion',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 16),
                    if (summary.totalPaid + summary.totalPending <= 0)
                      const _ReportEmptyState(
                        icon: Icons.pie_chart_outline,
                        title: 'Sin distribucion todavia',
                        message:
                            'Cuando registres gastos y pagos, este grafico mostrara la distribucion.',
                      )
                    else
                      SizedBox(
                        height: 220,
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
                    Text('Transacciones',
                        style: Theme.of(context).textTheme.titleMedium),
                    if (summary.recentPayments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: _ReportEmptyState(
                          icon: Icons.swap_horiz_outlined,
                          title: 'Sin transacciones',
                          message:
                              'Tus pagos y cobros recientes apareceran aqui.',
                        ),
                      )
                    else
                      for (final payment in summary.recentPayments)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: context.successIconContainerColor,
                            foregroundColor: context.successIconColor,
                            child: const Icon(Icons.swap_horiz_outlined),
                          ),
                          title: Text(payment.description),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(payment.confirmed
                                  ? payment.status
                                  : '${payment.status} - sin confirmar'),
                              const SizedBox(height: 6),
                              BlockchainHashChip(
                                hash: payment.blockchainHash,
                                compact: true,
                              ),
                            ],
                          ),
                          trailing: Text(formatCurrency(
                              payment.confirmed ? payment.amountPaid : 0)),
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

/// Reportes mientras llega el resumen del panel.
///
/// Mismo orden y mismas alturas que la lista con datos: el buscador, el informe
/// detallado, la torta de distribucion y las transacciones.
class _ReportsSkeleton extends StatelessWidget {
  const _ReportsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _SkeletonSearchCard(),
        SizedBox(height: 16),
        SkeletonCard(lines: 3),
        SizedBox(height: 16),
        SkeletonChartCard(),
        SizedBox(height: 16),
        SkeletonListCard(),
      ],
    );
  }
}

/// El buscador de gastos: el campo y el boton redondo de lupa a su derecha.
class _SkeletonSearchCard extends StatelessWidget {
  const _SkeletonSearchCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSkeleton(width: 120, height: 18),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: AppSkeleton(height: 48, radius: 8)),
                SizedBox(width: 8),
                AppSkeleton(width: 48, height: 48, radius: 999),
              ],
            ),
          ],
        ),
      ),
    );
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
        color:
            (isDark ? AppColors.lightGreen : AppColors.green).withOpacity(0.10),
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

class _ReportEmptyState extends StatelessWidget {
  const _ReportEmptyState({
    required this.icon,
    required this.title,
    required this.message,
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

class _PaymentEvidenceGrid extends StatelessWidget {
  const _PaymentEvidenceGrid({required this.imageRefs});

  final List<String> imageRefs;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: imageRefs.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final imageRef = imageRefs[index];
        final url = remoteImageUrl(imageRef);
        if (url == null) return const SizedBox.shrink();
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => showAppDialog<void>(
            context: context,
            builder: (context) => Dialog(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: AppColors.mist,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
        );
      },
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

/// Aviso fijo de que la boleta cargada ya respalda otro gasto.
///
/// Es un bloque en el formulario y no solo un snackbar porque el snackbar se va
/// a los pocos segundos y el bloqueo del boton se queda: sin algo permanente,
/// quien vuelve a la pantalla ve "Registrar gasto" apagado y no sabe por que.
class _DuplicateReceiptBanner extends StatelessWidget {
  const _DuplicateReceiptBanner({required this.message, required this.onReplace});

  final String message;
  final VoidCallback onReplace;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: error.withOpacity(context.isDarkMode ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: error.withOpacity(0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.copy_all_outlined, color: error, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Comprobante repetido',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800, color: error),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(message),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onReplace,
              icon: const Icon(Icons.refresh),
              label: const Text('Usar otro comprobante'),
            ),
          ),
        ],
      ),
    );
  }
}
