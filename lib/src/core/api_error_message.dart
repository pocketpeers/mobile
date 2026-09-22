import 'package:dio/dio.dart';

/// Traduce un error de red a un mensaje que el usuario pueda entender.
///
/// La regla que ordena todo esto: **si el servidor respondió, el problema no es
/// la conexión**. Decir "revisa tu internet" cuando el backend contestó
/// perfectamente —por ejemplo para avisar de que un código es incorrecto—
/// manda a la persona a revisar su wifi durante diez minutos por un error que
/// no tiene nada que ver.
///
/// El orden de preferencia es deliberado:
///
/// 1. El mensaje que mandó el backend, si lo hay. Viene en español y sabe qué
///    pasó exactamente; ninguna heurística de aquí lo va a mejorar.
/// 2. El código de estado, para los casos donde el servidor no explica.
/// 3. El tipo de fallo de Dio, que es lo único que de verdad indica un problema
///    de red: ahí sí no hubo respuesta.
/// 4. El texto de reserva que pase quien llama, específico de su pantalla.
String apiErrorMessage(Object error, {required String fallback}) {
  if (error is! DioException) return fallback;

  final backendMessage = _backendMessage(error.response?.data);
  if (backendMessage != null && backendMessage.trim().isNotEmpty) {
    return backendMessage;
  }

  final statusCode = error.response?.statusCode;
  if (statusCode == 401 || statusCode == 403) {
    return 'No tienes permiso para hacer esto.';
  }
  if (statusCode == 409) {
    return 'Ya existe un registro con esos datos.';
  }
  if (statusCode != null && statusCode >= 500) {
    return 'El servidor no pudo procesar la solicitud. Intenta nuevamente.';
  }
  // Solo a partir de aquí se habla de conexión: son los casos en los que no
  // llegó ninguna respuesta.
  if (error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout) {
    return 'La conexión está tardando demasiado. Revisa tu red e intenta otra vez.';
  }
  if (error.type == DioExceptionType.connectionError) {
    return 'No se pudo conectar con el servidor. Revisa tu conexión a internet.';
  }

  return fallback;
}

/// Saca el texto que el backend puso en el cuerpo del error.
String? _backendMessage(Object? data) {
  if (data is Map) {
    final message = data['message'] ?? data['error'];
    if (message != null) return message.toString();
    if (data.isNotEmpty) return data.values.first.toString();
  }
  if (data is String && data.trim().isNotEmpty) return data;
  return null;
}
