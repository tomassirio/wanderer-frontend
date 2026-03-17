import 'package:flutter/material.dart';
import '../../../core/theme/wanderer_theme.dart';

/// Wanderer app logo - uses the wanderer-logo.png asset
class WandererLogo extends StatelessWidget {
  final double size;
  final Color?
      color; // Kept for backward compatibility, but not used with image
  final bool showBorder;

  const WandererLogo({
    super.key,
    this.size = 40,
    this.color,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final borderWidth = showBorder ? (size * 0.06).clamp(1.5, 4.0) : 0.0;
    final totalSize = size + borderWidth * 2;

    return Container(
      width: totalSize,
      height: totalSize,
      decoration: showBorder
          ? BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: WandererTheme.primaryOrange,
                width: borderWidth,
              ),
            )
          : null,
      child: ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: Transform.scale(
            scale: 1.6,
            child: Image.asset(
              'assets/images/wanderer-logo.png',
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}
