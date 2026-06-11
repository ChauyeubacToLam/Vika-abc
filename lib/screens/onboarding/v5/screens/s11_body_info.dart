import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../utils/bmi.dart';
import '../../onboarding_data.dart';
import '../v5_primitives.dart';
import '../v5_theme.dart';

class S11BodyInfo extends StatefulWidget {
  const S11BodyInfo({
    super.key,
    required this.data,
    required this.onNext,
    required this.onBack,
  });

  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  State<S11BodyInfo> createState() => _S11BodyInfoState();
}

class _S11BodyInfoState extends State<S11BodyInfo>
    with SingleTickerProviderStateMixin {
  String _activeMetric = 'height';
  late AnimationController _bmiController;
  late Animation<double> _bmiTween;
  double _animatedBmi = 22.0;
  bool _under16NoticeShown = false;

  int get _height => (widget.data.heightCm ?? 165).round();
  int get _weight => (widget.data.weightKg ?? 60).round();
  int get _age => widget.data.age ?? 28;
  double get _bmi => _weight / math.pow(_height / 100, 2);
  bool get _ageEligible => _age >= 16;
  bool get _canContinue => widget.data.gender != null && _ageEligible;
  String get _disabledLabel {
    if (!_ageEligible) return 'Vika chỉ dành cho 16+';
    if (widget.data.gender == null) return 'Chọn giới tính';
    return 'Chọn để tiếp';
  }

  @override
  void initState() {
    super.initState();
    widget.data.heightCm ??= 165;
    widget.data.weightKg ??= 60;
    widget.data.age ??= 28;
    _animatedBmi = _bmi;
    _bmiController = AnimationController(
      duration: const Duration(milliseconds: 280),
      vsync: this,
    );
    _bmiTween = AlwaysStoppedAnimation(_animatedBmi);
  }

  @override
  void dispose() {
    _bmiController.dispose();
    super.dispose();
  }

  void _setMetricValue(int value) {
    setState(() {
      switch (_activeMetric) {
        case 'height':
          widget.data.heightCm = value.toDouble();
          break;
        case 'weight':
          widget.data.weightKg = value.toDouble();
          break;
        case 'age':
          widget.data.age = value;
          if (value >= 16) {
            _under16NoticeShown = false;
          } else if (!_under16NoticeShown) {
            _under16NoticeShown = true;
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _showUnder16Notice());
          }
          break;
      }
      _animateBmi();
    });
  }

  Future<void> _showUnder16Notice() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierColor: V5.ink.withValues(alpha: 0.42),
      builder: (ctx) => _Under16Dialog(onClose: () => Navigator.pop(ctx)),
    );
  }

  void _animateBmi() {
    final start = _animatedBmi;
    final target = _bmi;
    _bmiTween = Tween<double>(begin: start, end: target).animate(
      CurvedAnimation(parent: _bmiController, curve: V5.curve),
    )..addListener(() {
        if (mounted) setState(() => _animatedBmi = _bmiTween.value);
      });
    _bmiController.forward(from: 0);
  }

  // Label + band come from the shared [bmiCategory] helper so onboarding and
  // Profile can't drift; only the V5 color mapping lives here.
  _BmiZone _zone(double bmi) {
    final band = bmiCategory(bmi);
    final color = switch (band.zone) {
      BmiZone.low => const Color(0xFF7DA3D9),
      BmiZone.good => V5.yellow,
      BmiZone.warn => const Color(0xFFE89A4B),
      BmiZone.high => const Color(0xFFD67B3E),
    };
    return _BmiZone(band.label, color);
  }

  @override
  Widget build(BuildContext context) {
    final zone = _zone(_animatedBmi);
    final metrics = [
      _Metric('height', 'Chiều cao', _height, 'cm', 140, 210),
      _Metric('weight', 'Cân nặng', _weight, 'kg', 35, 150),
      _Metric('age', 'Tuổi', _age, 'tuổi', 13, 80),
    ];
    final active = metrics.firstWhere((m) => m.id == _activeMetric);
    final r = V5Responsive.of(context);
    final compact = r.isShort;
    final veryCompact = r.isVeryShort;
    final showHero = r.size.height >= 820;
    return V5Page(
      index: 13,
      onBack: widget.onBack,
      scroll: true,
      cta: V5PillCTA(
        label: 'Tiếp tục',
        disabledLabel: _disabledLabel,
        enabled: _canContinue,
        onTap: widget.onNext,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              V5ScreenHeader(
                eyebrow: 'Vóc dáng',
                title: 'Vài thông số\nvề cơ thể.',
                size: (r.isNarrow || veryCompact)
                    ? V5HeaderSize.medium
                    : V5HeaderSize.large,
              ),
              SizedBox(height: r.pick(cozy: V5.space12, short: V5.space8)),
              if (showHero) ...[
                V5FadeIn(
                  delay: const Duration(milliseconds: 140),
                  child: SizedBox(
                    height: 132,
                    child: _BodyStatsHero(
                      height: _height,
                      weight: _weight,
                      age: _age,
                      bmi: _animatedBmi,
                      zone: zone,
                    ),
                  ),
                ),
                const SizedBox(height: V5.space6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    bmiCaveat,
                    style: V5.caption(context, color: V5.inkFaint),
                  ),
                ),
                const SizedBox(height: V5.space12),
              ],
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: V5.surface,
                  border: Border.all(color: V5.border),
                  borderRadius: BorderRadius.circular(V5.radiusMd),
                  boxShadow: V5.elevation1,
                ),
                child: Row(
                  children: metrics.map((m) {
                    final isActive = _activeMetric == m.id;
                    return Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _activeMetric = m.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: V5.curveSharp,
                          padding: EdgeInsets.symmetric(
                            vertical: veryCompact ? 7 : 9,
                            horizontal: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isActive ? V5.ink : Colors.transparent,
                            borderRadius: BorderRadius.circular(V5.radiusSm),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                m.label.toUpperCase(),
                                style: V5.eyebrow(
                                  context,
                                  color: isActive ? V5.invInkSoft : V5.inkSoft,
                                ),
                              ),
                              const SizedBox(height: V5.space2),
                              Text(
                                '${m.value} ${m.unit}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: V5
                                    .titleSm(
                                      context,
                                      color: isActive ? V5.yellow : V5.ink,
                                    )
                                    .copyWith(fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              SizedBox(height: r.pick(cozy: V5.space10, short: V5.space8)),
              V5RulerPicker(
                key: ValueKey(active.id),
                label: active.label,
                value: active.value,
                min: active.min,
                max: active.max,
                unit: active.unit,
                compact: compact,
                onChanged: _setMetricValue,
              ),
              SizedBox(height: r.pick(cozy: V5.space14, short: V5.space8)),
              Text(
                'GIỚI TÍNH',
                style: V5.eyebrow(context, color: V5.inkSoft),
              ),
              SizedBox(height: veryCompact ? V5.space6 : V5.space8),
              // One compact row of the three identities, then a single quiet
              // opt-out line — far shorter and calmer than stacked tiles, so
              // the whole screen fits without scrolling.
              Row(
                children: [
                  Expanded(
                    child: _genderChip(
                        'male', 'Nam', Icons.male_rounded, veryCompact),
                  ),
                  const SizedBox(width: V5.space8),
                  Expanded(
                    child: _genderChip(
                        'female', 'Nữ', Icons.female_rounded, veryCompact),
                  ),
                  const SizedBox(width: V5.space8),
                  Expanded(
                    child: _genderChip('other', 'Khác',
                        Icons.transgender_rounded, veryCompact),
                  ),
                ],
              ),
              SizedBox(height: veryCompact ? V5.space6 : V5.space8),
              _genderDeclineLink('prefer_not_to_say', 'Không muốn trả lời'),
            ],
          ),
        ),
      ),
    );
  }

  // One compact identity chip: a horizontal icon + label that fills its
  // column. The three sit in a single even row.
  Widget _genderChip(String id, String label, IconData icon, bool compact) {
    final selected = widget.data.gender == id;
    return V5Card(
      onTap: () => setState(() => widget.data.gender = id),
      selected: selected,
      tint: selected ? V5CardTint.ink : V5CardTint.cream,
      padding: EdgeInsets.symmetric(
          horizontal: 10, vertical: compact ? 11 : 13),
      borderRadius: V5.radiusMd,
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 17, color: selected ? V5.yellow : V5.inkSoft),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: V5.titleSm(context, color: selected ? V5.invInk : V5.ink),
            ),
          ),
        ],
      ),
    );
  }

  // The "prefer not to say" option — a single low-emphasis opt-out line under
  // the three chips, using the shared check indicator. Minimal height, no
  // second card row.
  Widget _genderDeclineLink(String id, String label) {
    final selected = widget.data.gender == id;
    return GestureDetector(
      onTap: () => setState(() => widget.data.gender = id),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            V5CheckCircle(selected: selected, size: 18),
            const SizedBox(width: 10),
            Text(
              label,
              style: V5.bodySm(
                context,
                color: selected ? V5.ink : V5.inkSoft,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Ruler picker — horizontal scroll with snap + yellow marker
// ─────────────────────────────────────────────────────────────

class V5RulerPicker extends StatefulWidget {
  const V5RulerPicker({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
    this.compact = false,
  });

  final int value;
  final String label;
  final int min;
  final int max;
  final String unit;
  final ValueChanged<int> onChanged;
  final bool compact;

  @override
  State<V5RulerPicker> createState() => _V5RulerPickerState();
}

class _V5RulerPickerState extends State<V5RulerPicker> {
  static const tickWidth = 10.0;
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController(
      initialScrollOffset: (widget.value - widget.min) * tickWidth,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _valueForOffset(double offset) {
    return (widget.min + (offset / tickWidth).round())
        .clamp(widget.min, widget.max);
  }

  void _reportCurrentValue() {
    if (!_controller.hasClients) return;
    final value = _valueForOffset(_controller.offset);
    if (value != widget.value) widget.onChanged(value);
  }

  void _snapToNearest() {
    if (!_controller.hasClients) return;
    final value = (widget.min + (_controller.offset / tickWidth).round())
        .clamp(widget.min, widget.max);
    final target = (value - widget.min) * tickWidth;
    if ((_controller.offset - target).abs() < 0.5) return;
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 180),
      curve: V5.curveSharp,
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalTicks = widget.max - widget.min + 1;
    return Container(
      padding: EdgeInsets.fromLTRB(
          0, widget.compact ? 12 : 22, 0, widget.compact ? 10 : 18),
      decoration: BoxDecoration(
        color: V5.surface,
        border: Border.all(color: V5.border),
        borderRadius: BorderRadius.circular(V5.radiusLg),
        boxShadow: V5.elevation1,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: widget.compact ? 48 : 60,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ĐANG CHỈNH ${widget.label.toUpperCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: V5.eyebrow(context, color: V5.inkFaint),
                ),
                SizedBox(height: widget.compact ? V5.space2 : V5.space4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${widget.value}',
                      style: widget.compact
                          ? V5.displaySm(context)
                          : V5.stat(context),
                    ),
                    const SizedBox(width: V5.space6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: V5.space4),
                      child: Text(
                        widget.unit,
                        style: V5.titleSm(context, color: V5.inkSoft),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: widget.compact ? 8 : 14),
          SizedBox(
            height: widget.compact ? 56 : 72,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final sidePadding =
                    math.max(0.0, constraints.maxWidth / 2 - tickWidth / 2);
                return Stack(
                  children: [
                    NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification is ScrollUpdateNotification ||
                            notification is OverscrollNotification) {
                          _reportCurrentValue();
                        } else if (notification is ScrollEndNotification) {
                          _reportCurrentValue();
                          _snapToNearest();
                        }
                        return false;
                      },
                      child: ListView.builder(
                        controller: _controller,
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.symmetric(horizontal: sidePadding),
                        itemCount: totalTicks,
                        itemBuilder: (context, index) {
                          final num = widget.min + index;
                          final major = num % 10 == 0;
                          final mid = num % 5 == 0 && !major;
                          final tickHeight = major
                              ? (widget.compact ? 25.0 : 32.0)
                              : mid
                                  ? (widget.compact ? 18.0 : 22.0)
                                  : (widget.compact ? 11.0 : 14.0);
                          return SizedBox(
                            width: tickWidth,
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.topCenter,
                              children: [
                                Container(
                                  width: major ? 2 : 1,
                                  height: tickHeight,
                                  color: major
                                      ? V5.ink
                                      : mid
                                          ? V5.inkSoft
                                          : V5.inkFaint,
                                ),
                                if (major)
                                  Positioned(
                                    top: tickHeight + 4,
                                    child: Text(
                                      '$num',
                                      textAlign: TextAlign.center,
                                      style: V5
                                          .caption(context, color: V5.inkSoft)
                                          .copyWith(height: 1),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    IgnorePointer(
                      child: Center(
                        child: Column(
                          children: [
                            CustomPaint(
                              size: const Size(12, 8),
                              painter: _TrianglePainter(),
                            ),
                            Container(
                              width: 2,
                              height: widget.compact ? 34 : 42,
                              decoration: BoxDecoration(
                                color: V5.yellow,
                                boxShadow: [
                                  BoxShadow(
                                    color: V5.yellow.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()..color = V5.yellow,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Under16Dialog extends StatelessWidget {
  const _Under16Dialog({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: V5.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(V5.radiusLg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: V5.danger.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: V5.danger.withValues(alpha: 0.32),
                  ),
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  color: V5.danger,
                  size: 24,
                ),
              ),
              const SizedBox(height: V5.space12),
              Text(
                'Vika chỉ dành cho người từ 16 tuổi',
                style: V5.title(context).copyWith(height: 1.2),
              ),
              const SizedBox(height: V5.space6),
              Text(
                'Bạn cần đủ 16 tuổi trở lên để dùng Vika. '
                'Hãy chỉnh lại tuổi để tiếp tục.',
                style:
                    V5.bodySm(context, color: V5.inkSoft).copyWith(height: 1.4),
              ),
              const SizedBox(height: V5.space14),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: onClose,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 12),
                    decoration: BoxDecoration(
                      color: V5.ink,
                      borderRadius: BorderRadius.circular(V5.radiusFull),
                      boxShadow: V5.elevation1,
                    ),
                    child: Text(
                      'Đã hiểu',
                      style: V5.titleSm(context, color: V5.invInk),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric {
  const _Metric(this.id, this.label, this.value, this.unit, this.min, this.max);
  final String id;
  final String label;
  final int value;
  final String unit;
  final int min;
  final int max;
}

class _BmiZone {
  const _BmiZone(this.label, this.color);
  final String label;
  final Color color;
}

class _BodyStatsHero extends StatelessWidget {
  const _BodyStatsHero({
    required this.height,
    required this.weight,
    required this.age,
    required this.bmi,
    required this.zone,
  });

  final int height;
  final int weight;
  final int age;
  final double bmi;
  final _BmiZone zone;

  @override
  Widget build(BuildContext context) {
    return V5HeroCard(
      borderRadius: V5.radiusLg,
      elevation: 2,
      child: Stack(
        children: [
          Positioned(
            right: -54,
            top: -54,
            child: V5AmbientGlow(
              size: const Size(190, 190),
              opacity: 0.2,
              color: zone.color,
            ),
          ),
          Positioned(
            right: 10,
            top: 16,
            bottom: 14,
            width: 96,
            child: CustomPaint(
              painter: _BmiDialPainter(value: bmi, color: zone.color),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 124, 16),
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
                      style: V5.eyebrow(context, color: V5.invInkSoft),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      bmi.toStringAsFixed(1),
                      style: V5.displaySm(context, color: V5.invInk),
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
                    Expanded(child: _BodyMicroStat('$height', 'cm')),
                    Expanded(child: _BodyMicroStat('$weight', 'kg')),
                    Expanded(child: _BodyMicroStat('$age', 'tuổi')),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: zone.color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(V5.radiusFull),
        border: Border.all(color: zone.color.withValues(alpha: 0.34)),
      ),
      child: Text(
        zone.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style:
            V5.eyebrow(context, color: V5.invInk).copyWith(letterSpacing: 0.8),
      ),
    );
  }
}

class _BodyMicroStat extends StatelessWidget {
  const _BodyMicroStat(this.value, this.unit);

  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          value,
          style: V5.titleSm(context, color: V5.invInk).copyWith(height: 1),
        ),
        const SizedBox(width: 3),
        Padding(
          padding: const EdgeInsets.only(bottom: 1),
          child: Text(
            unit,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: V5.caption(context, color: V5.invInkFaint),
          ),
        ),
      ],
    );
  }
}

class _BmiDialPainter extends CustomPainter {
  const _BmiDialPainter({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 7;
    final track = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final active = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi * 0.75,
        endAngle: math.pi * 0.75,
        colors: [V5.yellowSpark, color],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);
    const start = math.pi * 0.78;
    const sweep = math.pi * 1.44;
    canvas.drawArc(rect, start, sweep, false, track);
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
      Paint()
        ..color = color.withValues(alpha: 0.16)
        ..style = PaintingStyle.fill,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'BMI',
        style: TextStyle(
          color: V5.invInkFaint,
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
  bool shouldRepaint(covariant _BmiDialPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.color != color;
}
