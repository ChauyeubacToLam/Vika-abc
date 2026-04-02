import 'package:flutter/material.dart';

import '../onboarding_data.dart';
import '../onboarding_primitives.dart';
import '../vf_theme.dart';

class BodySchedulePage extends StatefulWidget {
  const BodySchedulePage({
    super.key,
    required this.data,
    required this.onNext,
    required this.onBack,
  });

  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  State<BodySchedulePage> createState() => _BodySchedulePageState();
}

class _BodySchedulePageState extends State<BodySchedulePage> {
  static const _dayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  static const _timeOptions = [
    (
      id: 'morning',
      title: 'Sáng',
      subtitle: '6-9h',
      hint: 'Khởi động ngày mới',
      icon: Icons.wb_sunny_outlined,
      color: Color(0xFFF3B54A),
    ),
    (
      id: 'noon',
      title: 'Trưa',
      subtitle: '11-13h',
      hint: 'Tập nhanh giữa ngày',
      icon: Icons.light_mode_outlined,
      color: Color(0xFFF08A4B),
    ),
    (
      id: 'evening',
      title: 'Chiều',
      subtitle: '17-20h',
      hint: 'Sau giờ học hoặc làm',
      icon: Icons.wb_twilight_outlined,
      color: Color(0xFF4F8EF7),
    ),
    (
      id: 'night',
      title: 'Tối',
      subtitle: '20-22h',
      hint: 'Nhịp tập nhẹ và đều',
      icon: Icons.nights_stay_outlined,
      color: Color(0xFF5E7BAA),
    ),
  ];

  late int _height;
  late int _weight;
  late List<int> _days;
  late String _preferredTime;

  @override
  void initState() {
    super.initState();
    _height = (widget.data.heightCm ?? 165).round().clamp(140, 200);
    _weight = (widget.data.weightKg ?? 60).round().clamp(35, 120);
    _days = widget.data.workoutDays.isEmpty
        ? [0, 2, 4]
        : List<int>.from(widget.data.workoutDays)
      ..sort();
    _preferredTime = widget.data.preferredTime ?? 'evening';
    _syncData();
  }

  void _syncData() {
    widget.data.heightCm = _height.toDouble();
    widget.data.weightKg = _weight.toDouble();
    widget.data.workoutDays = List<int>.from(_days);
    widget.data.preferredTime = _preferredTime;
  }

  void _toggleDay(int day) {
    setState(() {
      if (_days.contains(day)) {
        _days.remove(day);
      } else {
        _days.add(day);
        _days.sort();
      }
      _syncData();
    });
  }

  double get _bmi => _weight / ((_height / 100) * (_height / 100));

  _BmiInfo get _bmiInfo {
    final bmi = _bmi;
    if (bmi < 18.5) {
      return const _BmiInfo('Thiếu cân', Color(0xFF5B9BD5));
    }
    if (bmi < 23) {
      return const _BmiInfo('Bình thường', VF.accent);
    }
    if (bmi < 25) {
      return const _BmiInfo('Thừa cân', VF.amber);
    }
    return const _BmiInfo('Béo phì', VF.coral);
  }

  double get _bmiPosition => ((_bmi - 15) / 20).clamp(0.0, 1.0).toDouble();

  bool get _canContinue => _days.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final s = VF.scale(context);
    final bmiInfo = _bmiInfo;

    return ColoredBox(
      color: VF.bg,
      child: Column(
        children: [
          VFOnboardingNavBar(
            current: 9,
            total: 10,
            onBack: widget.onBack,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20 * s, 20 * s, 20 * s, 16 * s),
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8 * s),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Thông tin cơ thể & lịch tập',
                          style: VF.textStyle(
                            context,
                            size: 28,
                            weight: FontWeight.w900,
                            color: VF.text,
                            letterSpacing: -1.5,
                            height: 1.1,
                          ),
                        ),
                        SizedBox(height: 8 * s),
                        Text(
                          'Kéo để chọn chiều cao, cân nặng và khung giờ bạn dễ duy trì nhất.',
                          style: VF.textStyle(
                            context,
                            size: 13,
                            weight: FontWeight.w500,
                            color: VF.textMuted,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20 * s),
                  _MeasurementCard(
                    label: 'CHIỀU CAO',
                    value: _height,
                    unit: 'cm',
                    picker: VFScrollableRulerPicker(
                      value: _height,
                      min: 140,
                      max: 200,
                      unit: 'cm',
                      onChanged: (value) => setState(() {
                        _height = value;
                        _syncData();
                      }),
                    ),
                  ),
                  SizedBox(height: 12 * s),
                  _MeasurementCard(
                    label: 'CÂN NẶNG',
                    value: _weight,
                    unit: 'kg',
                    picker: VFScrollableRulerPicker(
                      value: _weight,
                      min: 35,
                      max: 120,
                      unit: 'kg',
                      onChanged: (value) => setState(() {
                        _weight = value;
                        _syncData();
                      }),
                    ),
                  ),
                  SizedBox(height: 12 * s),
                  Container(
                    padding:
                        EdgeInsets.fromLTRB(16 * s, 16 * s, 16 * s, 14 * s),
                    decoration: BoxDecoration(
                      color: VF.surface,
                      borderRadius: BorderRadius.circular(24 * s),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8 * s,
                          offset: Offset(0, 4 * s),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BMI THAM CHIẾU',
                          style: VF.textStyle(
                            context,
                            size: 11,
                            weight: FontWeight.w700,
                            color: VF.textMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 14 * s),
                        SizedBox(
                          height: 34 * s,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final markerSize = 12 * s;
                              final trackHeight = 18 * s;
                              final trackInset = 2 * s;
                              final markerLeft = (trackInset +
                                      (_bmiPosition *
                                          (constraints.maxWidth -
                                              markerSize -
                                              (trackInset * 2))))
                                  .clamp(
                                trackInset,
                                constraints.maxWidth - markerSize - trackInset,
                              );
                              return Stack(
                                children: [
                                  Align(
                                    alignment: Alignment.center,
                                    child: Container(
                                      height: trackHeight,
                                      decoration: BoxDecoration(
                                        color: VF.bg.withValues(alpha: 0.75),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        border: Border.all(
                                          color: Colors.black
                                              .withValues(alpha: 0.05),
                                        ),
                                      ),
                                      padding: EdgeInsets.all(trackInset),
                                      child: const DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                            colors: [
                                              Color(0xFF5B9BD5),
                                              Color(0xFF5B9BD5),
                                              VF.accent,
                                              VF.accent,
                                              VF.amber,
                                              VF.amber,
                                              VF.coral,
                                              VF.coral,
                                            ],
                                            stops: [
                                              0.0,
                                              0.18,
                                              0.18,
                                              0.41,
                                              0.41,
                                              0.51,
                                              0.51,
                                              1.0,
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  AnimatedPositioned(
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOutCubic,
                                    left: markerLeft,
                                    top: (34 * s - markerSize) / 2,
                                    child: Container(
                                      width: markerSize,
                                      height: markerSize,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: bmiInfo.color,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: bmiInfo.color.withValues(
                                              alpha: 0.22,
                                            ),
                                            blurRadius: 10 * s,
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
                        SizedBox(height: 12 * s),
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: VF.sp(context, 13),
                              fontWeight: FontWeight.w700,
                            ),
                            children: [
                              TextSpan(
                                text: 'BMI ${_bmi.toStringAsFixed(1)}',
                                style: TextStyle(color: bmiInfo.color),
                              ),
                              const TextSpan(text: '  '),
                              TextSpan(
                                text: bmiInfo.label,
                                style: const TextStyle(color: VF.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16 * s),
                  Container(
                    padding:
                        EdgeInsets.fromLTRB(16 * s, 16 * s, 16 * s, 16 * s),
                    decoration: BoxDecoration(
                      color: VF.surface,
                      borderRadius: BorderRadius.circular(24 * s),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8 * s,
                          offset: Offset(0, 4 * s),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LỊCH TẬP',
                          style: VF.textStyle(
                            context,
                            size: 11,
                            weight: FontWeight.w700,
                            color: VF.textMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 6 * s),
                        Text(
                          'Chọn những ngày và khung giờ bạn có thể giữ đều mỗi tuần.',
                          style: VF.textStyle(
                            context,
                            size: 12,
                            weight: FontWeight.w500,
                            color: VF.textMuted,
                            height: 1.45,
                          ),
                        ),
                        SizedBox(height: 16 * s),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final spacing = 6 * s;
                            final chipSize =
                                (constraints.maxWidth - (spacing * 6)) / 7;
                            return Row(
                              children:
                                  List.generate(_dayLabels.length, (index) {
                                final selected = _days.contains(index);
                                return Padding(
                                  padding: EdgeInsets.only(
                                    right: index == _dayLabels.length - 1
                                        ? 0
                                        : spacing,
                                  ),
                                  child: GestureDetector(
                                    onTap: () => _toggleDay(index),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 160),
                                      width: chipSize,
                                      height: chipSize,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: selected ? VF.accent : VF.bg,
                                        border: Border.all(
                                          color: selected
                                              ? VF.accent
                                                  .withValues(alpha: 0.22)
                                              : Colors.black
                                                  .withValues(alpha: 0.05),
                                        ),
                                        boxShadow: selected
                                            ? [
                                                BoxShadow(
                                                  color: VF.accent.withValues(
                                                    alpha: 0.18,
                                                  ),
                                                  blurRadius: 14 * s,
                                                  offset: Offset(0, 6 * s),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        _dayLabels[index],
                                        style: VF.textStyle(
                                          context,
                                          size: chipSize < 40 * s ? 10.5 : 11.5,
                                          weight: selected
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                          color: selected
                                              ? Colors.white
                                              : VF.textMuted,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            );
                          },
                        ),
                        SizedBox(height: 10 * s),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12 * s,
                            vertical: 8 * s,
                          ),
                          decoration: BoxDecoration(
                            color: VF.accent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12 * s),
                          ),
                          child: Text(
                            '${_days.length} ngày/tuần',
                            style: VF.textStyle(
                              context,
                              size: 11,
                              weight: FontWeight.w700,
                              color: VF.accent,
                            ),
                          ),
                        ),
                        SizedBox(height: 18 * s),
                        Text(
                          'Khung giờ ưu tiên',
                          style: VF.textStyle(
                            context,
                            size: 13,
                            weight: FontWeight.w700,
                            color: VF.text,
                          ),
                        ),
                        SizedBox(height: 10 * s),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final spacing = 10 * s;
                            final itemWidth =
                                (constraints.maxWidth - spacing) / 2;
                            return Wrap(
                              spacing: spacing,
                              runSpacing: spacing,
                              children: _timeOptions.map((option) {
                                final selected = _preferredTime == option.id;
                                return SizedBox(
                                  width: itemWidth,
                                  child: _TimeOptionCard(
                                    title: option.title,
                                    subtitle: option.subtitle,
                                    hint: option.hint,
                                    icon: option.icon,
                                    tone: option.color,
                                    selected: selected,
                                    onTap: () => setState(() {
                                      _preferredTime = option.id;
                                      _syncData();
                                    }),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8 * s),
                ],
              ),
            ),
          ),
          VFOnboardingButton(
            label: 'Xem chương trình',
            onTap: _canContinue ? widget.onNext : null,
          ),
        ],
      ),
    );
  }
}

class _MeasurementCard extends StatelessWidget {
  const _MeasurementCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.picker,
  });

  final String label;
  final int value;
  final String unit;
  final Widget picker;

  @override
  Widget build(BuildContext context) {
    final s = VF.scale(context);
    return Container(
      padding: EdgeInsets.fromLTRB(16 * s, 20 * s, 16 * s, 14 * s),
      decoration: BoxDecoration(
        color: VF.surface,
        borderRadius: BorderRadius.circular(24 * s),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8 * s,
            offset: Offset(0, 4 * s),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            label,
            style: VF.textStyle(
              context,
              size: 11,
              weight: FontWeight.w700,
              color: VF.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 4 * s),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: VF.text,
              ),
              children: [
                TextSpan(
                  text: '$value',
                  style: TextStyle(
                    fontSize: VF.sp(context, 48),
                    letterSpacing: -3,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    fontSize: VF.sp(context, 16),
                    fontWeight: FontWeight.w600,
                    color: VF.textMuted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12 * s),
          picker,
        ],
      ),
    );
  }
}

class _TimeOptionCard extends StatelessWidget {
  const _TimeOptionCard({
    required this.title,
    required this.subtitle,
    required this.hint,
    required this.icon,
    required this.tone,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String hint;
  final IconData icon;
  final Color tone;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = VF.scale(context);
    final accent = selected ? VF.accent : tone;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.fromLTRB(14 * s, 14 * s, 14 * s, 12 * s),
        decoration: BoxDecoration(
          color: VF.surface,
          borderRadius: BorderRadius.circular(22 * s),
          border: Border.all(
            color: selected
                ? VF.accent.withValues(alpha: 0.20)
                : Colors.black.withValues(alpha: 0.05),
            width: selected ? 1.6 : 1,
          ),
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    VF.accent.withValues(alpha: 0.10),
                    VF.surface,
                  ],
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: selected
                  ? VF.accent.withValues(alpha: 0.10)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: selected ? 18 : 8,
              offset: Offset(0, 4 * s),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38 * s,
                  height: 38 * s,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12 * s),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    size: 19 * s,
                    color: accent,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 9 * s,
                    vertical: 5 * s,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? VF.accentSoft
                        : VF.bg.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    subtitle,
                    style: VF.textStyle(
                      context,
                      size: 10,
                      weight: FontWeight.w700,
                      color: selected ? VF.accent : VF.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12 * s),
            Text(
              title,
              style: VF.textStyle(
                context,
                size: 16,
                weight: FontWeight.w800,
                letterSpacing: -0.3,
                color: selected ? VF.text : VF.textSec,
              ),
            ),
            SizedBox(height: 6 * s),
            Text(
              hint,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: VF.textStyle(
                context,
                size: 11,
                weight: FontWeight.w500,
                color: VF.textMuted,
                height: 1.35,
              ),
            ),
            SizedBox(height: 10 * s),
            Row(
              children: [
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.arrow_forward_rounded,
                  size: 14 * s,
                  color: selected
                      ? VF.accent
                      : VF.textMuted.withValues(alpha: 0.6),
                ),
                SizedBox(width: 6 * s),
                Text(
                  selected ? 'Đã chọn' : 'Chạm để chọn',
                  style: VF.textStyle(
                    context,
                    size: 10.5,
                    weight: FontWeight.w700,
                    color: selected
                        ? VF.accent
                        : VF.textMuted.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BmiInfo {
  const _BmiInfo(this.label, this.color);

  final String label;
  final Color color;
}
