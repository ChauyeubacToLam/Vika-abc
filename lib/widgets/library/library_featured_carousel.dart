// LibraryFeaturedCarousel — swipeable editorial cover carousel that
// replaces the single featured card. Curators can rotate 3–5 "editor's
// pick" payloads through the same magazine-cover treatment, and the
// active slide's chapter index ("01 / 04") tracks the page itself.
//
// Each slide reuses [LibraryFeatured] verbatim so the editorial language
// (italic display, watermark numeral, halo CTA) is preserved. The
// carousel owns the PageView mechanics, the subtle out-of-focus scale
// fade, and the pagination dots below.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import 'library_featured.dart';

/// One slide in the [LibraryFeaturedCarousel]. Mirrors the props of
/// [LibraryFeatured] minus the [indexLabel] (carousel derives it from
/// the slide's position).
@immutable
class LibraryFeaturedSlide {
  const LibraryFeaturedSlide({
    required this.eyebrow,
    required this.titleLine1,
    required this.titleLine2,
    required this.statChips,
    required this.description,
    required this.ctaLabel,
    required this.onTap,
    this.watermarkNumeral,
  });

  final String eyebrow;
  final String titleLine1;
  final String titleLine2;
  final List<String> statChips;
  final String description;
  final String ctaLabel;
  final VoidCallback onTap;
  final String? watermarkNumeral;
}

class LibraryFeaturedCarousel extends StatefulWidget {
  const LibraryFeaturedCarousel({
    super.key,
    required this.slides,
    this.height = 348,
  });

  final List<LibraryFeaturedSlide> slides;

  /// Fixed height of the carousel viewport. The featured card sits
  /// inside, vertically centered. Tune if content grows taller.
  final double height;

  @override
  State<LibraryFeaturedCarousel> createState() =>
      _LibraryFeaturedCarouselState();
}

class _LibraryFeaturedCarouselState extends State<LibraryFeaturedCarousel> {
  late final PageController _controller;
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.92);
    _controller.addListener(_onScroll);
  }

  void _onScroll() {
    final p = _controller.page ?? 0;
    final i = p.round();
    if (i != _activeIndex) {
      setState(() => _activeIndex = i);
      HapticFeedback.selectionClick();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.slides.length;
    return Padding(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: widget.height,
            child: PageView.builder(
              controller: _controller,
              itemCount: total,
              physics: const BouncingScrollPhysics(),
              padEnds: true,
              clipBehavior: Clip.none,
              itemBuilder: (context, i) {
                final s = widget.slides[i];
                final indexLabel = '${(i + 1).toString().padLeft(2, '0')}'
                    ' / '
                    '${total.toString().padLeft(2, '0')}';
                return AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    double t = 1.0;
                    double op = 1.0;
                    if (_controller.hasClients &&
                        _controller.position.haveDimensions) {
                      final page = _controller.page ?? 0.0;
                      final d = (page - i).abs();
                      t = (1.0 - d * 0.06).clamp(0.92, 1.0);
                      op = (1.0 - d * 0.45).clamp(0.45, 1.0);
                    }
                    return Opacity(
                      opacity: op,
                      child: Transform.scale(scale: t, child: child),
                    );
                  },
                  child: Center(
                    child: LibraryFeatured(
                      eyebrow: s.eyebrow,
                      indexLabel: indexLabel,
                      titleLine1: s.titleLine1,
                      titleLine2: s.titleLine2,
                      statChips: s.statChips,
                      description: s.description,
                      ctaLabel: s.ctaLabel,
                      watermarkNumeral: s.watermarkNumeral,
                      onTap: s.onTap,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          _PaginationDots(active: _activeIndex, total: total),
        ],
      ),
    );
  }
}

class _PaginationDots extends StatelessWidget {
  const _PaginationDots({required this.active, required this.total});
  final int active;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < total; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == active ? 22 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == active ? c.yellow : c.inkFaint.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(3),
              boxShadow: i == active
                  ? [
                      BoxShadow(
                        color: c.yellow.withValues(alpha: 0.4),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
          ),
      ],
    );
  }
}
