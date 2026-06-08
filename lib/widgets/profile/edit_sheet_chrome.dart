// Shared Premium Ivory chrome for the Profile edit bottom sheets (goal, body).
// Keeps the gradient card, drag handle, and medallion header identical across
// editors so they read as one family.

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Wraps [child] in the gradient sheet card + drag handle used by every
/// Profile editor sheet. [child] should be the scrollable content column.
class ProfileEditSheetCard extends StatelessWidget {
  const ProfileEditSheetCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final accent = c.yellow;
    final sheetTint = Color.lerp(c.bgRaised, accent, c.isDark ? 0.10 : 0.06)!;
    final outline = Color.lerp(c.border, accent, c.isDark ? 0.30 : 0.40)!;
    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.viewPaddingOf(context).bottom +
            12,
      ),
      child: Material(
        color: Colors.transparent,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [c.bgRaised, sheetTint],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: outline),
            boxShadow: [
              BoxShadow(
                color: c.ink.withValues(alpha: c.isDark ? 0.30 : 0.12),
                blurRadius: 42,
                offset: const Offset(0, 22),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.borderHi,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Medallion + eyebrow + italic display title + close button.
class ProfileSheetHeader extends StatelessWidget {
  const ProfileSheetHeader({
    super.key,
    required this.icon,
    required this.eyebrow,
    required this.title,
  });

  final IconData icon;
  final String eyebrow;
  final String title;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: c.yellow.withValues(alpha: c.isDark ? 0.18 : 0.14),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: c.yellow.withValues(alpha: 0.40)),
          ),
          child: Icon(
            icon,
            size: 18,
            color: Color.lerp(c.yellow, c.ink, c.isDark ? 0.06 : 0.30),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: c.inkSoft,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -0.7,
                  height: 1.05,
                  color: c.ink,
                ),
              ),
            ],
          ),
        ),
        IconButton.filled(
          style: IconButton.styleFrom(
            backgroundColor: c.bg.withValues(alpha: 0.72),
            foregroundColor: c.ink,
          ),
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }
}

/// The yellow primary save button shared by the editor sheets.
class ProfileSheetSaveButton extends StatelessWidget {
  const ProfileSheetSaveButton({
    super.key,
    required this.label,
    required this.saving,
    required this.onPressed,
  });

  final String label;
  final bool saving;

  /// Null disables the button (e.g. nothing changed yet).
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return SizedBox(
      height: 50,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: c.yellow,
          disabledBackgroundColor: c.yellowGhost,
          foregroundColor: c.yellowInk,
          disabledForegroundColor: c.inkSoft,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        onPressed: saving ? null : onPressed,
        icon: saving
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: c.yellowInk,
                ),
              )
            : const Icon(Icons.check_rounded),
        label: Text(label),
      ),
    );
  }
}
