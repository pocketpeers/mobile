import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../core/validators.dart';
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

  /// Descarta solo los avisos pasados unos segundos.
  ///
  /// Un mensaje que se queda fijo deja de leerse: la persona lo asocia a la
  /// pantalla y no al intento que acaba de hacer, y despues no distingue si
  /// sigue ahi por el error anterior o por uno nuevo.
  Timer? _dismissTimer;

  static const _dismissDelay = Duration(seconds: 6);

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _email.dispose();
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Los avisos se programan al llegar, no dentro del build: aqui solo se
    // observa la transicion.
    ref.listen(authControllerProvider, (previous, next) {
      if (next.hasError) _scheduleDismiss();
    });
    ref.listen(sessionExpiredProvider, (previous, next) {
      if (next) _scheduleDismiss();
    });

    final auth = ref.watch(authControllerProvider);
    final sessionExpired = ref.watch(sessionExpiredProvider);
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
                            color: (isDark
                                    ? AppColors.lightGreen
                                    : AppColors.green)
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
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.72)
                                        : AppColors.navy.withOpacity(0.68),
                                  ),
                        ),
                        const SizedBox(height: 24),
                        if (_isRegistering) ...[
                          TextFormField(
                            controller: _firstName,
                            decoration:
                                const InputDecoration(labelText: 'Nombre'),
                            validator: nameField,
                            onChanged: (_) => _clearAuthError(),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _lastName,
                            decoration:
                                const InputDecoration(labelText: 'Apellido'),
                            validator: nameField,
                            onChanged: (_) => _clearAuthError(),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phone,
                            decoration:
                                const InputDecoration(labelText: 'Telefono'),
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(9),
                            ],
                            validator: phoneField,
                            onChanged: (_) => _clearAuthError(),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _email,
                            decoration:
                                const InputDecoration(labelText: 'Correo'),
                            keyboardType: TextInputType.emailAddress,
                            validator: emailField,
                            onChanged: (_) => _clearAuthError(),
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          controller: _username,
                          decoration:
                              const InputDecoration(labelText: 'Usuario'),
                          validator: usernameField,
                          onChanged: (_) => _clearAuthError(),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _password,
                          obscureText: true,
                          decoration:
                              const InputDecoration(labelText: 'Contraseña'),
                          validator:
                              _isRegistering ? passwordField : requiredField,
                          onChanged: (_) => _clearAuthError(),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: auth.isLoading ? null : _submit,
                          icon: auth.isLoading
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(_isRegistering
                                  ? Icons.person_add_alt
                                  : Icons.login),
                          label: Text(_isRegistering
                              ? 'Crear cuenta'
                              : 'Iniciar sesion'),
                        ),
                        TextButton(
                          onPressed: auth.isLoading ? null : _toggleMode,
                          child: Text(
                            _isRegistering
                                ? 'Ya tengo cuenta'
                                : 'Crear una cuenta nueva',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white.withOpacity(0.72)
                                  : AppColors.navy.withOpacity(0.68),
                            ),
                          ),
                        ),
                        // Solo se ofrece al iniciar sesion: durante el registro
                        // no hay ninguna contrasena que recuperar todavia.
                        if (!_isRegistering)
                          TextButton(
                            onPressed: auth.isLoading
                                ? null
                                : () => context.push('/forgot-password'),
                            child: Text(
                              'Olvide mi contrasena',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white.withOpacity(0.72)
                                    : AppColors.navy.withOpacity(0.68),
                              ),
                            ),
                          ),
                        if (sessionExpired)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: _SessionExpiredBox(isDark: isDark),
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

  void _toggleMode() {
    // El aviso de sesion vencida se limpia aqui tambien. Antes solo se borraban
    // los errores de credenciales, asi que al pasar a registro el banner seguia
    // ahi hablando de una sesion que ya no viene al caso.
    _clearSessionExpired();
    _dismissTimer?.cancel();
    setState(() {
      _isRegistering = !_isRegistering;
      _authError = null;
      _hideProviderError = true;
      _clearFields();
    });
    _formKey.currentState?.reset();
  }

  /// Programa el borrado de los avisos visibles.
  void _scheduleDismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = Timer(_dismissDelay, () {
      if (!mounted) return;
      _clearSessionExpired();
      setState(() {
        _authError = null;
        _hideProviderError = true;
      });
    });
  }

  void _clearFields() {
    _username.clear();
    _password.clear();
    _firstName.clear();
    _lastName.clear();
    _phone.clear();
    _email.clear();
  }

  /// Quita el aviso de sesion vencida en cuanto el usuario vuelve a intentar.
  void _clearSessionExpired() {
    if (ref.read(sessionExpiredProvider)) {
      ref.read(sessionExpiredProvider.notifier).state = false;
    }
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
    _clearSessionExpired();
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
      _scheduleDismiss();
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
        return 'Usuario o contraseña incorrectos.';
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

/// Aviso de sesion vencida en la pantalla de acceso.
///
/// Es informativo y no un error: la persona no hizo nada mal, simplemente paso
/// el tiempo. Por eso no usa el color de error, que sugeriria una falla suya.
class _SessionExpiredBox extends StatelessWidget {
  const _SessionExpiredBox({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final color = isDark ? AppColors.lightBlue : AppColors.blue;
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
          Icon(Icons.schedule_outlined, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tu sesion expiro por seguridad. Vuelve a iniciar sesion para continuar.',
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
