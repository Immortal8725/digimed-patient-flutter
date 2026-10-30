import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The DigiMed Connect mark from the website header, resized only.
class DigimedMark extends StatelessWidget {
  const DigimedMark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/brand/digimed-mark.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'DigiMed Connect logo',
    );
  }
}

/// Mark plus wordmark, as in the website header.
class DigimedLogo extends StatelessWidget {
  const DigimedLogo({super.key, this.size = 32, this.subtitle});

  final double size;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DigimedMark(size: size),
        SizedBox(width: size * 0.3),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DigiMed Connect',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: size * 0.56,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: isDark ? DigimedBrand.darkPrimary : DigimedBrand.patient,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: size * 0.34, color: theme.colorScheme.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
