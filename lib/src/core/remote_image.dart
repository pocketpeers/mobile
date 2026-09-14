import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'app_theme.dart';
import 'config.dart';

/// Vista previa de una foto elegida que todavia no se ha subido.
///
/// Existe para poder diferir la subida hasta el guardado. Sin esto el
/// formulario tendria que subir la imagen en cuanto se elige, solo para poder
/// mostrarla, y cada foto descartada quedaria en la base sin que nada la
/// referencie: la persona prueba tres y se queda con una, pero las tres
/// ocupan espacio para siempre.
///
/// Mientras el archivo siga siendo local la vista sale del disco; una vez
/// guardado, [pendingFile] vuelve a ser null y la vista sale del servidor.
class PhotoPreview extends StatelessWidget {
  const PhotoPreview({
    required this.pendingFile,
    required this.imageRef,
    required this.fallbackIcon,
    this.size = 44,
    this.borderRadius = 8,
    super.key,
  });

  /// Archivo recien elegido que aun no se sube. Null si no hay ninguno
  /// pendiente, y entonces manda [imageRef].
  final XFile? pendingFile;

  final String imageRef;
  final IconData fallbackIcon;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final pending = pendingFile;
    if (pending == null) {
      return RemoteAvatar(
        imageRef: imageRef,
        fallbackIcon: fallbackIcon,
        size: size,
        borderRadius: borderRadius,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.file(
        File(pending.path),
        width: size,
        height: size,
        fit: BoxFit.cover,
        // Si el archivo desaparece entre que se elige y se pinta, mostrar el
        // marcador de siempre es mejor que romper el formulario entero.
        errorBuilder: (context, error, stackTrace) => RemoteAvatar(
          imageRef: imageRef,
          fallbackIcon: fallbackIcon,
          size: size,
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}

class RemoteAvatar extends StatelessWidget {
  const RemoteAvatar({
    required this.imageRef,
    required this.fallbackIcon,
    this.size = 44,
    this.borderRadius = 8,
    this.backgroundColor,
    this.iconColor,
    super.key,
  });

  final String imageRef;
  final IconData fallbackIcon;
  final double size;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final url = remoteImageUrl(imageRef);
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? context.primaryIconContainerColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(
        fallbackIcon,
        color: iconColor ?? context.primaryIconColor,
        size: size * 0.48,
      ),
    );

    if (url == null) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return fallback;
        },
      ),
    );
  }
}

String? remoteImageUrl(String imageRef) {
  final value = imageRef.trim();
  if (value.isEmpty) return null;
  if (value.startsWith('http://') || value.startsWith('https://')) return value;
  final baseUrl = AppConfig.apiBaseUrl.replaceFirst(RegExp(r'/+$'), '');
  if (value.startsWith('/')) return '$baseUrl$value';
  return '$baseUrl/api/v1/images/$value';
}
