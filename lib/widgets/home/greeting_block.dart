// GreetingBlock — small two-line greeting under the wordmark header on Home.
// First line: "Xin chào, Nam." Second line: weekday · date · session number.
//
// Mirrors the inline greeting block at the top of the Home tab in
// vika-main-app-ivory-v1.jsx.

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class GreetingBlock extends StatelessWidget {
  const GreetingBlock({
    super.key,
    required this.userName,
    required this.dayLabel,
    required this.sessionLabel,
    this.padding = const EdgeInsets.fromLTRB(24, 18, 24, 0),
  });

  final String userName;
  final String dayLabel; // 'Thứ Sáu · 8 tháng 5'
  final String sessionLabel; // 'Buổi 03'

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Xin chào, $userName.',
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: c.inkSoft,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$dayLabel · $sessionLabel',
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: c.inkFaint,
            ),
          ),
        ],
      ),
    );
  }
}
