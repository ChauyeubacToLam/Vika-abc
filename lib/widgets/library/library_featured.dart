// LibraryFeatured — large editorial featured card placed just under the
// dark stage hero. Magazine-cover treatment: oversized italic display
// headline, decorative watermark numeral in the background, yellow rule
// accent, stat row, description, and a halo CTA.
//
// One single confident MOMENT below the stage hero. Reads as "the
// editor's pick this week" — anchors the cream body before the rails
// start scrolling.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/vf_theme.dart';

class LibraryFeatured extends StatefulWidget {
  const LibraryFeatured({
    super.key,
    required this.eyebrow,
    required this.indexLabel,
    required this.titleLine1,
    required this.titleLine2,
    required this.statChips,
    required this.description,
    required this.ctaLabel,
    required this.onTap,
    this.watermarkNumeral,
    this.padding = const EdgeInsets.fromLTRB(20, 22, 20, 0),
  });

  /// e.g. 'TUẦN NÀY · LỘ TRÌNH GỢI Ý'.
  final String eyebrow;

  /// e.g. '01 / 04' — magazine-style top-right index.
  final String indexLabel;

  /// Two-line italic display headline (line 1 italic, line 2 upright).
  final String titleLine1;
  final String titleLine2;

  /// Compact meta chips (e.g. ['21 ngày', '14 buổi', 'Cơ bản']).
  final List<String> statChips;

  final String description;
  final String ctaLabel;
  final VoidCallback onTap;

  /// Optional huge italic numeral painted as a soft watermark in the
  /// background. e.g. '01'. Decorative — used to give the card editorial
  /// "chapter" feel.
  final String? watermarkNumeral;

  final EdgeInsets padding;

  @override
  State<LibraryFeatured> createState() => _LibraryFeaturedState();
}

class _LibraryFeaturedState extends State<LibraryFeatured> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: widget.padding,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _pressed ? 0.99 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [c.bgRaised, c.powder],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: c.borderHi, width: 1.4),
              boxShadow: [
                BoxShadow(
                  color: c.ink.withValues(alpha: 0.04),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
                BoxShadow(
                  color: c.ink.withValues(alpha: 0.10),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: c.ink.withValues(alpha: 0.08),
                  blurRadius: 56,
                  offset: const Offset(0, 28),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Watermark numeral — decorative, soft, magazine
                // "chapter number" treatment.
                if (widget.watermarkNumeral != null)
                  Positioned(
                    right: -18,
                    bottom: -42,
                    child: IgnorePointer(
                      child: Text(
                        widget.watermarkNumeral!,
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 220,
                          fontWeight: FontWeight.w800,
                          fontStyle: FontStyle.italic,
                          letterSpacing: -12,
                          height: 1,
                          color: c.ink.withValues(alpha: 0.04),
                          fontFeatures: VikaIvoryMain.tabularFigures,
                        ),
                      ),
                    ),
                  ),
                // Soft warm halo top-right
                Positioned(
                  top: -60,
                  right: -50,
                  child: IgnorePointer(
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            c.yellow.withValues(alpha: 0.10),
                            c.yellow.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: c.yellow,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              widget.eyebrow,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'BeVietnamPro',
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.6,
                                color: c.inkSoft,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            widget.indexLabel,
                            style: TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                              color: c.inkFaint,
                              fontFeatures: VikaIvoryMain.tabularFigures,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        widget.titleLine1,
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          fontStyle: FontStyle.italic,
                          letterSpacing: -2.6,
                          height: 1.02,
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.titleLine2,
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -2.6,
                          height: 1.02,
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: 32,
                        height: 2,
                        decoration: BoxDecoration(
                          color: c.yellow,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        children: [
                          for (var i = 0; i < widget.statChips.length; i++) ...[
                            Text(
                              widget.statChips[i],
                              style: TextStyle(
                                fontFamily: 'BeVietnamPro',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.1,
                                color: c.inkSoft,
                                fontFeatures: VikaIvoryMain.tabularFigures,
                              ),
                            ),
                            if (i < widget.statChips.length - 1)
                              Container(
                                width: 3,
                                height: 3,
                                margin: const EdgeInsets.only(top: 7),
                                decoration: BoxDecoration(
                                  color: c.inkFaint,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.45,
                          color: c.inkSoft,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _FeaturedCta(label: widget.ctaLabel),
                    ],
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

class _FeaturedCta extends StatelessWidget {
  const _FeaturedCta({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 0, 6, 0),
      height: 50,
      decoration: BoxDecoration(
        color: c.yellow,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: c.yellow.withValues(alpha: 0.36),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.25,
              color: c.yellowInk,
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.ink,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 16,
              color: c.yellow,
            ),
          ),
        ],
      ),
    );
  }
}
