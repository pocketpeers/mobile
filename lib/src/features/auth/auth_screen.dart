import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../state/providers.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  var _isRegistering = false;
  String? _authError;
  var _hideProviderError = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayedError = _authError ??
        (!_hideProviderError && auth.hasError && auth.error != null
            ? _authErrorMessage(auth.error!)
            : null);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.navy, AppColors.blue, AppColors.green],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                color: isDark
                    ? AppColors.darkSurface.withOpacity(0.96)
                    : Colors.white.withOpacity(0.96),
                child: Padding(
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
                            color: (isDark ? AppColors.lightGreen : AppColors.green)
                                .withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Image.asset(
                              isDark
                                  ? 'assets/images/logo-dark.png'
                                  : 'assets/images/logo-transparent.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'PocketPeers',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isRegistering
                              ? 'Crea tu cuenta para organizar gastos compartidos.'
                              : 'Ingresa para ver tus grupos, pagos y balances.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: isDark
                                    ? Colors.white.withOpacity(0.72)
                                    : AppColors.navy.withOpacity(0.68),
                              ),
                        ),
                        const SizedBox(height: 24),
                        if (_isRegistering) ...[
                          TextFormField(
                            controller: _firstName,
                            decoration: const InputDecoration(labelText: 'Nombre'),
                            validator: _required,
                            onChanged: (_) => _clearAuthError(),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _lastName,
                            decoration: const InputDecoration(labelText: 'Apellido'),
                            validator: _required,
                            onChanged: (_) => _clearAuthError(),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phone,
                            decoration: const InputDecoration(labelText: 'Telefono'),
                            keyboardType: TextInputType.phone,
                            validator: _required,
                            onChanged: (_) => _clearAuthError(),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _email,
                            decoration: const InputDecoration(labelText: 'Correo'),
                            keyboardType: TextInputType.emailAddress,
                            validator: _required,
                            onChanged: (_) => _clearAuthError(),
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          controller: _username,
                          decoration: const InputDecoration(labelText: 'Usuario'),
                          validator: _required,
                          onChanged: (_) => _clearAuthError(),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _password,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Contrasena'),
                          validator: _required,
                          onChanged: (_) => _clearAuthError(),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: auth.isLoading ? null : _submit,
                          icon: auth.isLoading
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(_isRegistering ? Icons.person_add_alt : Icons.login),
                          label: Text(_isRegistering ? 'Crear cuenta' : 'Iniciar sesion'),
                        ),
                        TextButton(
                          onPressed: auth.isLoading ? null : _toggleMode,
                          child: Text(
                            _isRegistering ? 'Ya tengo cuenta' : 'Crear una cuenta nueva',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white.withOpacity(0.72)
                                  : AppColors.navy.withOpacity(0.68),
                            ),
                          ),
                        ),
                        if (displayedError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: _AuthErrorBox(message: displayedError),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Campo requerido';
    return null;
  }

  void _toggleMode() {
    setState(() {
      _isRegistering = !_isRegistering;
      _authError = null;
      _hideProviderError = true;
      _clearFields();
    });
    _formKey.currentState?.reset();
  }

  void _clearFields() {
    _username.clear();
    _password.clear();
    _firstName.clear();
    _lastName.clear();
    _phone.clear();
    _email.clear();
  }

  void _clearAuthError() {
    if (_authError != null || !_hideProviderError) {
      setState(() {
        _authError = null;
        _hideProviderError = true;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _authError = null;
      _hideProviderError = false;
    });
    final controller = ref.read(authControllerProvider.notifier);

    if (_isRegistering) {
      await controller.signUp(
        username: _username.text.trim(),
        password: _password.text,
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        phoneNumber: _phone.text.trim(),
        email: _email.text.trim(),
      );
    } else {
      await controller.signIn(_username.text.trim(), _password.text);
    }

    if (!mounted) return;
    final error = ref.read(authControllerProvider).error;
    if (error != null) {
      setState(() => _authError = _authErrorMessage(error));
    }
  }

  String _authErrorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      final backendMessage = _backendMessage(data);
      if (backendMessage != null && backendMessage.trim().isNotEmpty) {
        return backendMessage;
      }

      final statusCode = error.response?.statusCode;
      if (statusCode == 401 || statusCode == 403) {
        return 'Usuario o contrasena incorrectos.';
      }
      if (statusCode == 409) {
        return 'Ya existe una cuenta con esos datos.';
      }
      if (statusCode != null && statusCode >= 500) {
        return 'El servidor no pudo procesar la solicitud. Intenta nuevamente.';
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return 'La conexion esta tardando demasiado. Revisa tu red e intenta otra vez.';
      }
      if (error.type == DioExceptionType.connectionError) {
        return 'No se pudo conectar con el servidor.';
      }
    }

    return _isRegistering
        ? 'No se pudo crear la cuenta. Revisa los datos e intenta nuevamente.'
        : 'No se pudo iniciar sesion. Revisa tus datos e intenta nuevamente.';
  }

  String? _backendMessage(Object? data) {
    if (data is Map) {
      final message = data['message'] ?? data['error'];
      if (message != null) return message.toString();
      if (data.isNotEmpty) return data.values.first.toString();
    }
    if (data is String && data.trim().isNotEmpty) return data;
    return null;
  }
}

class _AuthErrorBox extends StatelessWidget {
  const _AuthErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
