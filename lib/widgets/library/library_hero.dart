// LibraryHero — featured card at the top of the library sheet. Wider
// landscape variant of [LibraryCard] reserved for the "moment" of the
// page (currently the AI form-coach pitch; later could rotate through
// new program launches, featured series, etc.).
//
// Single confident card. Bigger visual, bigger title, optional CTA.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';

class LibraryHero extends StatefulWidget {
  const LibraryHero({
    super.key,
    required this.eyebrow,
    required this.titleLine1,
    required this.titleLine2,
    required this.subtitle,
    required this.ctaLabel,
    required this.onTap,
    this.padding = const EdgeInsets.fromLTRB(20, 4, 20, 0),
  });

  /// e.g. 'CAMERA AI · MỚI'.
  final String eyebrow;
  final String titleLine1;
  final String titleLine2;
  final String subtitle;
  final String ctaLabel;
  final VoidCallback onTap;
  final EdgeInsets padding;

  @override
  State<LibraryHero> createState() => _LibraryHeroState();
}

class _LibraryHeroState extends State<LibraryHero> {
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
          scale: _pressed ? 0.985 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: const Alignment(-0.7, -1),
                  end: const Alignment(0.7, 1),
                  colors: [c.bgInverse, c.bgInverseHi],
                ),
                boxShadow: [
                  BoxShadow(
                    color: c.ink.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Warm ambient glow top-right
                  Positioned(
                    top: -60,
                    right: -50,
                    child: IgnorePointer(
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              c.yellow.withValues(alpha: 0.24),
                              c.yellow.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: c.yellow,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: c.yellow.withValues(alpha: 0.6),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                widget.eyebrow,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'BeVietnamPro',
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.6,
                                  color: c.yellow,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          widget.titleLine1,
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            fontStyle: FontStyle.italic,
                            letterSpacing: -1.8,
                            height: 0.94,
                            color: c.invInk,
                          ),
                        ),
                        Text(
                          widget.titleLine2,
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.8,
                            height: 0.94,
                            color: c.invInk,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          widget.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.45,
                            color: c.invInkSoft,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _HeroCta(label: widget.ctaLabel),
                      ],
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

class _HeroCta extends StatelessWidget {
  const _HeroCta({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
      height: 40,
      decoration: BoxDecoration(
        color: c.yellow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: c.yellowInk,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: c.ink,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 15,
              color: c.yellow,
            ),
          ),
        ],
      ),
    );
  }
}
