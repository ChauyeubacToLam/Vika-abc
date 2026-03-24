import 'package:flutter/material.dart';

import '../theme/vf_theme.dart';

class SectionHead extends StatelessWidget {
  const SectionHead({
    super.key,
    required this.title,
    this.action,
  });

  final String title;
  final String? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 20 * VFTheme.scale(context),
        bottom: 10 * VFTheme.scale(context),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: VFTheme.sectionTitle(context)),
          ),
          if (action != null)
            Text(
              action!,
              style: TextStyle(
                fontSize: VFTheme.font(context, 12),
                color: VFTheme.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}
