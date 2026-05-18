// PeriodTabs — segmented pill control for week / month / program on the
// Progress screen. Active pill is ink with cream text; inactive pills are
// transparent ink-soft text.
//
// Mirrors `ProgressTimeTabs` in vika-main-app-ivory-v1.jsx.

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
enum PeriodTab { week, month, program }

class PeriodTabs extends StatelessWidget {
  const PeriodTabs({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final PeriodTab value;
  final ValueChanged<PeriodTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.bgRaised,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          for (final t in PeriodTab.values)
            Expanded(child: _Pill(tab: t, active: t == value, onTap: () => onChanged(t))),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.tab, required this.active, required this.onTap});

  final PeriodTab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final label = switch (tab) {
      PeriodTab.week => 'Tuần này',
      PeriodTab.month => 'Tháng',
      PeriodTab.program => 'Cả lộ trình',
    };
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: active ? c.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
              color: active ? c.invInk : c.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
}
