import 'package:android_id/android_id.dart';

/// Identificador estable del teléfono, para los topes de verificación de DNI.
///
/// El backend limita cuántos DNI distintos y cuántos intentos fallidos puede
/// hacer un mismo teléfono al día, porque cada consulta del DNI sale de una
/// cuota mensual fija. Para eso necesita reconocer el teléfono entre un intento
/// y otro.
///
/// Se usa el ANDROID_ID y no un identificador generado por la app: este último
/// se pierde al desinstalar, y bastaría reinstalar para reiniciar el contador.
/// El ANDROID_ID se mantiene para esta app en este teléfono aunque se reinstale.
///
/// Devuelve null si no se puede obtener (otra plataforma, pruebas). El backend
/// lo acepta: esas peticiones comparten un contador común, más estricto.
class DeviceId {
  DeviceId._();

  static String? _cached;

  static Future<String?> get() async {
    if (_cached != null) return _cached;
    try {
      _cached = await const AndroidId().getId();
    } catch (_) {
      // Sin el plugin nativo (pruebas, plataforma no soportada) no hay id.
      return null;
    }
    return _cached;
  }
}
