import 'dart:async';

import 'package:flutter/material.dart';

import 'app_motion.dart';
import 'app_theme.dart';

/// Quién habla o festeja.
enum CrewMember { salvador, ariana }

extension CrewAssets on CrewMember {
  String get displayName => this == CrewMember.salvador ? 'Salvador' : 'Ariana';
  String get _file => this == CrewMember.salvador ? 'salvador' : 'ariana';

  Color accentOn(BuildContext context) => this == CrewMember.salvador
      ? context.primaryIconColor
      : context.successIconColor;

  Color surfaceOn(BuildContext context) => this == CrewMember.salvador
      ? context.primaryIconContainerColor
      : context.successIconContainerColor;
}

/// Una animación concreta: qué cuadros usa, en qué orden y dónde se detiene.
///
/// Los personajes tienen dos juegos de dibujos que no se mezclan: los de hablar
/// (`salvador_0..2`) y los de festejar (`happy_salvador_0..5`). Dentro de los de
/// festejar hay a su vez dos animaciones distintas, dibujadas por separado: el
/// `0..3` es un festejo con los pies en el piso y el `4..5` es un salto. Saltar
/// de una a otra a mitad de camino se ve mal porque no comparten la posición de
/// las piernas, así que cada clip usa solo los cuadros de su propia animación.
class CrewClip {
  const CrewClip._({
    required this.prefix,
    required this.sequence,
    required this.rest,
    required this.frameDuration,
  });

  /// Prefijo del archivo. Separa el juego de dibujos de habla del de festejo.
  final String prefix;

  /// Orden en que se muestran los cuadros.
  final List<int> sequence;

  /// Cuadro en el que se queda cuando termina.
  final int rest;

  final Duration frameDuration;

  /// Habla.
  ///
  /// No es un ciclo `0,1,2` repetido. El `_2` es el saludo con la mano
  /// levantada: es un gesto puntual, no una posición de habla, y repetirlo cada
  /// pocas décimas hace que el personaje parezca agitar el brazo sin parar.
  /// Aparece una sola vez al empezar, a modo de saludo, y el resto del tiempo se
  /// alterna entre boca abierta y cerrada, que es lo que realmente parece
  /// alguien hablando.
  ///
  /// Descansa en el `_1`, donde tienen la boca cerrada. Detenerse en otro los
  /// dejaría congelados a mitad de una palabra.
  static const talking = CrewClip._(
    prefix: '',
    sequence: [2, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1],
    rest: 1,
    frameDuration: Duration(milliseconds: 240),
  );

  /// Festejo con los pies en el piso.
  ///
  /// Los cuadros van de menos a más (`0` puños al pecho, `3` los dos brazos
  /// arriba), así que se recorren en orden: el festejo crece en lugar de
  /// aparecer ya en su punto máximo. Después baja y descansa en el `0`, que es
  /// contento pero contenido; quedarse en el `3` sería un personaje con los
  /// brazos en alto para siempre.
  ///
  /// Es el clip para cualquier lugar donde el personaje se queda en pantalla: al
  /// tener los pies fijos no mueve la línea del piso ni descuadra lo que tenga
  /// al lado.
  static const cheer = CrewClip._(
    prefix: 'happy_',
    sequence: [0, 1, 2, 3, 2, 3, 1, 0],
    rest: 0,
    frameDuration: Duration(milliseconds: 200),
  );

  /// Salto.
  ///
  /// Solo dos cuadros, `4` despegando y `5` en el aire, alternados. Termina en
  /// el `0` del otro clip a propósito: es la única pose de festejo con los dos
  /// pies en el piso, así que hace de aterrizaje. Sin ella el personaje se
  /// quedaría flotando.
  ///
  /// Va en avisos que duran unos segundos y se van. En algo permanente el salto
  /// cansa, y además mueve al personaje dentro de su caja.
  static const jump = CrewClip._(
    prefix: 'happy_',
    sequence: [4, 5, 4, 5, 4, 5, 0],
    rest: 0,
    frameDuration: Duration(milliseconds: 180),
  );

  String assetFor(CrewMember member, int frame) =>
      'assets/images/crew/$prefix${member._file}_$frame.png';
}

/// El personaje animado, sin globo ni fondo.
///
/// La animación se reproduce una vez y se queda en un cuadro fijo. Un personaje
/// que gesticula sin parar deja de leerse como alguien hablando y pasa a ser un
/// elemento que se mueve mientras uno intenta leer.
class CrewSprite extends StatefulWidget {
  const CrewSprite({
    required this.member,
    required this.height,
    required this.restartKey,
    this.clip = CrewClip.talking,
    super.key,
  });

  final CrewMember member;
  final double height;
  final CrewClip clip;

  /// Cuando cambia, la animación vuelve a empezar. Suele ser el mensaje.
  final Object restartKey;

  @override
  State<CrewSprite> createState() => _CrewSpriteState();
}

class _CrewSpriteState extends State<CrewSprite> {
  Timer? _timer;
  var _step = 0;
  late var _frame = widget.clip.rest;

  @override
  void initState() {
    super.initState();
    _play();
  }

  @override
  void didUpdateWidget(CrewSprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.restartKey != widget.restartKey ||
        oldWidget.clip != widget.clip) {
      _play();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _play() {
    final clip = widget.clip;
    _timer?.cancel();
    _step = 0;
    _frame = clip.sequence.first;
    _timer = Timer.periodic(clip.frameDuration, (timer) {
      if (!mounted) return timer.cancel();
      setState(() {
        _step++;
        if (_step >= clip.sequence.length) {
          _frame = clip.rest;
          timer.cancel();
          return;
        }
        _frame = clip.sequence[_step];
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Con "reducir animaciones" activado el personaje sigue estando, pero
    // quieto: lo que molesta de estas animaciones es el movimiento, no el
    // dibujo.
    final still = animationsDisabled(context);
    if (still) _timer?.cancel();

    return SizedBox(
      height: widget.height,
      child: Image.asset(
        widget.clip.assetFor(widget.member, still ? widget.clip.rest : _frame),
        // Sin esto Flutter interpola al escalar y el pixel art se ve borroso.
        filterQuality: FilterQuality.none,
        fit: BoxFit.contain,
        // Si el asset falta, la pantalla sigue funcionando sin el personaje.
        errorBuilder: (context, error, stack) => const SizedBox.shrink(),
      ),
    );
  }
}

/// Un personaje con su globo de diálogo, uno al lado del otro.
///
/// Aparece chico, junto al texto, y nunca ocupa el centro de la pantalla: es un
/// acompañante, no el contenido.
class CrewSpeaker extends StatelessWidget {
  const CrewSpeaker({
    required this.member,
    required this.message,
    this.height = 92,
    super.key,
  });

  final CrewMember member;
  final String message;

  /// Alto del personaje. Chico a propósito: acompaña el texto, no compite.
  final double height;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        CrewSprite(member: member, height: height, restartKey: message),
        const SizedBox(width: 8),
        Expanded(
          child: _SpeechBubble(
            text: message,
            label: member.displayName,
            accent: member.accentOn(context),
            background: member.surfaceOn(context),
          ),
        ),
      ],
    );
  }
}

/// Un personaje festejando, sin globo.
///
/// Se usa donde la pantalla ya dice qué pasó: el personaje pone el tono, no la
/// información. Por eso no lleva texto propio y nunca reemplaza al mensaje.
class CrewCelebration extends StatelessWidget {
  /// Festejo con los pies en el piso, para algo que se queda en pantalla.
  const CrewCelebration.cheering({
    required this.member,
    this.height = 72,
    this.restartKey = 'celebrate',
    super.key,
  }) : clip = CrewClip.cheer;

  /// Salto, para un aviso que dura unos segundos y se va.
  ///
  /// Mas chico que el festejo de pie: en un aviso el personaje comparte la
  /// linea con el texto, que es lo que hay que leer.
  const CrewCelebration.jumping({
    required this.member,
    this.height = 56,
    this.restartKey = 'celebrate',
    super.key,
  }) : clip = CrewClip.jump;

  final CrewMember member;

  final CrewClip clip;

  final double height;

  /// Cuando cambia, vuelve a festejar. Sirve para que la animación se repita
  /// cuando hay algo nuevo que celebrar y no solo la primera vez que se dibuja.
  final Object restartKey;

  @override
  Widget build(BuildContext context) {
    return CrewSprite(
      member: member,
      height: height,
      clip: clip,
      restartKey: restartKey,
    );
  }
}

/// Los dos personajes juntos, al mismo nivel.
///
/// Con [CrewClip.talking] va sin globo de dialogo: se usa en la bienvenida,
/// donde todavia no hay nada que explicar y el texto de la pantalla es una
/// bienvenida, no algo que ellos digan. Ponerles un globo obligaria a redactar
/// todo como parlamento y sonaria forzado.
///
/// Con [CrewClip.cheer] festejan juntos. El salto no sirve aqui: los dos
/// cuerpos se alinean por el piso, y en el aire ese piso deja de existir.
class CrewDuo extends StatelessWidget {
  const CrewDuo({
    this.height = 116,
    this.clip = CrewClip.talking,
    this.restartKey = 'welcome',
    super.key,
  });

  final double height;
  final CrewClip clip;
  final Object restartKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      // Alineados abajo: lo que tiene que coincidir es el piso, no la cabeza.
      // Ariana es mas baja y alinear arriba la dejaria flotando.
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CrewSprite(
          member: CrewMember.ariana,
          height: height,
          clip: clip,
          restartKey: restartKey,
        ),
        const SizedBox(width: 28),
        CrewSprite(
          member: CrewMember.salvador,
          height: height,
          clip: clip,
          restartKey: restartKey,
        ),
      ],
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({
    required this.text,
    required this.label,
    required this.accent,
    required this.background,
  });

  final String text;
  final String label;
  final Color accent;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: AppMotion.medium,
      curve: AppMotion.curve,
      alignment: Alignment.bottomLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
            bottomRight: Radius.circular(12),
            // La esquina recta apunta al personaje: hace de rabito del globo
            // sin necesidad de dibujar uno.
            bottomLeft: Radius.zero,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}
