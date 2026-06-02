// Difficulty rating block — three thin pill-cards with a tiny dot-meter
// indicator. Selection locks the row and lifts a faint shadow.
//
// FLAG: dead — no remaining references in lib/. Its only former call site
// (the "BÀI CUỐI" inline rating on the workout summary) was removed when the
// last-exercise difficulty moved into the entry popup
// (showPreviousExerciseRatingDialog). Kept intentionally, not deleted.
//
// Design intent: feel "clean and expensive" per user direction. No emoji
// buttons.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';

class DifficultyRatingBlock extends StatelessWidget {
  const DifficultyRatingBlock({
    super.key,
    required this.exerciseName,
    required this.selected,
    required this.onSelect,
    this.eyebrow,
    this.locked = false,
    this.dark = false,
    this.prompt,
  });

  final String exerciseName;
  final String? selected;
  final ValueChanged<String> onSelect;
  final String? eyebrow;
  final bool locked;
  final bool dark;
  final String? prompt;

  static const _options = <_DifficultyOption>[
    _DifficultyOption(id: 'light', label: 'Nhẹ', meter: 1),
    _DifficultyOption(id: 'medium', label: 'Vừa sức', meter: 2),
    _DifficultyOption(id: 'heavy', label: 'Nặng', meter: 3),
  ];

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final eyebrowColor =
        dark ? c.invInkSoft.withValues(alpha: 0.55) : c.inkFaint;
    final titleColor = dark ? c.invInk : c.ink;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: dark ? Colors.white.withValues(alpha: 0.04) : c.bgRaised,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: dark ? Colors.white.withValues(alpha: 0.10) : c.border,
        ),
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: c.ink.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: c.yellow,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: c.yellow, blurRadius: 4)],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                eyebrow ?? 'BÀI VỪA RỒI',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                  color: eyebrowColor,
                ),
              ),
              const Spacer(),
              if (selected != null) _LockedBadge(dark: dark),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            prompt ?? 'Cảm giác của bạn về $exerciseName?',
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              fontStyle: FontStyle.italic,
              letterSpacing: -0.4,
              height: 1.3,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < _options.length; i++) ...[
                Expanded(
                  child: _DifficultyTile(
                    option: _options[i],
                    selected: selected == _options[i].id,
                    locked: locked,
                    dark: dark,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onSelect(_options[i].id);
                    },
                  ),
                ),
                if (i < _options.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DifficultyOption {
  const _DifficultyOption({
    required this.id,
    required this.label,
    required this.meter,
  });
  final String id;
  final String label;
  final int meter;
}

class _DifficultyTile extends StatefulWidget {
  const _DifficultyTile({
    required this.option,
    required this.selected,
    required this.locked,
    required this.dark,
    required this.onTap,
  });
  final _DifficultyOption option;
  final bool selected;
  final bool locked;
  final bool dark;
  final VoidCallback onTap;

  @override
  State<_DifficultyTile> createState() => _DifficultyTileState();
}

class _DifficultyTileState extends State<_DifficultyTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final selected = widget.selected;
    final disabled = widget.locked && !selected;

    final bg = selected
        ? c.yellow
        : widget.dark
            ? Colors.white.withValues(alpha: 0.04)
            : c.bg;
    final border = selected
        ? c.yellow
        : widget.dark
            ? Colors.white.withValues(alpha: 0.12)
            : c.border;
    final labelColor = selected
        ? c.yellowInk
        : widget.dark
            ? c.invInk
            : c.ink;
    final meterDim = widget.dark
        ? c.invInkSoft.withValues(alpha: 0.25)
        : c.inkFaint.withValues(alpha: 0.45);
    final meterOn = selected
        ? c.yellowInk
        : widget.dark
            ? c.invInk
            : c.ink;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: disabled ? null : widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: disabled ? 0.35 : 1.0,
          duration: const Duration(milliseconds: 220),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border, width: 1.2),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: c.yellow.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    for (var i = 1; i <= 3; i++) ...[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i <= widget.option.meter ? meterOn : meterDim,
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (i < 3) const SizedBox(width: 3),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.option.label,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -0.3,
                    color: labelColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LockedBadge extends StatelessWidget {
  const _LockedBadge({required this.dark});
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: dark ? Colors.white.withValues(alpha: 0.06) : c.yellowGhost,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.14)
              : c.yellow.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_rounded,
            size: 11,
            color: dark ? c.invInk : c.ink,
          ),
          const SizedBox(width: 4),
          Text(
            'ĐÃ GHI NHẬN',
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: dark ? c.invInk : c.ink,
            ),
          ),
        ],
      ),
    );
  }
}
