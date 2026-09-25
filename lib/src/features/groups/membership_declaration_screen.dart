import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_error_message.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

/// Lo que devuelve la pantalla cuando la persona firma.
class SignedMembershipDeclaration {
  const SignedMembershipDeclaration({
    required this.version,
    required this.signaturePng,
  });

  /// Version de la declaracion que se acepto.
  final String version;

  /// La firma dibujada, PNG en base64. El backend la incrusta en el PDF.
  final String signaturePng;
}

/// Muestra la declaracion jurada, pide dibujar la firma y la devuelve, o null
/// si la persona sale sin firmar.
///
/// Se pide antes de unirse con codigo ([token]) y antes de crear un grupo
/// ([groupName]). El PDF firmado lo genera y guarda el backend al procesar el
/// ingreso: aqui solo se obtienen la aceptacion y el trazo.
Future<SignedMembershipDeclaration?> signMembershipDeclaration(
  BuildContext context, {
  String? token,
  String? groupName,
}) {
  return Navigator.of(context).push<SignedMembershipDeclaration>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => MembershipDeclarationScreen(
        token: token,
        groupName: groupName,
      ),
    ),
  );
}

class MembershipDeclarationScreen extends ConsumerStatefulWidget {
  const MembershipDeclarationScreen({this.token, this.groupName, super.key});

  final String? token;
  final String? groupName;

  @override
  ConsumerState<MembershipDeclarationScreen> createState() =>
      _MembershipDeclarationScreenState();
}

class _MembershipDeclarationScreenState
    extends ConsumerState<MembershipDeclarationScreen> {
  late final Future<MembershipDeclaration> _declaration = ref
      .read(apiProvider)
      .getMembershipDeclaration(token: widget.token, groupName: widget.groupName);
  final _scroll = ScrollController();
  final _signature = SignatureController();

  /// La casilla no se habilita hasta llegar al final del texto: aceptar sin
  /// haberlo recorrido es justo lo que la declaracion no deberia permitir.
  var _readToEnd = false;
  var _accepted = false;

  /// Segundo paso: el recuadro de firma. Va en su propia vista y no debajo del
  /// texto porque dentro de algo que se desplaza, el trazo vertical se lo come
  /// el scroll.
  var _signing = false;
  var _exporting = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_checkReadToEnd);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _signature.dispose();
    super.dispose();
  }

  void _checkReadToEnd() {
    if (_readToEnd || !_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - 24) {
      setState(() => _readToEnd = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Desde la firma, "atras" vuelve al texto en vez de cerrar todo.
      canPop: !_signing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _signing) setState(() => _signing = false);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_signing ? 'Firma' : 'Declaracion jurada'),
        ),
        body: FutureBuilder<MembershipDeclaration>(
          future: _declaration,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    apiErrorMessage(snapshot.error!,
                        fallback: 'No se pudo cargar la declaracion'),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            final declaration = snapshot.data;
            if (declaration == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return _signing
                ? _buildSignatureStep(declaration)
                : _buildReadingStep(declaration);
          },
        ),
      ),
    );
  }

  Widget _buildReadingStep(MembershipDeclaration declaration) {
    // Si el texto entra entero en pantalla no hay nada que desplazar.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkReadToEnd());
    return Column(
      children: [
        Expanded(
          child: Scrollbar(
            controller: _scroll,
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              child: SelectableText(declaration.text),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CheckboxListTile(
                  value: _accepted,
                  onChanged: _readToEnd
                      ? (value) => setState(() => _accepted = value ?? false)
                      : null,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(_readToEnd
                      ? 'He leido y acepto la declaracion jurada'
                      : 'Desplazate hasta el final para aceptar'),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed:
                      _accepted ? () => setState(() => _signing = true) : null,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Continuar a la firma'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignatureStep(MembershipDeclaration declaration) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Dibuja tu firma con el dedo', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Se incluira en el PDF de la declaracion jurada '
              '(version ${declaration.version}) junto con tu nombre, tu DNI y '
              'la fecha.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 3,
              child: SignaturePad(controller: _signature),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _exporting ? null : _signature.clear,
                icon: const Icon(Icons.refresh),
                label: const Text('Borrar'),
              ),
            ),
            const Spacer(),
            ListenableBuilder(
              listenable: _signature,
              builder: (context, _) => FilledButton.icon(
                onPressed: _signature.hasSignature && !_exporting
                    ? () => _finish(declaration)
                    : null,
                icon: _exporting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.draw_outlined),
                label: const Text('Firmar y continuar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _finish(MembershipDeclaration declaration) async {
    setState(() => _exporting = true);
    try {
      final png = await _signature.toPngBytes();
      if (!mounted) return;
      Navigator.of(context).pop(SignedMembershipDeclaration(
        version: declaration.version,
        signaturePng: base64Encode(png),
      ));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}

/// Guarda los trazos de la firma y los exporta a PNG.
class SignatureController extends ChangeNotifier {
  final List<List<Offset>> _strokes = [];
  Size _canvasSize = Size.zero;

  static const _strokeWidth = 3.0;

  /// Recorrido minimo, en puntos logicos, para no aceptar un toque suelto
  /// como firma. El backend ademas rechaza una imagen casi vacia.
  static const _minInkLength = 60.0;

  List<List<Offset>> get strokes => _strokes;

  bool get hasSignature {
    var length = 0.0;
    for (final stroke in _strokes) {
      for (var i = 1; i < stroke.length; i++) {
        length += (stroke[i] - stroke[i - 1]).distance;
      }
    }
    return length >= _minInkLength;
  }

  void _start(Offset point) {
    _strokes.add([point]);
    notifyListeners();
  }

  void _extend(Offset point) {
    if (_strokes.isEmpty) return;
    _strokes.last.add(point);
    notifyListeners();
  }

  void clear() {
    _strokes.clear();
    notifyListeners();
  }

  /// Fondo transparente y trazo negro, al doble de resolucion para que la firma
  /// no se vea pixelada en el PDF impreso.
  Future<List<int>> toPngBytes({double scale = 2}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(scale);
    paintStrokes(canvas, _strokes, Colors.black);
    final image = await recorder.endRecording().toImage(
          (_canvasSize.width * scale).ceil(),
          (_canvasSize.height * scale).ceil(),
        );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  static void paintStrokes(Canvas canvas, List<List<Offset>> strokes, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, _strokeWidth / 2, paint..style = PaintingStyle.fill);
        paint.style = PaintingStyle.stroke;
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }
}

/// Recuadro donde se dibuja la firma.
class SignaturePad extends StatelessWidget {
  const SignaturePad({required this.controller, super.key});

  final SignatureController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        controller._canvasSize = size;
        Offset clamp(Offset p) => Offset(
              p.dx.clamp(0, size.width),
              p.dy.clamp(0, size.height),
            );
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: scheme.outline),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (details) => controller._start(clamp(details.localPosition)),
              onPanUpdate: (details) => controller._extend(clamp(details.localPosition)),
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) => CustomPaint(
                  size: size,
                  painter: _SignaturePainter(controller.strokes, lineColor: scheme.outlineVariant),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.strokes, {required this.lineColor});

  final List<List<Offset>> strokes;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Linea guia, como en un papel. Solo se ve aqui: el PNG exportado lleva
    // unicamente el trazo.
    final baseline = size.height * 0.75;
    canvas.drawLine(
      Offset(16, baseline),
      Offset(size.width - 16, baseline),
      Paint()
        ..color = lineColor
        ..strokeWidth = 1,
    );
    SignatureController.paintStrokes(canvas, strokes, Colors.black);
  }

  // Los trazos se modifican en el sitio, asi que no hay forma barata de saber
  // si cambiaron: se repinta siempre que el controlador avisa.
  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
