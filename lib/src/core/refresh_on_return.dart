import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Observador de rutas de la aplicación. Se registra en el `GoRouter`.
///
/// Es lo que permite que una pantalla se entere de que volvieron a ella.
final appRouteObserver = RouteObserver<ModalRoute<void>>();

/// Recarga los datos de una pantalla cuando se vuelve a ella.
///
/// El caso: se abre un gasto desde el grupo, se confirma un pago, se pulsa
/// atrás — y el grupo sigue mostrando el saldo de antes. Los datos estaban en
/// memoria desde que se dejó la pantalla, y nada le dijo que habían cambiado.
///
/// **Por qué un observador y no recargar en cada `push`.** Se podría esperar el
/// resultado de cada `context.push(...)` y recargar al volver, pero eso obliga
/// a acordarse en cada sitio que navega, y basta olvidarse en uno para que esa
/// ruta quede desactualizada sin que nadie lo note. `didPopNext` se dispara
/// siempre que esta pantalla vuelve a quedar al frente, venga de donde venga y
/// se haya vuelto con el botón de la app, con el gesto o con el botón físico.
///
/// Es una recarga por regreso, no un sondeo: no compite con [BoundedPoller],
/// que cubre los cambios que ocurren mientras la pantalla está abierta.
mixin RefreshOnReturn<T extends ConsumerStatefulWidget> on ConsumerState<T>
    implements RouteAware {
  /// Qué volver a pedir cuando se regresa a esta pantalla.
  void onReturnToScreen();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      // Se vuelve a suscribir en cada cambio de dependencias a propósito: el
      // observador ignora los duplicados y así la suscripción sobrevive a que
      // la ruta cambie bajo los pies de la pantalla.
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  /// La pantalla de encima se cerró y esta vuelve a estar al frente.
  @override
  void didPopNext() {
    if (mounted) onReturnToScreen();
  }

  @override
  void didPush() {}

  @override
  void didPop() {}

  @override
  void didPushNext() {}
}
