import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import 'app_motion.dart';
import 'app_theme.dart';

/// Elige una imagen de la camara o de la galeria.
///
/// [cropToSquare] abre el recorte despues de elegirla, con la proporcion fija
/// en 1:1. Va apagado por defecto **a proposito**, y no por comodidad: hay dos
/// clases de imagen en esta aplicacion y tratarlas igual estropearia una.
///
/// Las fotos de perfil y de grupo se muestran dentro de un circulo. Si la
/// original no es cuadrada, algo se recorta igual; la unica diferencia es si lo
/// decide la persona o lo decide un recorte centrado que puede dejar fuera
/// justo la cara.
///
/// Los comprobantes y las evidencias de pago **no se recortan nunca**. Recortar
/// uno puede dejar fuera el monto o la fecha, que es lo que el OCR necesita
/// leer; y cambia los bytes de la imagen, con lo que su huella SHA-256 deja de
/// coincidir y la deteccion de comprobantes repetidos dejaria pasar el mismo
/// recibo dos veces con solo recortarlo distinto.
Future<XFile?> pickImageFromCameraOrGallery(
  BuildContext context, {
  ImagePicker? picker,
  bool cropToSquare = false,
  String title = 'Agregar foto',
  String? hint,
}) async {
  final source = await showImageSourceDialog(context, title: title, hint: hint);
  if (source == null) return null;

  try {
    // El limite de 1600 px no es una decision de calidad: es el mismo
    // MAX_IMAGE_SIDE al que ImageServiceImpl reescala en el servidor, asi que
    // la imagen que queda almacenada es identica con o sin esto. Lo unico que
    // cambia es donde se hace el trabajo.
    //
    // Sin el limite se sube el JPEG original de la camara. Un celular de 48 MP
    // produce una imagen que al decodificarse ocupa ~192 MB en el backend, que
    // corre con -Xmx640m y -XX:+ExitOnOutOfMemoryError: tres subidas simultaneas
    // tumban el proceso. Capando aca, la misma foto ocupa ~10 MB.
    //
    // Importa ademas para el trabajo de campo: la subida pasa de varios MB a
    // unos cientos de KB, y los participantes estaran en datos moviles.
    //
    // No afecta al OCR, que descarga la imagen ya almacenada y por tanto
    // siempre trabajo sobre la version capada a 1600.
    final picked = await (picker ?? ImagePicker()).pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked == null || !cropToSquare) return picked;
    return _cropToSquare(context, picked);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el selector de imagen')),
      );
    }
    return null;
  }
}

/// Abre el recorte cuadrado y devuelve el resultado.
///
/// Si la persona sale del recorte sin confirmar, se descarta la foto y se
/// devuelve null. Retroceder de esa pantalla es la unica forma que tiene de
/// arrepentirse una vez elegido el archivo: si en su lugar se quedara la
/// imagen original, la foto aparece puesta sin que nadie la haya aceptado y
/// hay que quitarla a mano.
///
/// El coste es repetir la eleccion desde el principio, que es exactamente lo
/// que esta pidiendo quien retrocede.
Future<XFile?> _cropToSquare(BuildContext context, XFile picked) async {
  try {
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressQuality: 85,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Recorta tu foto',
          toolbarColor: const Color(0xFF0B2545),
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: const Color(0xFF134074),
          // La proporcion queda fija: estas fotos se ven dentro de un circulo,
          // asi que dejar elegir otra solo permite componer un recorte que
          // luego se va a recortar igual.
          lockAspectRatio: true,
          hideBottomControls: true,
          initAspectRatio: CropAspectRatioPreset.square,
        ),
        IOSUiSettings(
          title: 'Recorta tu foto',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );
    return cropped == null ? null : XFile(cropped.path);
  } catch (_) {
    // Esto es un fallo al abrir el recorte, no una decision de la persona: no
    // llego a ver la pantalla, asi que no ha descartado nada. Se sube la
    // original y el servidor la reescala igual.
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('No se pudo abrir el recorte; se usara la foto completa')),
      );
    }
    return picked;
  }
}

/// Pregunta de donde sale la imagen: camara o galeria.
///
/// Antes era una hoja inferior con dos filas de texto sueltas, que en modo
/// oscuro se confundian con el fondo y no decian para que era la foto. Ahora es
/// un dialogo con el motivo arriba y dos opciones grandes, faciles de tocar
/// con el pulgar. Los colores salen de la paleta de la app y no del esquema
/// que Material deriva del color base, que en oscuro daba un fondo que no
/// combinaba con las tarjetas.
Future<ImageSource?> showImageSourceDialog(
  BuildContext context, {
  String title = 'Agregar foto',
  String? hint,
}) {
  return showAppDialog<ImageSource>(
    context: context,
    builder: (context) => _ImageSourceDialog(title: title, hint: hint),
  );
}

class _ImageSourceDialog extends StatelessWidget {
  const _ImageSourceDialog({required this.title, this.hint});

  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = context.isDarkMode;
    return Dialog(
      backgroundColor: dark ? AppColors.darkSurface : Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: dark ? AppColors.darkLine : AppColors.line),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: dark ? Colors.white : AppColors.navy,
                ),
              ),
              if (hint != null) ...[
                const SizedBox(height: 6),
                Text(
                  hint!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: context.mutedIconColor),
                ),
              ],
              const SizedBox(height: 20),
              // IntrinsicHeight: las dos opciones miden lo mismo aunque una
              // etiqueta se parta en dos lineas con letra grande.
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _SourceOption(
                        icon: Icons.photo_camera_outlined,
                        label: 'Tomar foto',
                        caption: 'Con la camara',
                        onTap: () =>
                            Navigator.of(context).pop(ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SourceOption(
                        icon: Icons.photo_library_outlined,
                        label: 'Galeria',
                        caption: 'De tus fotos',
                        onTap: () =>
                            Navigator.of(context).pop(ImageSource.gallery),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: context.mutedIconColor,
                ),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceOption extends StatelessWidget {
  const _SourceOption({
    required this.icon,
    required this.label,
    required this.caption,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = context.isDarkMode;
    final radius = BorderRadius.circular(16);
    return Semantics(
      button: true,
      label: '$label. $caption',
      excludeSemantics: true,
      child: Material(
        // Un escalon por encima del fondo del dialogo, en los dos modos: asi
        // la opcion se lee como algo que se toca y no como texto suelto.
        color: dark ? const Color(0xFF102F53) : AppColors.mist,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: dark ? AppColors.darkLine : AppColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.primaryIconContainerColor,
                  ),
                  child: Icon(icon, size: 28, color: context.primaryIconColor),
                ),
                const SizedBox(height: 12),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: dark ? Colors.white : AppColors.navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  caption,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: context.mutedIconColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
