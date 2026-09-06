import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/app_motion.dart';
import '../../../core/app_theme.dart';

/// Quién habla en un paso del tutorial.
enum CrewMember { salvador, ariana }

extension CrewAssets on CrewMember {
  String get displayName => this == CrewMember.salvador ? 'Salvador' : 'Ariana';
  String get _file => this == CrewMember.salvador ? 'salvador' : 'ariana';

  /// Tres cuadros por personaje: `_0`, `_1` y `_2`.
  List<String> get frames => [
        for (var i = 0; i < _CrewSprite.frameCount; i++)
          'assets/images/crew/${_file}_$i.png',
      ];

  Color accentOn(BuildContext context) => this == CrewMember.salvador
      ? context.primaryIconColor
      : context.successIconColor;

  Color surfaceOn(BuildContext context) => this == CrewMember.salvador
      ? context.primaryIconContainerColor
      : context.successIconContainerColor;
}

/// El personaje animado, sin globo.
///
/// La animación se detiene después de unos ciclos y se queda en un cuadro fijo.
/// Un personaje que gesticula sin parar deja de leerse como alguien hablando y
/// pasa a ser un elemento que se mueve mientras uno intenta leer.
class _CrewSprite extends StatefulWidget {
  const _CrewSprite({
    required this.member,
    required this.height,
    required this.restartKey,
  });

  /// Cuadros disponibles por personaje.
  static const frameCount = 3;

  /// Cuadro en el que se queda al terminar de hablar.
  ///
  /// Es el `_1`, donde los personajes tienen la boca cerrada. Detenerse en otro
  /// los dejaría congelados a mitad de una palabra.
  static const restFrame = 1;

  /// Orden en que se muestran los cuadros.
  ///
  /// No es un ciclo `0,1,2` repetido. El `_2` es el saludo con la mano
  /// levantada: es un gesto puntual, no una posición de habla, y repetirlo cada
  /// pocas décimas hace que el personaje parezca agitar el brazo sin parar.
  /// Aparece una sola vez al empezar, a modo de saludo, y el resto del tiempo se
  /// alterna entre boca abierta y cerrada, que es lo que realmente parece
  /// alguien hablando.
  static const sequence = <int>[2, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1];

  final CrewMember member;
  final double height;

  /// Cuando cambia, el personaje vuelve a hablar. Suele ser el mensaje.
  final Object restartKey;

  @override
  State<_CrewSprite> createState() => _CrewSpriteState();
}

class _CrewSpriteState extends State<_CrewSprite> {
  static const _frameDuration = Duration(milliseconds: 240);

  Timer? _timer;
  var _step = 0;
  var _frame = _CrewSprite.restFrame;

  @override
  void initState() {
    super.initState();
    _startTalking();
  }

  @override
  void didUpdateWidget(_CrewSprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.restartKey != widget.restartKey) _startTalking();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTalking() {
    _timer?.cancel();
    _step = 0;
    _frame = _CrewSprite.sequence.first;
    _timer = Timer.periodic(_frameDuration, (timer) {
      if (!mounted) return timer.cancel();
      setState(() {
        _step++;
        if (_step >= _CrewSprite.sequence.length) {
          _frame = _CrewSprite.restFrame;
          timer.cancel();
          return;
        }
        _frame = _CrewSprite.sequence[_step];
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Image.asset(
        widget.member.frames[_frame],
        // Sin esto Flutter interpola al escalar y el pixel art se ve borroso.
        filterQuality: FilterQuality.none,
        fit: BoxFit.contain,
        // Si el asset falta, el tutorial sigue funcionando sin el personaje.
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
        _CrewSprite(member: member, height: height, restartKey: message),
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

/// Los dos personajes juntos, al mismo nivel.
///
/// Se usa solo en la bienvenida, y a proposito va sin globo de dialogo: ahi
/// todavia no hay nada que explicar y el texto de la pantalla es una bienvenida,
/// no algo que ellos digan. Ponerles un globo obligaria a redactar todo como
/// parlamento y sonaria forzado.
class CrewDuo extends StatelessWidget {
  const CrewDuo({this.height = 116, super.key});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Row(
      // Alineados abajo: lo que tiene que coincidir es el piso, no la cabeza.
      // Ariana es mas baja y alinear arriba la dejaria flotando.
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CrewSprite(
          member: CrewMember.ariana,
          height: height,
          restartKey: 'welcome',
        ),
        const SizedBox(width: 28),
        _CrewSprite(
          member: CrewMember.salvador,
          height: height,
          restartKey: 'welcome',
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
