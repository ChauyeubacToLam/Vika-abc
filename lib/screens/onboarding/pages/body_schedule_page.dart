import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../onboarding_data.dart';
import '../vf_theme.dart';

class BodySchedulePage extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onComplete;
  const BodySchedulePage(
      {super.key, required this.data, required this.onComplete});

  @override
  State<BodySchedulePage> createState() => _BodySchedulePageState();
}

class _BodySchedulePageState extends State<BodySchedulePage> {
  late final TextEditingController _hCtrl;
  late final TextEditingController _wCtrl;

  static const _dayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  static const _times = [
    ('morning', 'Sáng', '6-9h', '☀️'),
    ('noon', 'Trưa', '11-13h', '🌤'),
    ('evening', 'Chiều tối', '17-20h', '🌅'),
    ('night', 'Tối', '20-22h', '🌙'),
  ];

  @override
  void initState() {
    super.initState();
    _hCtrl = TextEditingController(
        text: widget.data.heightCm?.toStringAsFixed(0) ?? '');
    _wCtrl = TextEditingController(
        text: widget.data.weightKg?.toStringAsFixed(0) ?? '');
    // Default schedule if empty
    if (widget.data.workoutDays.isEmpty) {
      widget.data.workoutDays = [0, 2, 4]; // Mon, Wed, Fri
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
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Thông tin & lịch tập',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: VF.text,
                          letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  const Text('Giúp AI tạo chương trình phù hợp nhất',
                      style: TextStyle(fontSize: 13, color: VF.textMuted)),
                  const SizedBox(height: 22),

                  // ── Height + Weight side by side ──
                  Row(children: [
                    Expanded(child: _unitField('CHIỀU CAO', _hCtrl, 'cm')),
                    const SizedBox(width: 10),
                    Expanded(child: _unitField('CÂN NẶNG', _wCtrl, 'kg')),
                  ]),
                  const SizedBox(height: 6),

                  // ── BMI Card ──
                  if (bmiValid) _BmiCard(bmi: bmi),

                  // ── Divider ──
                  Container(
                    height: 1,
                    color: VF.border,
                    margin: const EdgeInsets.symmetric(vertical: 18),
                  ),

                  // ── Schedule: Day picker ──
                  const Text('LỊCH TẬP',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: VF.textMuted,
                          letterSpacing: 0.8)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(7, (i) {
                      final on = widget.data.workoutDays.contains(i);
                      return GestureDetector(
                        onTap: () => _toggleDay(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 40,
                          height: 48,
                          decoration: BoxDecoration(
                            color: on ? VF.brand : VF.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: on ? VF.brand : VF.border,
                                width: on ? 2 : 1.5),
                            boxShadow: on
                                ? [
                                    BoxShadow(
                                        color: VF.brand.withValues(alpha: 0.2),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2))
                                  ]
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_dayLabels[i],
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: on ? Colors.white : VF.textSec)),
                              if (on)
                                Container(
                                  width: 5,
                                  height: 5,
                                  margin: const EdgeInsets.only(top: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                  if (widget.data.workoutDays.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('${widget.data.workoutDays.length} ngày/tuần',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: VF.brand)),
                    ),
                  const SizedBox(height: 14),

                  // ── Schedule: Time preference ──
                  const Text('GIỜ TẬP',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: VF.textMuted,
                          letterSpacing: 0.8)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _times.map((t) {
                      final on = widget.data.preferredTime == t.$1;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => widget.data.preferredTime = t.$1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: on ? VF.brandLight : VF.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: on
                                    ? VF.brand.withValues(alpha: 0.4)
                                    : VF.border,
                                width: on ? 2 : 1.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(t.$4, style: const TextStyle(fontSize: 14)),
                              const SizedBox(width: 6),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t.$2,
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: on ? VF.brand : VF.text)),
                                  Text(t.$3,
                                      style: const TextStyle(
                                          fontSize: 9.5, color: VF.textMuted)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Privacy note
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: VF.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: VF.border),
                    ),
                    child: const Row(children: [
                      Icon(Icons.lock_outline, size: 14, color: VF.textMuted),
                      SizedBox(width: 8),
                      Text('Chỉ lưu trên thiết bị, không chia sẻ',
                          style:
                              TextStyle(fontSize: 10.5, color: VF.textMuted)),
                    ]),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
            child: VFButton(
              label: 'Xem chương trình của tôi',
              onTap: _canProceed ? widget.onComplete : null,
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
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: VF.textMuted,
                letterSpacing: 0.5)),
        const SizedBox(height: 5),
        Container(
          decoration: BoxDecoration(
            color: VF.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: VF.border, width: 1.5),
          ),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
                ],
                onChanged: (_) => setState(() {}),
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: VF.text),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  hintText: unit == 'cm' ? '165' : '60',
                  hintStyle: TextStyle(
                      color: VF.textMuted.withValues(alpha: 0.5),
                      fontSize: 18,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(unit,
                  style: const TextStyle(fontSize: 13, color: VF.textMuted)),
            ),
          ]),
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

/// BMI display card with color bar and WHO Asian cutoffs.
class _BmiCard extends StatelessWidget {
  final double bmi;
  const _BmiCard({required this.bmi});

  @override
  Widget build(BuildContext context) {
    final info = _getBmiInfo(bmi);

    // Position: map BMI 12-38 to 0%-100%
    final pos = ((bmi - 12) / 26).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VF.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: VF.border),
        boxShadow: VF.cardShadow,
      ),
      child: Column(
        children: [
          // BMI number + label
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                const Text('BMI ',
                    style: TextStyle(
                        fontSize: 12,
                        color: VF.textMuted,
                        fontWeight: FontWeight.w600)),
                Text(bmi.toStringAsFixed(1),
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: info.color)),
              ]),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: info.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(info.label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: info.color)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Color bar
          SizedBox(
            height: 8,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Segments
                Row(children: [
                  _seg(VF.amber.withValues(alpha: 0.4), 25,
                      left: true), // Underweight: 12-18.5
                  _seg(VF.green.withValues(alpha: 0.45), 17), // Normal: 18.5-23
                  _seg(
                      VF.orange.withValues(alpha: 0.4), 8), // Overweight: 23-25
                  _seg(VF.red.withValues(alpha: 0.35), 50,
                      right: true), // Obese: 25+
                ]),
                // Indicator dot
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
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: info.color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                                color: info.color.withValues(alpha: 0.3),
                                blurRadius: 4)
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Labels
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Thiếu cân',
                  style: TextStyle(fontSize: 9, color: VF.textMuted)),
              Text('BT', style: TextStyle(fontSize: 9, color: VF.textMuted)),
              Text('Thừa', style: TextStyle(fontSize: 9, color: VF.textMuted)),
              Text('Béo phì',
                  style: TextStyle(fontSize: 9, color: VF.textMuted)),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Chuẩn WHO cho người châu Á (BMI 18.5-23)',
              style: TextStyle(fontSize: 10, color: VF.textMuted),
              textAlign: TextAlign.center),
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
            topLeft: left ? const Radius.circular(4) : Radius.zero,
            bottomLeft: left ? const Radius.circular(4) : Radius.zero,
            topRight: right ? const Radius.circular(4) : Radius.zero,
            bottomRight: right ? const Radius.circular(4) : Radius.zero,
          ),
        ),
      ),
    );
  }

  static _BmiInfo _getBmiInfo(double bmi) {
    if (bmi < 18.5) return const _BmiInfo('Thiếu cân', VF.amber);
    if (bmi < 23) return const _BmiInfo('Bình thường', VF.green);
    if (bmi < 25) return const _BmiInfo('Thừa cân', VF.orange);
    return const _BmiInfo('Béo phì', VF.red);
  }
}

class _BmiInfo {
  final String label;
  final Color color;
  const _BmiInfo(this.label, this.color);
}
