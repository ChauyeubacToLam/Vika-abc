import 'package:flutter/material.dart';
import '../onboarding_data.dart';

const _cyan = Color(0xFF00E5FF);
const _blue = Color(0xFF0091EA);
const _cardBg = Color(0xFF0D1228);
const _warning = Color(0xFFFFD600);

class AssessmentIntroPage extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const AssessmentIntroPage({
    super.key,
    required this.data,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<AssessmentIntroPage> createState() => _AssessmentIntroPageState();
}

class _AssessmentIntroPageState extends State<AssessmentIntroPage> {
  bool _showMedicalDetail = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kiểm tra nhanh!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Thử 5 cái squat để AI đánh giá thể lực của bạn',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),

          // ── Assessment preview card ──
          _buildAssessmentCard(),

          const SizedBox(height: 16),

          // ── Medical disclaimer ──
          _buildMedicalDisclaimer(),

          const Spacer(),

          // ── CTA ──
          SizedBox(
            width: double.infinity,
            height: 54,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: widget.data.medicalOk
                    ? const LinearGradient(colors: [_cyan, _blue])
                    : null,
                color: widget.data.medicalOk
                    ? null
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                boxShadow: widget.data.medicalOk
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
                onPressed: widget.data.medicalOk ? widget.onNext : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'BẮT ĐẦU KIỂM TRA →',
                  style: TextStyle(
                    color: widget.data.medicalOk
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
        ],
      ),
    );
  }

  Widget _buildAssessmentCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cyan.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_cyan, _blue]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.fitness_center,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '5 Squats đánh giá',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Khoảng 30 giây • Không cần thiết bị',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // What AI checks
          Text(
            'AI SẼ PHÂN TÍCH:',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          _analysisItem('Độ linh hoạt', 'Hông & cổ chân'),
          const SizedBox(height: 8),
          _analysisItem('Sức mạnh core', 'Độ ổn định thân trên'),
          const SizedBox(height: 8),
          _analysisItem('Sự kiểm soát', 'Nhịp độ & phối hợp'),
        ],
      ),
    );
  }

  Widget _analysisItem(String label, String desc) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: _cyan,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '— $desc',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.25),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildMedicalDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _warning.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _warning.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkbox
              GestureDetector(
                onTap: () {
                  setState(() {
                    widget.data.medicalOk = !widget.data.medicalOk;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    color: widget.data.medicalOk ? _cyan : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: widget.data.medicalOk
                          ? _cyan
                          : Colors.white.withValues(alpha: 0.2),
                      width: 2,
                    ),
                  ),
                  child: widget.data.medicalOk
                      ? const Icon(Icons.check,
                          color: Colors.black, size: 14)
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tôi không có vấn đề sức khỏe nghiêm trọng về khớp gối, lưng, hoặc tim mạch.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _showMedicalDetail = !_showMedicalDetail;
                        });
                      },
                      child: Text(
                        _showMedicalDetail
                            ? 'Ẩn chi tiết ▲'
                            : 'Tôi có vấn đề sức khỏe ▼',
                        style: TextStyle(
                          color: _warning.withValues(alpha: 0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Expandable detail
          if (_showMedicalDetail) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _warning.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _warning.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nếu bạn có bất kỳ vấn đề nào sau đây, hãy tham khảo ý kiến bác sĩ trước khi tập:',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...[
                    'Đau khớp gối hoặc từng phẫu thuật gối',
                    'Thoát vị đĩa đệm hoặc đau lưng mãn tính',
                    'Bệnh tim mạch hoặc huyết áp cao',
                    'Đang mang thai',
                    'Chấn thương gần đây',
                  ].map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '•  ',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.3),
                                fontSize: 11,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                item,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  fontSize: 11,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 6),
                  Text(
                    'Bạn vẫn có thể sử dụng app nhưng nên tập nhẹ nhàng và lắng nghe cơ thể.',
                    style: TextStyle(
                      color: _warning.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
