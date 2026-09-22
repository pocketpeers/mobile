import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_error_message.dart';
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
  final _documentNumber = TextEditingController();
  var _documentType = IdDocumentType.dni;
  var _isRegistering = false;

  /// Si la contrasena se muestra en claro.
  ///
  /// Escribir a ciegas en un teclado de telefono es la primera causa de
  /// "contrasena incorrecta" cuando la contrasena es correcta, y pesa mas en
  /// quien tiene menos practica con el movil, que es justo el publico de esta
  /// aplicacion.
  var _passwordVisible = false;

  /// Controlador del campo de repetir la contrasena.
  ///
  /// Solo existe en la aplicacion: al backend se le sigue mandando una sola
  /// contrasena. Comprobar que coinciden es cosa del formulario, y anadir el
  /// segundo campo al contrato del servidor no aportaria nada que este no
  /// pueda decidir aqui.
  final _confirmPassword = TextEditingController();

  /// Permite revalidar SOLO ese campo cuando cambia la contrasena de arriba.
  ///
  /// Sin esto, quien escribe las dos iguales y luego corrige la primera se
  /// queda con el segundo campo en verde hasta que pulsa el boton.
  final _confirmPasswordKey = GlobalKey<FormFieldState<String>>();

  /// Revalida el numero de documento al salir del campo.
  ///
  /// El validador ya exige la longitud exacta, pero solo corre al pulsar el
  /// boton: hasta entonces un DNI de cinco digitos se veia igual de correcto
  /// que uno completo. Comprobarlo al perder el foco avisa cuando la persona
  /// acaba de escribirlo, no tres campos despues.
  final _documentNumberKey = GlobalKey<FormFieldState<String>>();

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
    _confirmPassword.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _email.dispose();
    _documentNumber.dispose();
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
                          const _SectionLabel(
                              icon: Icons.person_outline, text: 'Tus datos'),
                          const SizedBox(height: 12),
                          // Nombre y apellido van en pareja: son cortos, se
                          // llenan seguidos, y separarlos en dos filas enteras
                          // alarga el formulario sin ganar legibilidad.
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _firstName,
                                  decoration: const InputDecoration(
                                      labelText: 'Nombre'),
                                  textCapitalization: TextCapitalization.words,
                                  validator: nameField,
                                  onChanged: (_) => _clearAuthError(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _lastName,
                                  decoration: const InputDecoration(
                                      labelText: 'Apellido'),
                                  textCapitalization: TextCapitalization.words,
                                  validator: nameField,
                                  onChanged: (_) => _clearAuthError(),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phone,
                            decoration: const InputDecoration(
                              labelText: 'Telefono',
                              prefixIcon: Icon(Icons.phone_outlined),
                              prefixText: '+51 ',
                            ),
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
                            decoration: const InputDecoration(
                              labelText: 'Correo',
                              prefixIcon: Icon(Icons.mail_outline),
                              // El aviso va aqui, mientras se escribe, y no
                              // solo en el dialogo de confirmacion: para
                              // entonces la persona ya dio el dato por bueno.
                              helperText: 'Aqui te enviaremos el codigo',
                            ),
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            validator: emailField,
                            onChanged: (_) => _clearAuthError(),
                          ),
                          const SizedBox(height: 20),
                          const _SectionLabel(
                              icon: Icons.badge_outlined,
                              text: 'Tu documento'),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<IdDocumentType>(
                            value: _documentType,
                            decoration: const InputDecoration(
                              labelText: 'Tipo',
                              prefixIcon: Icon(Icons.assignment_ind_outlined),
                            ),
                            items: [
                              for (final type in IdDocumentType.values)
                                DropdownMenuItem(
                                  value: type,
                                  child: Text(type.label),
                                ),
                            ],
                            onChanged: (type) {
                              if (type == null) return;
                              // Al cambiar de tipo se vacia el numero. Un DNI no
                              // es un pasaporte valido, asi que conservarlo solo
                              // dejaria un dato que ya no cuadra; y de paso se
                              // va el mensaje de error del tipo anterior, que
                              // antes se quedaba diciendo que el numero estaba
                              // mal cuando ya no lo estaba.
                              setState(() => _documentType = type);
                              _documentNumber.clear();
                              _documentNumberKey.currentState?.reset();
                              _clearAuthError();
                            },
                          ),
                          const SizedBox(height: 12),
                          Focus(
                            // Al salir del campo se comprueba la longitud. El
                            // formateador impide pasarse del maximo, pero nada
                            // impide quedarse corto mientras se escribe, y ese
                            // es justo el error que hay que cazar aqui y no al
                            // final del formulario.
                            onFocusChange: (hasFocus) {
                              if (!hasFocus &&
                                  _documentNumber.text.isNotEmpty) {
                                _documentNumberKey.currentState?.validate();
                              }
                            },
                            child: TextFormField(
                            key: _documentNumberKey,
                            controller: _documentNumber,
                            decoration: InputDecoration(
                              labelText: 'Numero de ${_documentType.label}',
                              prefixIcon: const Icon(Icons.pin_outlined),
                              // Se dice lo que se espera antes de escribir, no
                              // despues de fallar.
                              helperText: _documentType.formatHint,
                            ),
                            textCapitalization: TextCapitalization.characters,
                            // El DNI y el carne son solo digitos, asi que abren
                            // teclado numerico y no admiten letras. El pasaporte
                            // si es alfanumerico: su formato lo fija cada pais.
                            keyboardType: _documentType.isNumericOnly
                                ? TextInputType.number
                                : TextInputType.text,
                            inputFormatters: [
                              if (_documentType.isNumericOnly)
                                FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(
                                  _documentType.maxLength),
                            ],
                            validator: documentNumberField(_documentType),
                            onChanged: (_) => _clearAuthError(),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const _SectionLabel(
                              icon: Icons.lock_outline, text: 'Tu cuenta'),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          controller: _username,
                          decoration: const InputDecoration(
                            labelText: 'Usuario',
                            prefixIcon: Icon(Icons.account_circle_outlined),
                          ),
                          autocorrect: false,
                          validator: usernameField,
                          onChanged: (_) => _clearAuthError(),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _password,
                          obscureText: !_passwordVisible,
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: const Icon(Icons.key_outlined),
                            suffixIcon: IconButton(
                              tooltip: _passwordVisible
                                  ? 'Ocultar contraseña'
                                  : 'Mostrar contraseña',
                              icon: Icon(_passwordVisible
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined),
                              onPressed: () => setState(
                                  () => _passwordVisible = !_passwordVisible),
                            ),
                          ),
                          validator:
                              _isRegistering ? passwordField : requiredField,
                          onChanged: (_) {
                            _clearAuthError();
                            // Si ya habia una confirmacion escrita, se vuelve a
                            // comprobar al vuelo en vez de esperar al envio.
                            if (_isRegistering &&
                                _confirmPassword.text.isNotEmpty) {
                              _confirmPasswordKey.currentState?.validate();
                            }
                          },
                        ),
                        if (_isRegistering) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            key: _confirmPasswordKey,
                            controller: _confirmPassword,
                            obscureText: !_passwordVisible,
                            decoration: InputDecoration(
                              labelText: 'Repetir contraseña',
                              prefixIcon: const Icon(Icons.key_outlined),
                              // Comparte el mismo ojo que el campo de arriba:
                              // dos interruptores separados para el mismo dato
                              // solo invitan a mostrar uno y no el otro, que es
                              // justo cuando no se ve si coinciden.
                              suffixIcon: IconButton(
                                tooltip: _passwordVisible
                                    ? 'Ocultar contraseña'
                                    : 'Mostrar contraseña',
                                icon: Icon(_passwordVisible
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined),
                                onPressed: () => setState(
                                    () => _passwordVisible = !_passwordVisible),
                              ),
                            ),
                            // El error aparece mientras se escribe, no al
                            // enviar: es el unico campo cuyo fallo se puede
                            // detectar sin salir del formulario.
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Repite tu contraseña';
                              }
                              if (value != _password.text) {
                                return 'Las contraseñas no coinciden';
                              }
                              return null;
                            },
                            onChanged: (_) => _clearAuthError(),
                          ),
                        ],
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
                        // no hay ninguna contraseña que recuperar todavia.
                        if (!_isRegistering)
                          TextButton(
                            onPressed: auth.isLoading
                                ? null
                                : () => context.push('/forgot-password'),
                            child: Text(
                              'Olvidé mi contraseña',
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
    // Cambiar de modo descarta el aviso en curso: habla del intento anterior.
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() {
      _isRegistering = !_isRegistering;
      _clearFields();
    });
    _formKey.currentState?.reset();
  }

  /// Programa el borrado del aviso de sesion vencida.
  ///
  /// Ya solo cubre ese: los errores de credenciales salen como SnackBar, que se
  /// va solo a los cinco segundos.
  void _scheduleDismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = Timer(_dismissDelay, () {
      if (!mounted) return;
      _clearSessionExpired();
    });
  }

  void _clearFields() {
    _username.clear();
    _password.clear();
    _confirmPassword.clear();
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

  /// Retira el aviso en cuanto la persona empieza a corregir.
  ///
  /// Antes borraba el estado del cuadro que se pintaba al final del formulario.
  /// Ese cuadro ya no existe —quedaba detras del teclado, que era justamente el
  /// problema— y el unico aviso es el SnackBar, asi que lo que hay que retirar
  /// es ese. Sin esto, el mensaje de "usuario o contrasena incorrectos" seguiria
  /// flotando mientras ya se esta escribiendo la contrasena buena.
  void _clearAuthError() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  Future<void> _submit() async {
    _clearSessionExpired();
    // El teclado se baja antes de validar. Con el abierto, cualquier aviso
    // queda detras y el usuario cree que el boton no hizo nada.
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final controller = ref.read(authControllerProvider.notifier);

    if (_isRegistering) {
      // Antes de crear nada se pide confirmar los datos. El correo y el
      // documento son los dos que no se pueden arreglar despues por cuenta
      // propia: al correo va el codigo de verificacion y es el unico camino
      // para recuperar la contrasena, y el documento identifica a la persona.
      if (!await _confirmRegistrationData()) return;
      if (!mounted) return;

      // El alta ya no crea la cuenta de golpe: pide un codigo al correo y la
      // cuenta nace al confirmarlo. Asi una direccion mal escrita no deja una
      // cuenta activa que su dueno no puede recuperar, porque la recuperacion
      // de contrasena se apoya justo en ese correo.
      final email = _email.text.trim();
      final username = _username.text.trim();
      final password = _password.text;
      final needsVerification = await controller.requestSignUp(
        username: username,
        password: password,
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        phoneNumber: _phone.text.trim(),
        email: email,
        documentType: _documentType.apiValue,
        documentNumber: _documentNumber.text.trim().toUpperCase(),
      );
      if (!mounted) return;
      if (needsVerification) {
        ref.read(pendingSignUpProvider.notifier).state = PendingSignUp(
          email: email,
          username: username,
          password: password,
        );
        context.push('/verify-email');
        return;
      }
    } else {
      await controller.signIn(_username.text.trim(), _password.text);
    }

    if (!mounted) return;
    final error = ref.read(authControllerProvider).error;
    if (error != null) {
      _showErrorSnackBar(_authErrorMessage(error));
    }
  }

  /// Pide revisar los datos antes de crear la cuenta.
  ///
  /// El correo y el documento van destacados y el resto en letra menor, porque
  /// no todos los errores cuestan lo mismo: un apellido mal escrito se corrige
  /// luego desde el perfil, pero un correo equivocado deja a la persona sin
  /// codigo de verificacion y sin forma de recuperar su contrasena, y un
  /// documento errado rompe la identificacion de quien esta detras de la
  /// cuenta.
  Future<bool> _confirmRegistrationData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Revisa tus datos'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Antes de crear tu cuenta, confirma que esto esté bien escrito:',
              ),
              const SizedBox(height: 16),
              _ConfirmField(
                icon: Icons.mail_outline,
                label: 'Correo',
                value: _email.text.trim(),
                highlighted: true,
              ),
              const SizedBox(height: 8),
              _ConfirmField(
                icon: Icons.badge_outlined,
                label: _documentType.label,
                value: _documentNumber.text.trim().toUpperCase(),
                highlighted: true,
              ),
              const SizedBox(height: 16),
              Text(
                'Te enviaremos un código a ese correo para activar tu cuenta. '
                'Si está mal escrito, no podrás entrar ni recuperar tu contraseña.',
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
              const Divider(height: 24),
              _ConfirmField(
                icon: Icons.person_outline,
                label: 'Nombre',
                value: '${_firstName.text.trim()} ${_lastName.text.trim()}',
              ),
              const SizedBox(height: 8),
              _ConfirmField(
                icon: Icons.phone_outlined,
                label: 'Teléfono',
                value: _phone.text.trim(),
              ),
              const SizedBox(height: 8),
              _ConfirmField(
                icon: Icons.account_circle_outlined,
                label: 'Usuario',
                value: _username.text.trim(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Corregir'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sí, crear cuenta'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// Muestra el error donde se ve: flotando sobre el teclado.
  ///
  /// El aviso vivia al final del formulario, debajo de los botones. En un
  /// telefono con el teclado abierto eso queda fuera de pantalla, asi que el
  /// usuario pulsaba "Iniciar sesion", no pasaba nada visible, y volvia a
  /// pulsar. Un SnackBar flotante se dibuja por encima del teclado y es ademas
  /// el mismo lenguaje que ya usa el resto de la aplicacion para confirmar un
  /// pago o avisar de un error.
  void _showErrorSnackBar(String message) {
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

  String _authErrorMessage(Object error) {
    // La logica vive en core/api_error_message.dart para que esta pantalla y la
    // de verificacion del correo no puedan divergir. Ya divergieron una vez: la
    // de verificacion comparaba texto a mano y acababa culpando a la conexion
    // de un codigo mal tecleado.
    return apiErrorMessage(
      error,
      fallback: _isRegistering
          ? 'No se pudo crear la cuenta. Revisa los datos e intenta nuevamente.'
          : 'No se pudo iniciar sesion. Revisa tus datos e intenta nuevamente.',
    );
  }
}

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

/// Una fila del diálogo de confirmación.
///
/// Los campos destacados llevan fondo y texto en negrita: son los que la
/// persona tiene que leer de verdad, y sin esa diferencia la lista entera se
/// mira por encima y el diálogo no sirve para lo que se puso.
class _ConfirmField extends StatelessWidget {
  const _ConfirmField({
    required this.icon,
    required this.label,
    required this.value,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final color =
        highlighted ? context.primaryIconColor : context.mutedIconColor;
    return Container(
      padding: highlighted
          ? const EdgeInsets.all(10)
          : const EdgeInsets.symmetric(horizontal: 2),
      decoration: highlighted
          ? BoxDecoration(
              color: context.primaryIconContainerColor,
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: highlighted ? 20 : 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: color),
                ),
                Text(
                  value.isEmpty ? '—' : value,
                  style: TextStyle(
                    fontSize: highlighted ? 16 : 13,
                    fontWeight:
                        highlighted ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Encabezado de un bloque del formulario.
///
/// El alta pide nueve datos y en una sola columna de campos identicos se leia
/// como una lista interminable: nadie sabia cuanto faltaba ni por que estaba
/// dando cada dato. Partirlo en tres bloques con nombre no acorta el
/// formulario, pero lo vuelve tres tareas cortas en vez de una larga, que es lo
/// que decide si alguien con poca practica lo termina o lo abandona.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = context.primaryIconColor;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: color,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Divider(color: color.withOpacity(0.24), height: 1)),
      ],
    );
  }
}
