import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocketpeers/src/features/groups/membership_declaration_screen.dart';

void main() {
  test('un toque suelto no cuenta como firma', () {
    final controller = SignatureController();
    controller.strokes.add([const Offset(10, 10)]);

    expect(controller.hasSignature, isFalse);
  });

  test('un trazo con recorrido suficiente cuenta como firma', () {
    final controller = SignatureController();
    controller.strokes.add([
      const Offset(10, 10),
      const Offset(60, 40),
      const Offset(120, 20),
    ]);

    expect(controller.hasSignature, isTrue);
  });

  test('borrar deja el recuadro vacio', () {
    final controller = SignatureController();
    controller.strokes.add([const Offset(0, 0), const Offset(200, 0)]);

    controller.clear();

    expect(controller.hasSignature, isFalse);
  });
}
