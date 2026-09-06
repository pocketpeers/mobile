import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../state/providers.dart';

/// Recuperación de contraseña olvidada, en dos pasos.
///
/// Se mantienen los dos pasos dentro de una sola pantalla para que el correo
/// escrito en el primero siga a la vista en el segundo: si la persona se
/// equivocó al escribirlo, lo nota sin tener que retroceder.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

enum _Step { requestCode, confirmCode }

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _confirmFormKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _newPassword = TextEditingController();
  final _repeatPassword = TextEditingController();

  var _step = _Step.requestCode;
  var _isBusy = false;
  var _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _newPassword.dispose();
    _repeatPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recuperar contraseña'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _step == _Step.requestCode
              ? _buildRequestStep(context)
              : _buildConfirmStep(context),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Paso 1: pedir el código
  // ------------------------------------------------------------------

  Widget _buildRequestStep(BuildContext context) {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            icon: Icons.lock_reset_outlined,
            title: 'Recupera tu acceso',
            subtitle:
                'Escribe el correo con el que te registraste y te enviaremos '
                'un código de 6 dígitos.',
          ),
          const SizedBox(height: 28),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              prefixIcon: Icon(Icons.mail_outline),
            ),
            validator: _validateEmail,
            onFieldSubmitted: (_) => _requestCode(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            _ErrorBanner(message: _error!),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _isBusy ? null : _requestCode,
            icon: _isBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(_isBusy ? 'Enviando...' : 'Enviar código'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _isBusy ? null : () => setState(() => _step = _Step.confirmCode),
            child: const Text('Ya tengo un código'),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Paso 2: canjear el código
  // ------------------------------------------------------------------

  Widget _buildConfirmStep(BuildContext context) {
    return Form(
      key: _confirmFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            icon: Icons.mark_email_read_outlined,
            title: 'Revisa tu correo',
            subtitle: _email.text.trim().isEmpty
                ? 'Ingresa el código que recibiste y tu contraseña nueva.'
                : 'Si ${_email.text.trim()} está registrado, recibirás un '
                    'código en unos minutos. Revisa también la carpeta de spam.',
          ),
          const SizedBox(height: 28),
          if (_email.text.trim().isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                validator: _validateEmail,
              ),
            ),
          TextFormField(
            controller: _code,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 12,
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Código de 6 dígitos',
              counterText: '',
            ),
            validator: (value) {
              final code = value?.trim() ?? '';
              if (code.length != 6) return 'El código tiene 6 dígitos';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _newPassword,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Contraseña nueva',
              prefixIcon: const Icon(Icons.lock_outline),
              helperText: 'Mínimo 8 caracteres, con letras y números',
              helperMaxLines: 2,
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: _validatePassword,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _repeatPassword,
            obscureText: _obscurePassword,
            decoration: const InputDecoration(
              labelText: 'Repite la contraseña',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            validator: (value) {
              if (value != _newPassword.text) {
                return 'Las contraseñas no coinciden';
              }
              return null;
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            _ErrorBanner(message: _error!),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _isBusy ? null : _confirmReset,
            icon: _isBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_outlined),
            label: Text(_isBusy ? 'Guardando...' : 'Cambiar contraseña'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _isBusy ? null : _requestCode,
            child: const Text('Enviar el código de nuevo'),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Acciones
  // ------------------------------------------------------------------

  Future<void> _requestCode() async {
    if (!(_emailFormKey.currentState?.validate() ??
        _validateEmail(_email.text) == null)) {
      return;
    }
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      await ref.read(apiProvider).requestPasswordReset(_email.text.trim());
      if (!mounted) return;
      setState(() => _step = _Step.confirmCode);
      _showMessage(
        'Si el correo está registrado, recibirás un código en unos minutos.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _confirmReset() async {
    if (!(_confirmFormKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      await ref.read(apiProvider).confirmPasswordReset(
            email: _email.text.trim(),
            code: _code.text.trim(),
            newPassword: _newPassword.text,
          );
      if (!mounted) return;
      _showMessage('Tu contraseña fue actualizada. Ya puedes iniciar sesión.');
      context.go('/auth');
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _goBack() {
    // Desde el segundo paso, retroceder vuelve al primero en lugar de salir de
    // la pantalla: quien se equivocó de correo no debería perder el avance.
    if (_step == _Step.confirmCode) {
      setState(() {
        _step = _Step.requestCode;
        _error = null;
      });
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/auth');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ------------------------------------------------------------------
  // Validación y errores
  // ------------------------------------------------------------------

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Ingresa tu correo';
    final pattern = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
    if (!pattern.hasMatch(email)) return 'Ese correo no parece válido';
    return null;
  }

  String? _validatePassword(String? value) {
    // Se replican las reglas del backend para poder avisar antes de la llamada.
    // El backend vuelve a validarlas: esto es comodidad, no la defensa.
    final password = value ?? '';
    if (password.length < 8) return 'Debe tener al menos 8 caracteres';
    if (!password.contains(RegExp(r'[A-Za-zÁÉÍÓÚáéíóúÑñ]'))) {
      return 'Debe incluir al menos una letra';
    }
    if (!password.contains(RegExp(r'\d'))) {
      return 'Debe incluir al menos un número';
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
      if (status == 400) return 'El código es incorrecto o ya venció.';
      if (status != null && status >= 500) {
        return 'El servidor no pudo procesar la solicitud. Intenta nuevamente.';
      }
      if (error.type == DioExceptionType.connectionError) {
        return 'No se pudo conectar con el servidor.';
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return 'La conexión está tardando demasiado.';
      }
    }
    return 'No se pudo completar la operación. Intenta nuevamente.';
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: context.primaryIconContainerColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 32, color: context.primaryIconColor),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.mutedIconColor,
                height: 1.5,
              ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

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
