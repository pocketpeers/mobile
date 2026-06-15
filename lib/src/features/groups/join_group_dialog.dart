import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/providers.dart';

class JoinGroupDialog extends ConsumerStatefulWidget {
  const JoinGroupDialog({super.key});

  @override
  ConsumerState<JoinGroupDialog> createState() => _JoinGroupDialogState();
}

class _JoinGroupDialogState extends ConsumerState<JoinGroupDialog> {
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
      content: TextField(
        controller: _token,
        decoration: const InputDecoration(labelText: 'Codigo de invitacion'),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => context.pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _saving ? null : _join,
          child: const Text('Unirme'),
        ),
      ],
    );
  }

  Future<void> _join() async {
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
      if (mounted) context.pop();
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
}
