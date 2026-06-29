import 'package:flutter_test/flutter_test.dart';
import 'package:pocketpeers/src/core/validators.dart';

void main() {
  group('parseAmount', () {
    test('parses trimmed values with comma or dot decimal separators', () {
      expect(parseAmount(' 12.50 '), 12.5);
      expect(parseAmount('12,50'), 12.5);
    });

    test('returns zero for invalid amounts', () {
      expect(parseAmount('abc'), 0);
      expect(parseAmount(''), 0);
    });
  });

  group('requiredField', () {
    test('rejects null and blank values', () {
      expect(requiredField(null), 'Campo requerido');
      expect(requiredField('   '), 'Campo requerido');
    });

    test('accepts non blank values', () {
      expect(requiredField('texto'), isNull);
    });
  });

  group('nameField', () {
    test('requires at least two characters', () {
      expect(nameField('A'), 'Ingresa al menos 2 caracteres');
      expect(nameField('Ana'), isNull);
    });
  });

  group('usernameField', () {
    test('requires at least three characters', () {
      expect(usernameField('ab'), 'Ingresa al menos 3 caracteres');
      expect(usernameField('ana'), isNull);
    });
  });

  group('passwordField', () {
    test('requires at least six characters without trimming', () {
      expect(passwordField('12345'), 'Ingresa al menos 6 caracteres');
      expect(passwordField('123456'), isNull);
    });
  });

  group('phoneField', () {
    test('requires exactly nine digits after removing formatting', () {
      expect(phoneField('987 654 321'), isNull);
      expect(phoneField('+51 987 654 321'), 'El telefono debe tener 9 digitos');
      expect(phoneField('123'), 'El telefono debe tener 9 digitos');
    });
  });

  group('emailField', () {
    test('validates email shape', () {
      expect(emailField('ana@example.com'), isNull);
      expect(emailField('ana.example.com'), 'Ingresa un correo válido');
    });
  });

  group('positiveAmountField', () {
    test('requires a positive amount', () {
      expect(positiveAmountField('0'), 'Ingresa un monto mayor a cero');
      expect(positiveAmountField('-1'), 'Ingresa un monto mayor a cero');
      expect(positiveAmountField('10,5'), isNull);
    });
  });
}
