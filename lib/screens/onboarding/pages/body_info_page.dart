import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../onboarding_data.dart';

const _cyan = Color(0xFF00E5FF);
const _blue = Color(0xFF0091EA);
const _cardBg = Color(0xFF0D1228);

class BodyInfoPage extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onComplete;

  const BodyInfoPage({
    super.key,
    required this.data,
    required this.onComplete,
  });

  @override
  State<BodyInfoPage> createState() => _BodyInfoPageState();
}

class _BodyInfoPageState extends State<BodyInfoPage> {
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightFocus = FocusNode();

  bool get _canProceed {
    final h = double.tryParse(_heightController.text);
    final w = double.tryParse(_weightController.text);
    return h != null && h >= 100 && h <= 250 && w != null && w >= 25 && w <= 200;
  }

  void _submit() {
    if (!_canProceed) return;
    widget.data.heightCm = double.parse(_heightController.text);
    widget.data.weightKg = double.parse(_weightController.text);
    widget.onComplete();
  }

  @override
  void initState() {
    super.initState();
    if (widget.data.heightCm != null) {
      _heightController.text = widget.data.heightCm!.toStringAsFixed(0);
    }
    if (widget.data.weightKg != null) {
      _weightController.text = widget.data.weightKg!.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _heightFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            const Text(
              'Thông tin cơ thể',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Giúp AI tính toán chính xác hơn cho bạn',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),

            // ── Height ──
            _buildInputCard(
              label: 'CHIỀU CAO',
              hint: '165',
              unit: 'cm',
              icon: Icons.height,
              controller: _heightController,
              focusNode: _heightFocus,
              nextAction: TextInputAction.next,
              avgHint: 'Trung bình người Việt: Nam 168cm, Nữ 156cm',
            ),
            const SizedBox(height: 16),

            // ── Weight ──
            _buildInputCard(
              label: 'CÂN NẶNG',
              hint: '60',
              unit: 'kg',
              icon: Icons.monitor_weight_outlined,
              controller: _weightController,
              nextAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              avgHint: 'Không cần chính xác, ước lượng cũng được!',
            ),
            const SizedBox(height: 12),

            // ── Privacy note ──
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.04)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    color: Colors.white.withValues(alpha: 0.15),
                    size: 16,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Thông tin chỉ lưu trên thiết bị, không chia sẻ với ai.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.25),
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── CTA ──
            SizedBox(
              width: double.infinity,
              height: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: _canProceed
                      ? const LinearGradient(colors: [_cyan, _blue])
                      : null,
                  color: _canProceed
                      ? null
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _canProceed
                      ? [
                          BoxShadow(
                            color: _cyan.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: ElevatedButton(
                  onPressed: _canProceed ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'XEM CHƯƠNG TRÌNH CỦA TÔI →',
                    style: TextStyle(
                      color: _canProceed
                          ? Colors.black
                          : Colors.white.withValues(alpha: 0.2),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Được tạo riêng dựa trên kết quả phân tích của bạn',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.2),
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard({
    required String label,
    required String hint,
    required String unit,
    required IconData icon,
    required TextEditingController controller,
    FocusNode? focusNode,
    TextInputAction? nextAction,
    ValueChanged<String>? onSubmitted,
    String? avgHint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 14),
                child: Icon(
                  icon,
                  color: Colors.white.withValues(alpha: 0.2),
                  size: 20,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: nextAction,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: onSubmitted,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.1),
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 16),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  unit,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.25),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (avgHint != null) ...[
          const SizedBox(height: 6),
          Text(
            avgHint,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.2),
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }
}
