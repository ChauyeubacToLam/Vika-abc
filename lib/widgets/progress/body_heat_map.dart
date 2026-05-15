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
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: c.bgRaised,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _BodyFigure(areas: areas, gender: gender),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              children: [
                for (var i = 0; i < areas.length; i++) ...[
                  _HeatRow(area: areas[i]),
                  if (i < areas.length - 1) const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BodyFigure extends StatelessWidget {
  const _BodyFigure({required this.areas, required this.gender});

  final List<BodyHeatArea> areas;
  final BodyGender gender;

  // Body silhouette + heat zones. Per-gender layout matches JSX:
  // figures normalize to 245px tall but male is 78 wide, female is 86.
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
    final w = _figureWidth[gender]!;
    final h = _figureHeight;
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

class _HeatRow extends StatelessWidget {
  const _HeatRow({required this.area});

  final BodyHeatArea area;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final isStrong = area.intensity == 'strong';
    final isMedium = area.intensity == 'medium';
    final dotColor = isStrong
        ? c.yellow
        : isMedium
            ? c.attention
            : c.inkGhost;
    final deltaColor = isStrong
        ? c.yellow
        : isMedium
            ? c.attention
            : c.inkSoft;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      area.area,
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: c.ink,
                      ),
                    ),
                  ),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: area.delta,
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            fontStyle: FontStyle.italic,
                            letterSpacing: -0.3,
                            color: deltaColor,
                            fontFeatures: VikaIvoryMain.tabularFigures,
                          ),
                        ),
                        TextSpan(
                          text: '%',
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: deltaColor.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                area.note,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                  color: c.inkFaint,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
