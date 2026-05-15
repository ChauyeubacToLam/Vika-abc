// IdentityBlock — 88px avatar + italic name display + member meta on the
// Profile screen. Mirrors `ProfileIdentityBlock` in
// vika-main-app-ivory-v1.jsx.

import 'package:flutter/material.dart';

import '../plan/plan_typography.dart';
import '../../theme/app_colors.dart';
class IdentityBlock extends StatelessWidget {
  const IdentityBlock({
    super.key,
    required this.name,
    required this.initial,
    required this.memberSince,
    required this.level,
    required this.phase,
    this.padding = const EdgeInsets.fromLTRB(24, 20, 24, 0),
  });

  final String name;
  final String initial;
  final String memberSince;
  final String level;
  final String phase;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: c.bgInverse,
              shape: BoxShape.circle,
              border: Border.all(color: c.yellow, width: 2),
              boxShadow: [
                BoxShadow(
                  color: c.yellow.withValues(alpha: 0.10),
                  blurRadius: 0,
                  spreadRadius: 4,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 36,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
                letterSpacing: -1,
                color: c.yellow,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                PlanEyebrow(
                  'THÀNH VIÊN TỪ $memberSince',
                  size: 9,
                  letterSpacing: 1.6,
                  tabular: true,
                ),
                const SizedBox(height: 6),
                PlanH1('$name.', size: 30, letterSpacing: -1.4, height: 0.95),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: c.yellow,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '$level · $phase',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          color: c.inkSoft,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
