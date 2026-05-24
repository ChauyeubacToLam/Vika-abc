// LibraryFilterChips — horizontal scrolling chip row at the top of the
// library sheet for quick refinement (All, Programs, Collections,
// Exercises, Yoga, etc.). Selected chip is ink-filled with cream text;
// unselected are hairline-bordered with ink text. Smooth animated
// transitions on selection.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/vf_theme.dart';

@immutable
class LibraryFilter {
  const LibraryFilter({
    required this.id,
    required this.label,
    this.count,
  });

  final String id;
  final String label;

  /// Optional count shown as a small superscript-style numeral.
  final int? count;
}

class LibraryFilterChips extends StatelessWidget {
  const LibraryFilterChips({
    super.key,
    required this.filters,
    required this.selectedId,
    required this.onSelect,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
    this.inverted = false,
  });

  final List<LibraryFilter> filters;
  final String selectedId;
  final ValueChanged<String> onSelect;
  final EdgeInsets padding;

  /// When true, render chips for placement OVER a warm-dark surface
  /// (e.g., inside a dark stage hero). Selected = yellow filled; default
  /// = subtle dark fill + hairline white border, white text.
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: padding,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final f = filters[i];
          return _FilterChip(
            filter: f,
            selected: f.id == selectedId,
            inverted: inverted,
            onTap: () {
              HapticFeedback.selectionClick();
              onSelect(f.id);
            },
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.filter,
    required this.selected,
    required this.inverted,
    required this.onTap,
  });

  final LibraryFilter filter;
  final bool selected;
  final bool inverted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    // Two color tiers — light-surface (cream pages) vs dark-surface
    // (inverted, for embedding in a dark stage hero).
    final Color bg;
    final Color borderColor;
    final Color labelColor;
    final Color countBg;
    final Color countFg;
    if (inverted) {
      bg = selected ? c.yellow : Colors.white.withValues(alpha: 0.05);
      borderColor =
          selected ? c.yellow : Colors.white.withValues(alpha: 0.18);
      labelColor = selected ? c.yellowInk : c.invInk;
      countBg = selected
          ? c.yellow.withValues(alpha: 0.2)
          : Colors.white.withValues(alpha: 0.10);
      countFg = selected ? c.yellowInk : c.invInkSoft;
    } else {
      bg = selected ? c.ink : Colors.transparent;
      borderColor = selected ? c.ink : c.borderHi;
      labelColor = selected ? c.invInk : c.ink;
      countBg = selected
          ? c.yellow.withValues(alpha: 0.24)
          : c.yellowGhost;
      countFg = selected ? c.yellow : c.ink;
    }
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: selected && inverted
              ? [
                  BoxShadow(
                    color: c.yellow.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              filter.label,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.1,
                color: labelColor,
              ),
            ),
            if (filter.count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: countBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${filter.count}',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: countFg,
                    fontFeatures: VikaIvoryMain.tabularFigures,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
