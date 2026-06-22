import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';
import 'formatters.dart';

class BlockchainHashChip extends StatelessWidget {
  const BlockchainHashChip({
    required this.hash,
    this.compact = false,
    super.key,
  });

  final String hash;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final normalizedHash = hash.trim();
    final available = normalizedHash.isNotEmpty;
    final iconColor =
        available ? context.successIconColor : context.primaryIconColor;
    final backgroundColor = available
        ? context.successIconContainerColor
        : context.primaryIconContainerColor;
    return Tooltip(
      message:
          available ? 'Copiar hash blockchain' : 'Hash blockchain pendiente',
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
            : null,
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
              Icon(Icons.link_outlined,
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
