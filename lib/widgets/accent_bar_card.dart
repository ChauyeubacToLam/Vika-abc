import 'package:flutter/material.dart';

import '../theme/vf_theme.dart';

class AccentBarCard extends StatelessWidget {
  const AccentBarCard({
    super.key,
    required this.accentColor,
    required this.child,
    this.opacity = 1,
    this.padding,
  });

  final Color accentColor;
  final Widget child;
  final double opacity;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        decoration: BoxDecoration(
          color: VFTheme.surface,
          borderRadius: BorderRadius.circular(VFTheme.cardRadius(context)),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4 * VFTheme.scale(context), color: accentColor),
              Expanded(
                child: Padding(
                  padding: padding ??
                      EdgeInsets.fromLTRB(
                        14 * VFTheme.scale(context),
                        14 * VFTheme.scale(context),
                        14 * VFTheme.scale(context),
                        12 * VFTheme.scale(context),
                      ),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
