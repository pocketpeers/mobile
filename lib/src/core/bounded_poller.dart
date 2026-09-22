import 'dart:async';

/// Recarga una pantalla unas cuantas veces mientras esta abierta, y para.
///
/// Existe por un caso concreto: dos personas del mismo grupo mirando la misma
/// deuda desde sus teléfonos. Cuando una registra el pago, la otra no se entera
/// —su pantalla sigue diciendo «pendiente»— porque nada le avisa. Sin esto, la
/// única salida es salir y volver a entrar, y nadie adivina que hay que hacerlo.
///
/// **Por qué acotado y no permanente.** Una pantalla que consulta para siempre
/// gasta batería y datos del participante toda la tarde por un cambio que quizá
/// nunca llega. Y en el trabajo de campo son cien personas en datos móviles
/// contra una VM de 4 GB. Unas pocas pasadas cubren la ventana en la que de
/// verdad se espera algo —el otro acaba de pagar, el anclaje está en camino— y
/// después la pantalla queda quieta, con el gesto de deslizar disponible para
/// quien quiera comprobar más tarde.
///
/// Hubo antes un temporizador que consultaba doce veces cada tres segundos y
/// solo miraba si había llegado el hash. Eran dos problemas: gastaba 24
/// peticiones para acabar mostrando «Pendiente» igual, y al detenerse en cuanto
/// el hash aparecía dejaba de ver cualquier otro cambio, que es justamente el
/// que llega desde otro teléfono.
class BoundedPoller {
  BoundedPoller({
    required this.onTick,
    this.interval = const Duration(seconds: 4),
    this.maxTicks = 5,
  });

  /// Qué recargar en cada pasada.
  final void Function() onTick;

  final Duration interval;

  /// Cuántas pasadas antes de quedarse quieto.
  final int maxTicks;

  Timer? _timer;
  int _ticks = 0;

  bool get isRunning => _timer != null;

  /// Arranca. Si ya estaba corriendo no hace nada, para que reconstruir la
  /// pantalla no reinicie la cuenta ni abra un segundo temporizador.
  void start() {
    if (_timer != null) return;
    _ticks = 0;
    _timer = Timer.periodic(interval, (_) {
      _ticks++;
      onTick();
      if (_ticks >= maxTicks) stop();
    });
  }

  /// Vuelve a empezar la cuenta. Se usa tras un gesto de deslizar: si alguien
  /// pide datos frescos a mano, es que sigue esperando algo.
  void restart() {
    stop();
    start();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => stop();
}
