import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../state/providers.dart';

/// Cambio de contraseña para una sesión ya iniciada.
///
/// Pide la contraseña actual aunque la sesión esté activa: un teléfono
/// desbloqueado no debería alcanzar para que alguien tome control de la cuenta.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _newPassword = TextEditingController();
  final _repeat = TextEditingController();

  var _isBusy = false;
  var _obscure = true;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _newPassword.dispose();
    _repeat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cambiar contraseña')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: context.primaryIconContainerColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.password_outlined,
                      size: 32, color: context.primaryIconColor),
                ),
                const SizedBox(height: 20),
                Text(
                  'Elige una contraseña nueva',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Necesitas conocer tu contraseña actual para poder cambiarla.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.mutedIconColor,
                        height: 1.5,
                      ),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _current,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña actual',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'Ingresa tu contraseña actual'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _newPassword,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Contraseña nueva',
                    prefixIcon: const Icon(Icons.lock_outline),
                    helperText: 'Mínimo 8 caracteres, con letras y números',
                    helperMaxLines: 2,
                    suffixIcon: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: _validatePassword,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _repeat,
                  obscureText: _obscure,
                  decoration: const InputDecoration(
                    labelText: 'Repite la contraseña nueva',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (value) => value != _newPassword.text
                      ? 'Las contraseñas no coinciden'
                      : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  _ErrorBox(message: _error!),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _isBusy ? null : _submit,
                  icon: _isBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_outlined),
                  label: Text(_isBusy ? 'Guardando...' : 'Guardar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      await ref.read(apiProvider).changePassword(
            currentPassword: _current.text,
            newPassword: _newPassword.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Tu contraseña fue actualizada.')),
        );
      context.pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.length < 8) return 'Debe tener al menos 8 caracteres';
    if (!password.contains(RegExp(r'[A-Za-zÁÉÍÓÚáéíóúÑñ]'))) {
      return 'Debe incluir al menos una letra';
    }
    if (!password.contains(RegExp(r'\d'))) {
      return 'Debe incluir al menos un número';
    }
    if (password == _current.text) {
      return 'La contraseña nueva debe ser distinta de la actual';
    }
    return null;
  }

  String _errorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final message = data['message'];
        if (message is String && message.trim().isNotEmpty) return message;
      }
      final status = error.response?.statusCode;
      if (status == 401) return 'Tu contraseña actual no es correcta.';
      if (status == 400) return 'La contraseña nueva no cumple los requisitos.';
      if (status != null && status >= 500) {
        return 'El servidor no pudo procesar la solicitud. Intenta nuevamente.';
      }
      if (error.type == DioExceptionType.connectionError) {
        return 'No se pudo conectar con el servidor.';
      }
    }
    return 'No se pudo cambiar la contraseña. Intenta nuevamente.';
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        border: Border.all(color: color.withOpacity(0.45)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: color, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
