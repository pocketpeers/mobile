import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'config.dart';

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
