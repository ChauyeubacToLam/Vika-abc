// HomeSignoff — small closing brand mark at the bottom of Home. Gives the
// page a deliberate ending so it doesn't just trail off into the bottom
// nav. Pattern borrowed from the v5 onboarding closer's "VIKA · ..." mark.
//
// Sparkle + tracked uppercase + thin hairline. Soft enough that it reads
// like a colophon, not another action.

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class HomeSignoff extends StatelessWidget {
  const HomeSignoff({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(24, 36, 24, 0),
  });

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: c.border)),
          const SizedBox(width: 14),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: c.yellow,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'VIKA',
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              color: c.inkSoft,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '·',
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: c.inkFaint,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'HLV CÁ NHÂN',
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
              fontStyle: FontStyle.italic,
              color: c.inkFaint,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Container(height: 1, color: c.border)),
        ],
      ),
    );
  }
}
