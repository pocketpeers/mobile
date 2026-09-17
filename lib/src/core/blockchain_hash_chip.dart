import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';
import 'formatters.dart';

class BlockchainHashChip extends StatelessWidget {
  const BlockchainHashChip({
    required this.hash,
    this.compact = false,
    this.onRefresh,
    super.key,
  });

  final String hash;
  final bool compact;

  /// Que hacer cuando el hash todavia no llego y alguien toca el chip.
  ///
  /// El hash se escribe en la cadena despues de guardar el gasto, asi que al
  /// abrir la pantalla casi nunca esta listo. Antes habia un temporizador que
  /// consultaba doce veces cada tres segundos: se rendia a los 36 s aunque el
  /// backend admite hasta 90 s esperando la confirmacion, de modo que en las
  /// confirmaciones lentas gastaba 24 peticiones para terminar mostrando
  /// "Pendiente" igual.
  ///
  /// Dejarlo en manos de quien mira cuesta una peticion, ocurre solo cuando a
  /// alguien le interesa el dato, y no se rinde nunca.
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final normalizedHash = hash.trim();
    final available = normalizedHash.isNotEmpty;
    final canRefresh = !available && onRefresh != null;
    final iconColor =
        available ? context.successIconColor : context.primaryIconColor;
    final backgroundColor = available
        ? context.successIconContainerColor
        : context.primaryIconContainerColor;
    return Tooltip(
      message: available
          ? 'Copiar hash blockchain'
          : canRefresh
              ? 'Toca para comprobar si ya se registro'
              : 'Hash blockchain pendiente',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: available
            ? () async {
                await Clipboard.setData(ClipboardData(text: normalizedHash));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Hash blockchain copiado')),
                  );
                }
              }
            : onRefresh,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10,
            vertical: compact ? 5 : 7,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: iconColor.withOpacity(0.24)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Un chip que dice "Pendiente" con un icono de enlace no invita a
              // tocarlo. Con el de recarga, la accion se explica sola.
              Icon(canRefresh ? Icons.refresh : Icons.link_outlined,
                  size: compact ? 14 : 16, color: iconColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  formatBlockchainHash(normalizedHash),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: iconColor,
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 12 : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
