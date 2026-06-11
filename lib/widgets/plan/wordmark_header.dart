// WordmarkHeader — the top of every main-app screen: the rounded VIKA logo
// mark + italic "VIKA" wordmark on the left, trailing icon button + avatar
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

import '../../services/user_profile_service.dart';
import '../../theme/app_colors.dart';

/// Visual size of the icon buttons.
const double _iconVisualSize = 38;

/// Total tap target size — meets iOS HIG (44pt) + Material (48dp).
const double _iconHitTargetSize = 48;

class WordmarkHeader extends StatefulWidget {
  const WordmarkHeader({
    super.key,
    this.trailingIcon = Icons.calendar_today_rounded,
    this.trailingTooltip = 'Lịch',
    this.userInitial = 'N',
    this.avatarUrl,
    this.userTooltip = 'Hồ sơ',
    this.padding = const EdgeInsets.fromLTRB(24, 12, 24, 0),
    this.onTrailingTap,
    this.onAvatarTap,
    this.inverted = false,
  });

  final IconData trailingIcon;
  final String trailingTooltip;
  final String userInitial;
  final String? avatarUrl;
  final String userTooltip;
  final EdgeInsets padding;
  final VoidCallback? onTrailingTap;
  final VoidCallback? onAvatarTap;

  /// When true, renders for placement over a warm-dark hero surface:
  /// wordmark in invInk, icon outlines in borderDark. Avatar inverts —
  /// cream-filled circle with ink initial (read order: pop forward, not
  /// recede into the dark).
  final bool inverted;

  @override
  State<WordmarkHeader> createState() => _WordmarkHeaderState();
}

class _WordmarkHeaderState extends State<WordmarkHeader> {
  AppUserProfile? _profile;

  @override
  void initState() {
    super.initState();
    if (widget.avatarUrl == null && widget.userInitial == 'N') {
      _loadProfile();
    }
  }

  @override
  void didUpdateWidget(covariant WordmarkHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.avatarUrl == null &&
        widget.userInitial == 'N' &&
        (oldWidget.avatarUrl != widget.avatarUrl ||
            oldWidget.userInitial != widget.userInitial)) {
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    final profile = await UserProfileService().fetchCurrentProfile();
    if (!mounted) return;
    setState(() => _profile = profile);
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final wordmarkColor = widget.inverted ? c.invInk : c.ink;
    final iconBorder = widget.inverted ? c.borderDark : c.border;
    final iconColor = widget.inverted ? c.invInk : c.ink;
    final avatarBg = widget.inverted ? c.bg : c.ink;
    final avatarFg = widget.inverted ? c.ink : c.yellow;
    final avatarBorder = widget.inverted ? c.yellow : c.yellow;
    final userInitial = _profile?.initial ?? widget.userInitial;
    final avatarUrl = widget.avatarUrl ?? _profile?.avatarUrl;

    return Padding(
      padding: widget.padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const _LogoMark(),
          const SizedBox(width: 9),
          Semantics(
            header: true,
            label: 'Vika',
            child: ExcludeSemantics(
              child: Text(
                'VIKA',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  height: 1,
                  color: wordmarkColor,
                ),
              ),
            ),
          ),
          const Spacer(),
          _IconButton(
            tooltip: widget.trailingTooltip,
            semanticsLabel: widget.trailingTooltip,
            onTap: widget.onTrailingTap,
            child: Container(
              width: _iconVisualSize,
              height: _iconVisualSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: iconBorder),
              ),
              child: Icon(widget.trailingIcon, size: 16, color: iconColor),
            ),
          ),
          const SizedBox(width: 4),
          _IconButton(
            tooltip: widget.userTooltip,
            semanticsLabel: '${widget.userTooltip} $userInitial',
            onTap: widget.onAvatarTap,
            child: _HeaderAvatar(
              avatarUrl: avatarUrl,
              initial: userInitial,
              backgroundColor: avatarBg,
              foregroundColor: avatarFg,
              borderColor: avatarBorder,
            ),
          ),
        ],
      ),
    );
  }
}

/// The rounded VIKA logo mark. A subtle shadow lifts the warm tile off the
/// surface so it reads as a placed mark, not a flat sticker — and grounds it
/// the same way on cream and over the dark hero.
class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F1812).withValues(alpha: 0.16),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Image.asset(
        'assets/branding/Logo.jpeg',
        fit: BoxFit.cover,
      ),
    );
  }
}

class _HeaderAvatar extends StatelessWidget {
  const _HeaderAvatar({
    required this.avatarUrl,
    required this.initial,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
  });

  final String? avatarUrl;
  final String initial;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final imageUrl = avatarUrl;
    final hasImage = imageUrl != null;
    return Container(
      width: _iconVisualSize,
      height: _iconVisualSize,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: hasImage ? null : Border.all(color: borderColor, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: imageUrl == null
          ? _InitialText(initial: initial, color: foregroundColor)
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              width: _iconVisualSize,
              height: _iconVisualSize,
              errorBuilder: (_, __, ___) => _InitialText(
                initial: initial,
                color: foregroundColor,
              ),
            ),
    );
  }
}

class _InitialText extends StatelessWidget {
  const _InitialText({required this.initial, required this.color});

  final String initial;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      initial,
      style: TextStyle(
        fontFamily: 'BeVietnamPro',
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: color,
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
