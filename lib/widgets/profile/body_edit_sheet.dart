// BodyEditSheet — Premium Ivory bottom sheet for editing height / weight / age.
// Carries the onboarding body-info feel into the main app: a live BMI hero
// dial, a segmented metric switch, and a snap ruler — all in the Ivory
// register. Returns the saved (height, weight, age) via Navigator.pop, or null
// if dismissed.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/vf_theme.dart';
import 'edit_sheet_chrome.dart';
import 'ruler_picker.dart';

typedef BodyStats = ({int height, int weight, int age});

class BodyEditSheet extends StatefulWidget {
  const BodyEditSheet({
    super.key,
    this.currentHeight,
    this.currentWeight,
    this.currentAge,
    required this.onSave,
  });

  final int? currentHeight;
  final int? currentWeight;
  final int? currentAge;

  /// Persists the chosen stats. Returns true on success.
  final Future<bool> Function(BodyStats stats) onSave;

  @override
  State<BodyEditSheet> createState() => _BodyEditSheetState();
}

class _BodyEditSheetState extends State<BodyEditSheet> {
  // Defaults mirror the onboarding body step so the ruler opens somewhere
  // sensible when a value was never set.
  late int _height = widget.currentHeight ?? 165;
  late int _weight = widget.currentWeight ?? 60;
  late int _age = widget.currentAge ?? 28;
  String _activeMetric = 'height';
  bool _saving = false;

  double get _bmi => _weight / math.pow(_height / 100, 2);

  bool get _dirty =>
      _height != widget.currentHeight ||
      _weight != widget.currentWeight ||
      _age != widget.currentAge;

  bool get _ageEligible => _age >= 16;

  void _setActiveValue(int value) {
    setState(() {
      switch (_activeMetric) {
        case 'height':
          _height = value;
        case 'weight':
          _weight = value;
        case 'age':
          _age = value;
      }
    });
  }

  Future<void> _save() async {
    if (_saving || !_dirty || !_ageEligible) return;
    setState(() => _saving = true);
    final ok = await widget.onSave((
      height: _height,
      weight: _weight,
      age: _age,
    ));
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop((height: _height, weight: _weight, age: _age));
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Chưa lưu được số đo, thử lại sau.')),
        );
    }
  }

  ({int value, int min, int max, String unit, String label}) get _active {
    return switch (_activeMetric) {
      'weight' => (value: _weight, min: 35, max: 150, unit: 'kg', label: 'Cân nặng'),
      'age' => (value: _age, min: 13, max: 80, unit: 'tuổi', label: 'Tuổi'),
      _ => (value: _height, min: 140, max: 210, unit: 'cm', label: 'Chiều cao'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final active = _active;
    return ProfileEditSheetCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ProfileSheetHeader(
            icon: Icons.straighten_rounded,
            eyebrow: 'VÓC DÁNG',
            title: 'Số đo cơ thể',
          ),
          const SizedBox(height: 18),
          _BmiHero(height: _height, weight: _weight, age: _age, bmi: _bmi),
          const SizedBox(height: 14),
          _MetricSwitch(
            active: _activeMetric,
            height: _height,
            weight: _weight,
            age: _age,
            onTap: (id) {
              HapticFeedback.selectionClick();
              setState(() => _activeMetric = id);
            },
          ),
          const SizedBox(height: 12),
          IvoryRulerPicker(
            key: ValueKey(active.label),
            label: active.label,
            value: active.value,
            min: active.min,
            max: active.max,
            unit: active.unit,
            onChanged: _setActiveValue,
          ),
          if (!_ageEligible) ...[
            const SizedBox(height: 12),
            _AgeNotice(),
          ],
          const SizedBox(height: 20),
          ProfileSheetSaveButton(
            label: 'Lưu số đo',
            saving: _saving,
            onPressed: (_dirty && _ageEligible) ? _save : null,
          ),
        ],
      ),
    );
  }
}

// ─── BMI zone helper ─────────────────────────────────────────────────────
class _BmiZone {
  const _BmiZone(this.label, this.color);
  final String label;
  final Color color;
}

_BmiZone _zoneFor(double bmi, VikaColors c) {
  if (bmi < 18.5) return _BmiZone('Hơi gầy', c.bmiLow);
  if (bmi < 23) return _BmiZone('Cân đối', c.bmiGood);
  if (bmi < 25) return _BmiZone('Hơi tròn', c.bmiWarn);
  return _BmiZone('Cần chú ý', c.bmiHigh);
}

// ─── Live BMI hero (dark) ────────────────────────────────────────────────
class _BmiHero extends StatelessWidget {
  const _BmiHero({
    required this.height,
    required this.weight,
    required this.age,
    required this.bmi,
  });

  final int height;
  final int weight;
  final int age;
  final double bmi;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final zone = _zoneFor(bmi, c);
    return Container(
      height: 132,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.bgInverse,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: c.ink.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -54,
            top: -54,
            child: IgnorePointer(
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      zone.color.withValues(alpha: 0.20),
                      zone.color.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 10,
            top: 16,
            bottom: 14,
            width: 96,
            child: CustomPaint(
              painter: _BmiDialPainter(
                value: bmi,
                color: zone.color,
                track: c.invInk.withValues(alpha: 0.10),
                spark: c.yellow,
                labelColor: c.invInkFaint,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 116, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: zone.color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: zone.color.withValues(alpha: 0.5),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'HỒ SƠ CƠ THỂ',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: c.invInkSoft,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      bmi.toStringAsFixed(1),
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                        letterSpacing: -1.4,
                        height: 1.0,
                        color: c.invInk,
                        fontFeatures: VikaIvoryMain.tabularFigures,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: _ZonePill(zone: zone),
                    ),
                  ],
                ),
                const SizedBox(height: 11),
                Row(
                  children: [
                    Expanded(child: _MicroStat('$height', 'cm')),
                    Expanded(child: _MicroStat('$weight', 'kg')),
                    Expanded(child: _MicroStat('$age', 'tuổi')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ZonePill extends StatelessWidget {
  const _ZonePill({required this.zone});
  final _BmiZone zone;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: zone.color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: zone.color.withValues(alpha: 0.34)),
      ),
      child: Text(
        zone.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'BeVietnamPro',
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: c.invInk,
        ),
      ),
    );
  }
}

class _MicroStat extends StatelessWidget {
  const _MicroStat(this.value, this.unit);
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 14,
            fontWeight: FontWeight.w800,
            height: 1,
            color: c.invInk,
            fontFeatures: VikaIvoryMain.tabularFigures,
          ),
        ),
        const SizedBox(width: 3),
        Padding(
          padding: const EdgeInsets.only(bottom: 1),
          child: Text(
            unit,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: c.invInkFaint,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Segmented height/weight/age switch ──────────────────────────────────
class _MetricSwitch extends StatelessWidget {
  const _MetricSwitch({
    required this.active,
    required this.height,
    required this.weight,
    required this.age,
    required this.onTap,
  });

  final String active;
  final int height;
  final int weight;
  final int age;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final items = [
      ('height', 'CHIỀU CAO', '$height cm'),
      ('weight', 'CÂN NẶNG', '$weight kg'),
      ('age', 'TUỔI', '$age tuổi'),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.bgRaised,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: c.ink.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: items.map((m) {
          final isActive = active == m.$1;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(m.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
                decoration: BoxDecoration(
                  color: isActive ? c.ink : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      m.$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: isActive ? c.invInkSoft : c.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      m.$3,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                        letterSpacing: -0.3,
                        color: isActive ? c.yellow : c.ink,
                        fontFeatures: VikaIvoryMain.tabularFigures,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AgeNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.attention.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.attention.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: c.attention),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Vika chỉ dành cho người từ 16 tuổi.',
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: c.inkSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── BMI dial ────────────────────────────────────────────────────────────
class _BmiDialPainter extends CustomPainter {
  const _BmiDialPainter({
    required this.value,
    required this.color,
    required this.track,
    required this.spark,
    required this.labelColor,
  });

  final double value;
  final Color color;
  final Color track;
  final Color spark;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 7;
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final active = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi * 0.75,
        endAngle: math.pi * 0.75,
        colors: [spark, color],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);
    const start = math.pi * 0.78;
    const sweep = math.pi * 1.44;
    canvas.drawArc(rect, start, sweep, false, trackPaint);
    final pct = ((value - 17) / 12).clamp(0.0, 1.0);
    canvas.drawArc(rect, start, sweep * pct, false, active);

    final needleAngle = start + sweep * pct;
    final needle = Offset(
      center.dx + math.cos(needleAngle) * radius,
      center.dy + math.sin(needleAngle) * radius,
    );
    canvas.drawCircle(needle, 5, Paint()..color = color);
    canvas.drawCircle(
      needle,
      8,
      Paint()..color = color.withValues(alpha: 0.16),
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'BMI',
        style: TextStyle(
          color: labelColor,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
          fontFamily: 'BeVietnamPro',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - 7),
    );
  }

  @override
  bool shouldRepaint(covariant _BmiDialPainter old) =>
      old.value != value || old.color != color;
}
