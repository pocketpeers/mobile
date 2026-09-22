import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_error_message.dart';
import '../../core/app_theme.dart';
import '../../state/providers.dart';

/// Pide el código de seis dígitos que confirma el correo del alta.
///
/// La cuenta todavía no existe: se crea cuando el código se valida. Por eso
/// salir de aquí no deja un usuario a medias, solo una solicitud que vence
/// sola a los quince minutos.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingSignUpProvider);
    final auth = ref.watch(authControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Si no hay alta en curso —por ejemplo tras reiniciar la app— no hay nada
    // que confirmar. Se vuelve al acceso en vez de mostrar un formulario que
    // no puede funcionar.
    if (pending == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/auth');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirma tu correo'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(pendingSignUpProvider.notifier).state = null;
            context.go('/auth');
          },
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.mark_email_unread_outlined,
                      size: 56, color: context.primaryIconColor),
                  const SizedBox(height: 16),
                  Text(
                    'Te enviamos un código',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Revisa ${pending.email} e ingresa los 6 dígitos. '
                    'El código vence en 15 minutos.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDark
                              ? Colors.white70
                              : Colors.black.withOpacity(0.66),
                        ),
                  ),
                  const SizedBox(height: 16),
                  // El aviso del spam va aquí y no al final: es donde la
                  // persona está cuando no encuentra el correo, y abajo, tras
                  // el botón, se leía cuando ya se había dado por vencida.
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.warningIconContainerColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.report_gmailerrorred_outlined,
                            color: context.warningIconColor),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '¿No lo ves? Busca en tu carpeta de spam o correo '
                            'no deseado. Suele llegar ahí la primera vez.',
                            style: TextStyle(color: context.warningIconColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _code,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 28, letterSpacing: 8, fontWeight: FontWeight.w700),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Código',
                      counterText: '',
                    ),
                    validator: (value) {
                      final code = value?.trim() ?? '';
                      if (code.length != 6) return 'Ingresa los 6 dígitos';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: auth.isLoading ? null : () => _confirm(pending),
                    icon: auth.isLoading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Confirmar y crear cuenta'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirm(PendingSignUp pending) async {
    // El teclado se baja antes de nada: con él abierto, el aviso de error
    // queda detrás y parece que el botón no hizo nada.
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    await ref.read(authControllerProvider.notifier).confirmSignUp(
          email: pending.email,
          code: _code.text.trim(),
          username: pending.username,
          password: pending.password,
        );

    if (!mounted) return;
    final error = ref.read(authControllerProvider).error;
    if (error != null) {
      _showError(_errorMessage(error));
      return;
    }

    // Confirmado: ya hay cuenta y sesión. El enrutador se encarga del destino.
    ref.read(pendingSignUpProvider.notifier).state = null;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: context.dangerIconColor),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        duration: const Duration(seconds: 5),
      ));
  }

  String _errorMessage(Object error) {
    // Antes esto miraba `error.toString()` buscando palabras del mensaje del
    // backend, pero el texto de una DioException no incluye el cuerpo de la
    // respuesta: la comparación no acertaba nunca y todo error acababa en el
    // mensaje de conexión. Un código mal tecleado decía "revisa tu internet",
    // que manda a la persona a pelearse con su wifi por algo que no tiene que
    // ver.
    return apiErrorMessage(
      error,
      fallback: 'No pudimos confirmar el código. Inténtalo otra vez.',
    );
  }
}
