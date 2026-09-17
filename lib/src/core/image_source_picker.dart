import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'app_theme.dart';

Future<XFile?> pickImageFromCameraOrGallery(
  BuildContext context, {
  ImagePicker? picker,
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
    return await (picker ?? ImagePicker()).pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el selector de imagen')),
      );
    }
    return null;
  }
}
