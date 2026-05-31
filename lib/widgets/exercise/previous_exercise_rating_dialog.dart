// Modal popup that gates entry to a continuation exercise's intro page.
// Surfaces immediately on intro mount and cannot be dismissed without
// picking a difficulty rating.
//
// v2 redesign — visual-first, minimal text:
//   • Big italic display question — no eyebrows, no body copy
//   • Tactile 3-tile rating row with icons + meter dots (no labels above)
//   • Visual contrast: the previous exercise's form score sits in a
//     compact poster-style stat block above the tiles, so users see
//     "what they earned" before deciding how it felt
//   • One inline foot-line (italic) nudges them to read the intro — no
//     paragraph-style notice
//
// Returns the selected difficulty id ('light' / 'medium' / 'heavy').

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/vf_theme.dart';

Future<String> showPreviousExerciseRatingDialog(
  BuildContext context, {
  required String exerciseName,
  int? formScore,
}) async {
  final result = await showGeneralDialog<String>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'rating',
    barrierColor: const Color(0xFF15110D).withValues(alpha: 0.82),
    transitionDuration: const Duration(milliseconds: 420),
    pageBuilder: (context, anim1, anim2) {
      return _PreviousExerciseRatingDialog(
        exerciseName: exerciseName,
        formScore: formScore,
      );
    },
    transitionBuilder: (context, anim, secondaryAnim, child) {
      final eased = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutBack,
      );
      return BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 16 * anim.value,
          sigmaY: 16 * anim.value,
        ),
        child: Opacity(
          opacity: anim.value,
          child: Transform.scale(
            scale: 0.88 + (0.12 * eased.value.clamp(0.0, 1.0)),
            child: child,
          ),
        ),
      );
    },
  );
  return result ?? 'medium';
}

class _PreviousExerciseRatingDialog extends StatefulWidget {
  const _PreviousExerciseRatingDialog({
    required this.exerciseName,
    required this.formScore,
  });

  final String exerciseName;
  final int? formScore;

  @override
  State<_PreviousExerciseRatingDialog> createState() =>
      _PreviousExerciseRatingDialogState();
}

class _PreviousExerciseRatingDialogState
    extends State<_PreviousExerciseRatingDialog>
    with SingleTickerProviderStateMixin {
  String? _selected;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _pick(String id) {
    if (_selected != null) return;
    setState(() => _selected = id);
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 320), () {
      if (mounted) Navigator.of(context).pop(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    // Clamp accessibility text scaling so the 40pt italic question
    // can't push the tile row off-screen on small phones.
    final mq = MediaQuery.of(context);
    final clampedScaler = mq.textScaler.clamp(
      minScaleFactor: 0.9,
      maxScaleFactor: 1.1,
    );
    // Tighter dialog max-width on phones, wider on tablets.
    final dialogMaxWidth = mq.size.shortestSide >= 600 ? 520.0 : 420.0;
    return MediaQuery(
      data: mq.copyWith(textScaler: clampedScaler),
      child: PopScope(
        canPop: false,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: dialogMaxWidth),
                child: Material(
                  color: Colors.transparent,
                  child: AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, _) {
                      return Container(
                        decoration: BoxDecoration(
                          color: c.bgRaised,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: c.border),
                          boxShadow: [
                            BoxShadow(
                              color: c.ink.withValues(alpha: 0.45),
                              blurRadius: 64,
                              offset: const Offset(0, 26),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: Stack(
                            children: [
                              // Atmospheric stack — top-right yellow glow,
                              // bottom-left amber bloom. Matches the
                              // transition-moment world so it reads as the
                              // same surface.
                              Positioned(
                                top: -90,
                                right: -70,
                                child: IgnorePointer(
                                  child: Opacity(
                                    opacity: 0.6 + (_pulse.value * 0.3),
                                    child: SizedBox(
                                      width: 240,
                                      height: 240,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: RadialGradient(
                                            colors: [
                                              c.yellow.withValues(alpha: 0.28),
                                              c.yellow.withValues(alpha: 0),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: -110,
                                left: -80,
                                child: IgnorePointer(
                                  child: SizedBox(
                                    width: 240,
                                    height: 220,
                                    child: const DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: RadialGradient(
                                          colors: [
                                            Color(0x33CD7C45),
                                            Color(0x00CD7C45),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(24, 26, 24, 22),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _FormScoreBadge(
                                      formScore: widget.formScore,
                                      exerciseName: widget.exerciseName,
                                      pulse: _pulse.value,
                                    ),
                                    const SizedBox(height: 22),
                                    // The question — italic, big, no
                                    // surrounding chrome.
                                    Text(
                                      'Cảm giác',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: 'BeVietnamPro',
                                        fontSize: 40,
                                        fontWeight: FontWeight.w800,
                                        fontStyle: FontStyle.italic,
                                        height: 1.0,
                                        letterSpacing: -2.2,
                                        color: c.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'thế nào?',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: 'BeVietnamPro',
                                        fontSize: 40,
                                        fontWeight: FontWeight.w800,
                                        fontStyle: FontStyle.italic,
                                        height: 1.0,
                                        letterSpacing: -2.2,
                                        color: c.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 26),
                                    // 3 visual tiles — IntrinsicHeight gives
                                    // the Row a bounded height so `stretch`
                                    // can equalize the tiles without forcing
                                    // an infinite vertical constraint.
                                    IntrinsicHeight(
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          for (var i = 0;
                                              i < _options.length;
                                              i++) ...[
                                            Expanded(
                                              child: _Tile(
                                                option: _options[i],
                                                selected:
                                                    _selected == _options[i].id,
                                                locked: _selected != null,
                                                onTap: () =>
                                                    _pick(_options[i].id),
                                              ),
                                            ),
                                            if (i < _options.length - 1)
                                              const SizedBox(width: 10),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    // Footline — one short italic nudge
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.menu_book_rounded,
                                          size: 12,
                                          color: c.inkFaint,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _selected == null
                                              ? 'Đọc giới thiệu phía dưới sau khi chọn'
                                              : 'Đã ghi nhận',
                                          style: TextStyle(
                                            fontFamily: 'BeVietnamPro',
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            fontStyle: FontStyle.italic,
                                            letterSpacing: -0.1,
                                            color: c.inkFaint,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Form score badge — poster-style stat block at the top of the
// dialog. Shows the exercise name + the form score they just earned. ───
class _FormScoreBadge extends StatelessWidget {
  const _FormScoreBadge({
    required this.formScore,
    required this.exerciseName,
    required this.pulse,
  });

  final int? formScore;
  final String exerciseName;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final score = formScore ?? 0;
    final scoreColor = score >= 78
        ? c.yellow
        : score >= 60
            ? c.ink
            : c.attention;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          // Left: form score in a poster-style numeral
          if (formScore != null) ...[
            Stack(
              alignment: Alignment.center,
              children: [
                // Soft halo behind the score
                IgnorePointer(
                  child: Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scoreColor.withValues(alpha: 0.12 + pulse * 0.08),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$score',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                        height: 1.0,
                        letterSpacing: -1.4,
                        color: scoreColor,
                        fontFeatures: VikaIvoryMain.tabularFigures,
                      ),
                    ),
                    Text(
                      '/100',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: c.inkFaint,
                        fontFeatures: VikaIvoryMain.tabularFigures,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: c.yellow,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: c.yellow, blurRadius: 4),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'BÀI VỪA RỒI',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                        color: c.inkFaint,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  exerciseName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -0.6,
                    color: c.ink,
                  ),
                ),
              ],
            ),
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
    required this.icon,
  });
  final String id;
  final String label;
  final int meter;
  final IconData icon;
}

const _options = <_DifficultyOption>[
  _DifficultyOption(
    id: 'light',
    label: 'Nhẹ',
    meter: 1,
    icon: Icons.air_rounded,
  ),
  _DifficultyOption(
    id: 'medium',
    label: 'Vừa',
    meter: 2,
    icon: Icons.local_fire_department_rounded,
  ),
  _DifficultyOption(
    id: 'heavy',
    label: 'Nặng',
    meter: 3,
    icon: Icons.bolt_rounded,
  ),
];

class _Tile extends StatefulWidget {
  const _Tile({
    required this.option,
    required this.selected,
    required this.locked,
    required this.onTap,
  });
  final _DifficultyOption option;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  State<_Tile> createState() => _TileState();
}

class _TileState extends State<_Tile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final selected = widget.selected;
    final disabled = widget.locked && !selected;

    // Material+InkWell for guaranteed hit testing on every tile.
    return AnimatedScale(
      scale: _pressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 120),
      child: AnimatedOpacity(
        opacity: disabled ? 0.32 : 1.0,
        duration: const Duration(milliseconds: 240),
        child: Material(
          color: selected ? c.yellow : c.bg,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: disabled ? null : widget.onTap,
            onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
            onTapUp: disabled ? null : (_) => setState(() => _pressed = false),
            onTapCancel:
                disabled ? null : () => setState(() => _pressed = false),
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected ? c.yellow : c.border,
                  width: 1.4,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: c.yellow.withValues(alpha: 0.45),
                          blurRadius: 22,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              padding: const EdgeInsets.fromLTRB(10, 16, 10, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon medallion
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? c.yellowInk.withValues(alpha: 0.12)
                          : c.bgRaised,
                      border: Border.all(
                        color: selected
                            ? c.yellowInk.withValues(alpha: 0.25)
                            : c.border,
                        width: 1.2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      widget.option.icon,
                      size: 22,
                      color: selected ? c.yellowInk : c.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Meter dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 1; i <= 3; i++) ...[
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: i <= widget.option.meter
                                ? (selected ? c.yellowInk : c.ink)
                                : (selected
                                    ? c.yellowInk.withValues(alpha: 0.25)
                                    : c.inkFaint.withValues(alpha: 0.4)),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      letterSpacing: -0.4,
                      color: selected ? c.yellowInk : c.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
