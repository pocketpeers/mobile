import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_motion.dart';
import '../../core/validators.dart';
import '../../state/providers.dart';

class JoinGroupDialog extends ConsumerStatefulWidget {
  const JoinGroupDialog({super.key});

  @override
  ConsumerState<JoinGroupDialog> createState() => _JoinGroupDialogState();
}

class _JoinGroupDialogState extends ConsumerState<JoinGroupDialog> {
  final _formKey = GlobalKey<FormState>();
  final _token = TextEditingController();
  var _saving = false;

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Unirme a grupo'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _token,
          decoration: const InputDecoration(labelText: 'Codigo de invitacion'),
          validator: _invitationToken,
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => context.pop(),
            child: const Text('Cancelar')),
        FilledButton(
          onPressed: _saving ? null : _join,
          child: const Text('Unirme'),
        ),
      ],
    );
  }

  Future<void> _join() async {
    if (!_formKey.currentState!.validate()) return;
    final session = ref.read(authControllerProvider).valueOrNull;
    final token = _token.text.trim();
    if (session == null || token.isEmpty) return;
    setState(() => _saving = true);
    try {
      final member = await ref.read(apiProvider).joinGroup(
            userId: session.id,
            token: token,
          );
      ref.invalidate(groupsProvider);
      invalidateGroup(ref, member.groupId);
      if (mounted) {
        showAchievementSnackBar(
          context,
          title: 'Te uniste al grupo',
          message: 'Ya puedes ver sus gastos y pagos',
          icon: Icons.group_add_outlined,
        );
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo unir al grupo')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _invitationToken(String? value) {
    final required = requiredField(value);
    if (required != null) return required;
    if (value!.trim().length < 6) return 'Ingresa un codigo valido';
    return null;
  }
}
