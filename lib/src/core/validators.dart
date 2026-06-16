double parseAmount(String value) =>
    double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;

String? requiredField(String? value) {
  if (value == null || value.trim().isEmpty) return 'Campo requerido';
  return null;
}

String? nameField(String? value) {
  final required = requiredField(value);
  if (required != null) return required;
  if (value!.trim().length < 2) return 'Ingresa al menos 2 caracteres';
  return null;
}

String? usernameField(String? value) {
  final required = requiredField(value);
  if (required != null) return required;
  if (value!.trim().length < 3) return 'Ingresa al menos 3 caracteres';
  return null;
}

String? passwordField(String? value) {
  final required = requiredField(value);
  if (required != null) return required;
  if (value!.length < 6) return 'Ingresa al menos 6 caracteres';
  return null;
}

String? phoneField(String? value) {
  final required = requiredField(value);
  if (required != null) return required;
  final digits = value!.replaceAll(RegExp(r'\D'), '');
  if (digits.length != 9) return 'El telefono debe tener 9 digitos';
  return null;
}

String? emailField(String? value) {
  final required = requiredField(value);
  if (required != null) return required;
  final email = value!.trim();
  final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  if (!valid) return 'Ingresa un correo válido';
  return null;
}

String? positiveAmountField(String? value) {
  final required = requiredField(value);
  if (required != null) return required;
  final amount = parseAmount(value!);
  if (amount <= 0) return 'Ingresa un monto mayor a cero';
  return null;
}
