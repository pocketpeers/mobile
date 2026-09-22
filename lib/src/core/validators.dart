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

/// Misma politica que `PasswordPolicy` del backend, con los mismos mensajes.
///
/// Antes pedia 6 caracteres y nada mas, mientras el servidor exigia 8 con al
/// menos una letra y un numero. Una clave como "123456" pasaba aqui y la
/// rechazaban alla, asi que el aviso llegaba despues del viaje de ida y vuelta
/// —y en el registro eso significa tener que volver a escribirlo todo—.
///
/// El limite de 72 no es arbitrario: BCrypt ignora lo que pase de ahi, y
/// aceptar mas daria la falsa impresion de que esos caracteres protegen algo.
String? passwordField(String? value) {
  final required = requiredField(value);
  if (required != null) return required;
  final password = value!;
  if (password.length < 8) {
    return 'La contraseña debe tener al menos 8 caracteres';
  }
  if (password.length > 72) {
    return 'La contraseña no puede tener más de 72 caracteres';
  }
  if (!RegExp(r'[A-Za-zÀ-ÿ]').hasMatch(password)) {
    return 'La contraseña debe incluir al menos una letra';
  }
  if (!RegExp(r'\d').hasMatch(password)) {
    return 'La contraseña debe incluir al menos un número';
  }
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

/// Tipos de documento de identidad admitidos en el registro.
///
/// Los valores de [apiValue] tienen que coincidir letra por letra con el enum
/// `DocumentType` del backend: si se separan, el registro falla con un mensaje
/// que habla de un tipo no valido y cuesta relacionarlo con este archivo.
enum IdDocumentType { dni, ce, pasaporte }

extension IdDocumentTypeX on IdDocumentType {
  String get apiValue => switch (this) {
        IdDocumentType.dni => 'DNI',
        IdDocumentType.ce => 'CE',
        IdDocumentType.pasaporte => 'PASAPORTE',
      };

  String get label => switch (this) {
        IdDocumentType.dni => 'DNI',
        IdDocumentType.ce => 'Carné de extranjería',
        IdDocumentType.pasaporte => 'Pasaporte',
      };

  int get maxLength => switch (this) {
        IdDocumentType.dni => 8,
        IdDocumentType.ce => 10,
        IdDocumentType.pasaporte => 12,
      };

  /// Si el numero es solo digitos.
  ///
  /// Decide el teclado que se abre y si se filtran las letras al escribir. El
  /// pasaporte es el unico alfanumerico: su formato lo fija cada pais emisor.
  bool get isNumericOnly => this != IdDocumentType.pasaporte;

  /// Lo que se espera, dicho antes de escribir y no despues de fallar.
  String get formatHint => switch (this) {
        IdDocumentType.dni => 'Son 8 digitos',
        IdDocumentType.ce => 'Son 9 o 10 digitos',
        IdDocumentType.pasaporte => 'Entre 6 y 12 caracteres',
      };
}

/// Valida el numero segun el tipo elegido.
///
/// Se normaliza igual que en el servidor —sin espacios, guiones ni puntos, y en
/// mayusculas— antes de comprobar el formato. Si aqui se aceptara "1234-5678"
/// tal cual, el backend lo guardaria como "12345678" y la persona veria en su
/// perfil algo distinto de lo que escribio.
String? Function(String?) documentNumberField(IdDocumentType type) {
  return (String? value) {
    final required = requiredField(value);
    if (required != null) return required;

    final normalized =
        value!.trim().toUpperCase().replaceAll(RegExp(r'[\s.-]'), '');

    return switch (type) {
      IdDocumentType.dni => RegExp(r'^\d{8}$').hasMatch(normalized)
          ? null
          : 'El DNI debe tener exactamente 8 dígitos',
      // Nueve o diez digitos, sin letras: es el formato que emite Migraciones.
      // Antes aceptaba de 8 a 12 alfanumericos y dejaba pasar numeros que no
      // existen. Tiene que coincidir con DocumentType.CE del backend; si se
      // separan, el formulario aprueba lo que el servidor rechaza.
      IdDocumentType.ce => RegExp(r'^\d{9,10}$').hasMatch(normalized)
          ? null
          : 'El carné de extranjería debe tener 9 o 10 dígitos',
      IdDocumentType.pasaporte => RegExp(r'^[A-Z0-9]{6,12}$')
              .hasMatch(normalized)
          ? null
          : 'El pasaporte debe tener entre 6 y 12 caracteres',
    };
  };
}
