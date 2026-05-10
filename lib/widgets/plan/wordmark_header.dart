// WordmarkHeader — the top of every main-app screen: thin yellow accent bar
// + italic 32pt "vika" wordmark on the left, trailing icon button + avatar
// on the right.
//
// Accessibility:
//   • Wordmark wraps in `Semantics(header: true, label: 'Vika')` —
//     screen readers announce the section header.
//   • Icon buttons are visually 38pt but use a 44pt hit area
//     (`HitTestBehavior.opaque` + invisible padding) to meet iOS HIG +
//     Android Material guidelines. Each has a tooltip + Semantics label.
//
// Mirrors the wordmark header pattern used on Home/Plan/Progress/Profile
// in vika-main-app-ivory-v1.jsx.

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Visual size of the icon buttons.
const double _iconVisualSize = 38;

/// Total tap target size — meets iOS HIG (44pt) + Material (48dp).
const double _iconHitTargetSize = 48;

class WordmarkHeader extends StatelessWidget {
  const WordmarkHeader({
    super.key,
    this.trailingIcon = Icons.calendar_today_rounded,
    this.trailingTooltip = 'Lịch',
    this.userInitial = 'N',
    this.userTooltip = 'Hồ sơ',
    this.padding = const EdgeInsets.fromLTRB(24, 12, 24, 0),
    this.onTrailingTap,
    this.onAvatarTap,
  });

  final IconData trailingIcon;
  final String trailingTooltip;
  final String userInitial;
  final String userTooltip;
  final EdgeInsets padding;
  final VoidCallback? onTrailingTap;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 5,
            height: 28,
            decoration: BoxDecoration(
              color: c.yellow,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Semantics(
            header: true,
            label: 'Vika',
            child: ExcludeSemantics(
              child: Text(
                'vika',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -2,
                  height: 1,
                  color: c.ink,
                ),
              ),
            ),
          ),
          const Spacer(),
          _IconButton(
            tooltip: trailingTooltip,
            semanticsLabel: trailingTooltip,
            onTap: onTrailingTap,
            child: Container(
              width: _iconVisualSize,
              height: _iconVisualSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: c.border),
              ),
              child: Icon(trailingIcon, size: 16, color: c.ink),
            ),
          ),
          const SizedBox(width: 4),
          _IconButton(
            tooltip: userTooltip,
            semanticsLabel: '$userTooltip $userInitial',
            onTap: onAvatarTap,
            child: Container(
              width: _iconVisualSize,
              height: _iconVisualSize,
              decoration: BoxDecoration(
                color: c.ink,
                shape: BoxShape.circle,
                border: Border.all(color: c.yellow, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                userInitial,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: c.yellow,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Wraps a visual icon child in a 48×48 hit target with tooltip +
/// Semantics. The visual icon stays 38px but the tap zone meets
/// platform guidelines (iOS HIG 44pt, Material 48dp).
class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.child,
    required this.tooltip,
    required this.semanticsLabel,
    this.onTap,
  });

  final Widget child;
  final String tooltip;
  final String semanticsLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Tooltip(
        message: tooltip,
        child: SizedBox(
          width: _iconHitTargetSize,
          height: _iconHitTargetSize,
          child: Material(
            color: Colors.transparent,
            child: InkResponse(
              onTap: onTap,
              radius: _iconHitTargetSize / 2,
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
