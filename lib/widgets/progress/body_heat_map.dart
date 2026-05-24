// BodyHeatMap — body silhouette PNG + colored heat overlays + delta column.
//
// Mirrors `BodyHeatMap` and `BodyFigureMap` in vika-main-app-ivory-v1.jsx.
//
// Heat zones are rendered as positioned radial gradients on top of the body
// silhouette. The JSX uses CSS mask-image to clip each gradient to the body
// alpha; in Flutter we approximate with positioned ellipses that stay within
// the silhouette bounds at the JSX-specified zone coordinates. Visually
// reads the same — the body lights up around the indicated regions.
//
// Asset PNGs: assets/images/body_male.png and body_female.png. Both must be
// declared in pubspec.yaml under flutter > assets.

import 'package:flutter/material.dart';

import '../../data/progress_mock.dart';
import '../../theme/vf_theme.dart';
import '../../theme/app_colors.dart';
enum BodyGender { male, female }

class BodyHeatMap extends StatelessWidget {
  const BodyHeatMap({
    super.key,
    required this.areas,
    this.gender = BodyGender.male,
  });

  final List<BodyHeatArea> areas;
  final BodyGender gender;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      decoration: BoxDecoration(
        color: c.bgRaised,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: c.ink.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Body silhouette gets full breathing room — centered, tall.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: _BodyFigure(
                areas: areas,
                gender: gender,
                width: 124,
                height: 324,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Intensity legend — small editorial key under the figure.
          _IntensityLegend(),
          const SizedBox(height: 14),
          Container(height: 1, color: c.border),
          const SizedBox(height: 16),
          // 2×2 grid of area cards.
          LayoutBuilder(
            builder: (context, bc) {
              const gap = 10.0;
              final tileWidth = (bc.maxWidth - gap) / 2;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final a in areas)
                    SizedBox(
                      width: tileWidth,
                      child: _AreaTile(area: a),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Small three-dot key showing the meaning of intensity colors. Sits
/// directly under the silhouette so users learn the visual language.
class _IntensityLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    Widget item(Color dot, String label, {bool glow = false}) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: dot,
              shape: BoxShape.circle,
              boxShadow:
                  glow ? [BoxShadow(color: dot, blurRadius: 5)] : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: c.inkFaint,
            ),
          ),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        item(c.yellow, 'MẠNH', glow: true),
        const SizedBox(width: 18),
        item(c.attention, 'VỪA'),
        const SizedBox(width: 18),
        item(c.inkGhost, 'NHẸ'),
      ],
    );
  }
}

class _AreaTile extends StatelessWidget {
  const _AreaTile({required this.area});
  final BodyHeatArea area;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final isStrong = area.intensity == 'strong';
    final isMedium = area.intensity == 'medium';
    final accent = isStrong
        ? c.yellow
        : isMedium
            ? c.attention
            : c.inkGhost;
    final deltaColor = isStrong
        ? c.yellow
        : isMedium
            ? c.attention
            : c.inkSoft;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  boxShadow: isStrong
                      ? [
                          BoxShadow(color: accent, blurRadius: 6),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  area.area,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: c.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                area.delta,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -1.2,
                  height: 0.95,
                  color: deltaColor,
                  fontFeatures: VikaIvoryMain.tabularFigures,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                '%',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: deltaColor.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(width: 14, height: 1, color: accent),
          const SizedBox(height: 8),
          Text(
            area.note,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              height: 1.4,
              letterSpacing: 0.05,
              color: c.inkFaint,
            ),
          ),
        ],
      ),
    );
  }
}

class _BodyFigure extends StatelessWidget {
  const _BodyFigure({
    required this.areas,
    required this.gender,
    this.width,
    this.height,
  });

  final List<BodyHeatArea> areas;
  final BodyGender gender;

  /// Optional explicit sizing. If omitted, falls back to per-gender
  /// defaults matching the JSX (male 78×245, female 86×245).
  final double? width;
  final double? height;

  // Per-gender default layout: figures normalize to 245px tall but
  // male is 78 wide, female is 86.
  static const _figureWidth = {BodyGender.male: 78.0, BodyGender.female: 86.0};
  static const _figureHeight = 245.0;

  static const _zonesByRegion = {
    'shoulders': _Zone(cyPct: 26, rxPct: 76, ryPct: 11),
    'core':      _Zone(cyPct: 43, rxPct: 58, ryPct: 13),
    'glutes':    _Zone(cyPct: 56, rxPct: 76, ryPct: 9),
    'legs':      _Zone(cyPct: 76, rxPct: 78, ryPct: 18),
  };

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final w = width ?? _figureWidth[gender]!;
    final h = height ?? _figureHeight;
    final assetPath = gender == BodyGender.male
        ? 'assets/images/body_male.png'
        : 'assets/images/body_female.png';

    final intensityByRegion = {
      for (final a in areas) a.region: a.intensity,
    };

    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        children: [
          // Body silhouette PNG.
          Positioned.fill(
            child: Image.asset(
              assetPath,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // Fallback if PNG missing — render a faint placeholder block
                // so the layout doesn't collapse.
                return Container(
                  decoration: BoxDecoration(
                    color: c.borderHi,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'body.png\nmissing',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 10,
                      color: c.inkFaint,
                    ),
                  ),
                );
              },
            ),
          ),
          // Heat zone overlays — one per known region with a registered
          // intensity. Drawn additively over the silhouette so the body
          // tone shows through.
          for (final entry in _zonesByRegion.entries)
            if (intensityByRegion[entry.key] != null)
              _HeatZone(
                width: w,
                height: h,
                zone: entry.value,
                intensity: intensityByRegion[entry.key]!,
              ),
        ],
      ),
    );
  }
}

class _Zone {
  const _Zone({required this.cyPct, required this.rxPct, required this.ryPct});
  final double cyPct;
  final double rxPct;
  final double ryPct;
}

class _HeatZone extends StatelessWidget {
  const _HeatZone({
    required this.width,
    required this.height,
    required this.zone,
    required this.intensity,
  });

  final double width;
  final double height;
  final _Zone zone;
  final String intensity;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    // Color + peak-alpha by intensity.
    final (color, peak) = switch (intensity) {
      'strong' => (c.yellow, 0.78),
      'medium' => (c.attention, 0.58),
      'mild' => (c.borderHi, 0.34),
      _ => (c.yellow, 0.34),
    };

    final cyPx = (zone.cyPct / 100) * height;
    final rxPx = (zone.rxPct / 100) * width / 2;
    final ryPx = (zone.ryPct / 100) * height;

    return Positioned(
      left: width / 2 - rxPx,
      top: cyPx - ryPx,
      width: rxPx * 2,
      height: ryPx * 2,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 0.5,
              colors: [
                color.withValues(alpha: peak),
                color.withValues(alpha: peak * 0.32),
                color.withValues(alpha: 0),
              ],
              stops: const [0, 0.55, 1],
            ),
          ),
        ),
      ),
    );
  }
}

