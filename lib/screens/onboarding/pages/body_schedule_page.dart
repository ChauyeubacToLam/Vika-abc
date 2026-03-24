import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../onboarding_data.dart';
import '../vf_theme.dart';

class BodySchedulePage extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const BodySchedulePage({
    super.key,
    required this.data,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<BodySchedulePage> createState() => _BodySchedulePageState();
}

class _BodySchedulePageState extends State<BodySchedulePage> {
  late final TextEditingController _hCtrl;
  late final TextEditingController _wCtrl;

  static const _dayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  static const _times = [
    ('morning', 'Sáng', '6-9h'),
    ('noon', 'Trưa', '11-13h'),
    ('evening', 'Chiều tối', '17-20h'),
    ('night', 'Tối', '20-22h'),
  ];

  @override
  void initState() {
    super.initState();
    _hCtrl = TextEditingController(
      text: widget.data.heightCm?.toStringAsFixed(0) ?? '',
    );
    _wCtrl = TextEditingController(
      text: widget.data.weightKg?.toStringAsFixed(0) ?? '',
    );
    if (widget.data.workoutDays.isEmpty) {
      widget.data.workoutDays = [0, 2, 4];
    }
    widget.data.preferredTime ??= 'evening';
  }

  void _updateBodyData() {
    widget.data.heightCm = double.tryParse(_hCtrl.text);
    widget.data.weightKg = double.tryParse(_wCtrl.text);
  }

  void _toggleDay(int day) {
    setState(() {
      if (widget.data.workoutDays.contains(day)) {
        widget.data.workoutDays.remove(day);
      } else {
        widget.data.workoutDays.add(day);
      }
    });
  }

  bool get _canProceed {
    final h = double.tryParse(_hCtrl.text) ?? 0;
    final w = double.tryParse(_wCtrl.text) ?? 0;
    return h >= 100 &&
        h <= 250 &&
        w >= 25 &&
        w <= 200 &&
        widget.data.workoutDays.isNotEmpty &&
        widget.data.preferredTime != null;
  }

  @override
  Widget build(BuildContext context) {
    _updateBodyData();
    final bmi = widget.data.bmi;
    final bmiValid = bmi != null && bmi >= 10 && bmi <= 50;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        children: [
          VFProgressBar(current: 6, total: 7, onBack: widget.onBack),
          Expanded(
            child: VFFitViewport(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Thông tin và lịch tập',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: VF.text,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Phần cuối cùng trước khi hiện chương trình. Giữ mọi lựa chọn gọn, rõ, và thiên về planning hơn là decoration.',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: VF.textMuted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: _unitField('CHIỀU CAO', _hCtrl, 'cm')),
                      const SizedBox(width: 10),
                      Expanded(child: _unitField('CÂN NẶNG', _wCtrl, 'kg')),
                    ],
                  ),
                  if (bmiValid) ...[
                    const SizedBox(height: 12),
                    _BmiCard(bmi: bmi),
                  ],
                  const SizedBox(height: 16),
                  VFPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ngày tập',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: VF.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Chọn các ngày bạn có thể duy trì đều nhất.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: VF.textMuted,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(7, (i) {
                            final on = widget.data.workoutDays.contains(i);
                            return GestureDetector(
                              onTap: () => _toggleDay(i),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 40,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: on ? VF.accentSoft : VF.bg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: on
                                        ? VF.accent.withValues(alpha: 0.28)
                                        : VF.border,
                                    width: 1.4,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _dayLabels[i],
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: on ? VF.accent : VF.textSec,
                                      ),
                                    ),
                                    if (on) ...[
                                      const SizedBox(height: 3),
                                      const VFCheckIcon(size: 9),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  VFPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Khung giờ ưu tiên',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: VF.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'VinaFit sẽ ưu tiên reminder và planning quanh khung giờ này.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: VF.textMuted,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...List.generate(2, (rowIndex) {
                          final start = rowIndex * 2;
                          final rowItems = _times.skip(start).take(2).toList();

                          return Padding(
                            padding:
                                EdgeInsets.only(bottom: rowIndex == 1 ? 0 : 8),
                            child: Row(
                              children: List.generate(rowItems.length, (index) {
                                final item = rowItems[index];
                                final isLast = index == rowItems.length - 1;
                                return Expanded(
                                  child: Padding(
                                    padding:
                                        EdgeInsets.only(right: isLast ? 0 : 8),
                                    child: _TimeOptionCard(
                                      label: item.$2,
                                      subtitle: item.$3,
                                      selected:
                                          widget.data.preferredTime == item.$1,
                                      onTap: () => setState(() {
                                        widget.data.preferredTime = item.$1;
                                      }),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
            child: VFButton(
              label: 'Xem chương trình của tôi',
              onTap: _canProceed ? widget.onNext : null,
              enabled: _canProceed,
            ),
          ),
        ],
      ),
    );
  }

  Widget _unitField(String label, TextEditingController ctrl, String unit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: VF.textMuted,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: VF.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: VF.border, width: 1.5),
            boxShadow: VF.cardShadow,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: VF.text,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    hintText: unit == 'cm' ? '165' : '60',
                    hintStyle: TextStyle(
                      color: VF.textMuted.withValues(alpha: 0.45),
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 13,
                    color: VF.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _hCtrl.dispose();
    _wCtrl.dispose();
    super.dispose();
  }
}

class _TimeOptionCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _TimeOptionCard({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? VF.accentSoft : VF.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                selected ? VF.accent.withValues(alpha: 0.28) : VF.border,
            width: 1.4,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (selected) ...[
                  const VFCheckIcon(size: 10),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected ? VF.accent : VF.text,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: VF.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BmiCard extends StatelessWidget {
  final double bmi;

  const _BmiCard({required this.bmi});

  @override
  Widget build(BuildContext context) {
    final info = _getBmiInfo(bmi);
    final pos = ((bmi - 12) / 26).clamp(0.0, 1.0);

    return VFPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'BMI ',
                    style: TextStyle(
                      fontSize: 12,
                      color: VF.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    bmi.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: info.color,
                    ),
                  ),
                ],
              ),
              VFPill(
                label: info.label,
                color: info.color,
                background: info.color.withValues(alpha: 0.10),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 10,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Row(
                  children: [
                    _seg(VF.amber.withValues(alpha: 0.35), 25, left: true),
                    _seg(VF.green.withValues(alpha: 0.40), 17),
                    _seg(VF.amber.withValues(alpha: 0.50), 8),
                    _seg(VF.red.withValues(alpha: 0.30), 50, right: true),
                  ],
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: -3,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: pos,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: info.color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Thiếu cân', style: TextStyle(fontSize: 9, color: VF.textMuted)),
              Text('BT', style: TextStyle(fontSize: 9, color: VF.textMuted)),
              Text('Thừa', style: TextStyle(fontSize: 9, color: VF.textMuted)),
              Text('Béo phì', style: TextStyle(fontSize: 9, color: VF.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _seg(Color color, int flex, {bool left = false, bool right = false}) {
    return Expanded(
      flex: flex,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.only(
            topLeft: left ? const Radius.circular(999) : Radius.zero,
            bottomLeft: left ? const Radius.circular(999) : Radius.zero,
            topRight: right ? const Radius.circular(999) : Radius.zero,
            bottomRight: right ? const Radius.circular(999) : Radius.zero,
          ),
        ),
      ),
    );
  }

  static _BmiInfo _getBmiInfo(double bmi) {
    if (bmi < 18.5) return const _BmiInfo('Thiếu cân', VF.amber);
    if (bmi < 23) return const _BmiInfo('Bình thường', VF.green);
    if (bmi < 25) return const _BmiInfo('Thừa cân', VF.amber);
    return const _BmiInfo('Béo phì', VF.red);
  }
}

class _BmiInfo {
  final String label;
  final Color color;

  const _BmiInfo(this.label, this.color);
}
