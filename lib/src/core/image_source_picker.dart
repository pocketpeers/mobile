import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

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
}) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(
              Icons.photo_camera_outlined,
              color: context.primaryIconColor,
            ),
            title: const Text('Tomar foto'),
            onTap: () => Navigator.of(context).pop(ImageSource.camera),
          ),
          ListTile(
            leading: Icon(
              Icons.photo_library_outlined,
              color: context.primaryIconColor,
            ),
            title: const Text('Elegir de galeria'),
            onTap: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
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
/// Si la persona cancela, se devuelve la imagen original en vez de null:
/// cancelar el recorte significa "me vale como esta", no "ya no quiero subir
/// nada". Tratarlo como una cancelacion obligaria a repetir la eleccion desde
/// el principio.
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
    return cropped == null ? picked : XFile(cropped.path);
  } catch (_) {
    // Que falle el recorte no debe costar la foto: se sube la original y el
    // servidor la reescala igual.
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el recorte; se usara la foto completa')),
      );
    }
    return picked;
  }
}
