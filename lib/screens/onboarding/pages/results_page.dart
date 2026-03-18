import 'package:flutter/material.dart';
import '../onboarding_data.dart';

const _cyan = Color(0xFF00E5FF);
const _blue = Color(0xFF0091EA);
const _cardBg = Color(0xFF0D1228);
const _success = Color(0xFF00E676);
const _warning = Color(0xFFFFD600);

class ResultsPage extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;

  const ResultsPage({super.key, required this.data, required this.onNext});

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  List<_Insight> get _insights {
    final d = widget.data;
    final list = <_Insight>[];

    if (d.mobilityLevel == 'limited') {
      list.add(_Insight(
        icon: Icons.accessibility_new,
        title: 'Hạn chế vận động hông',
        desc:
            'Bình thường với dân văn phòng ngồi nhiều. Sẽ cải thiện trong 2-3 tuần!',
        color: _warning,
      ));
    }
    if (d.hasAnkleIssue) {
      list.add(_Insight(
        icon: Icons.directions_walk,
        title: 'Cổ chân hơi cứng',
        desc:
            'Gót chân hay nhấc khi squat. Bài khởi động cổ chân sẽ giúp bạn!',
        color: _warning,
      ));
    }
    if (d.stabilityLevel == 'weak') {
      list.add(_Insight(
        icon: Icons.sync,
        title: 'Core cần tăng cường',
        desc: 'Thân trên nghiêng nhiều khi squat. Plank sẽ giúp cải thiện!',
        color: _warning,
      ));
    }
    if (list.isEmpty) {
      list.add(_Insight(
        icon: Icons.star,
        title: 'Nền tảng tốt!',
        desc:
            'Tư thế squat khá ổn. Chương trình sẽ giúp bạn tiến bộ nhanh hơn!',
        color: _success,
      ));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final levelLabel = d.fitnessLevel == 'beginner'
        ? 'Người mới'
        : d.fitnessLevel == 'advanced'
            ? 'Khá tốt'
            : 'Trung bình';
    final levelColor = d.fitnessLevel == 'beginner'
        ? _warning
        : d.fitnessLevel == 'advanced'
            ? _success
            : _cyan;

    return FadeTransition(
      opacity: CurvedAnimation(parent: _anim, curve: Curves.easeOut),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          children: [
            // ── Header ──
            const Icon(Icons.track_changes, color: _cyan, size: 36),
            const SizedBox(height: 10),
            const Text(
              'Kết quả phân tích',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Dựa trên ${d.totalReps} squats của bạn',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),

            // ── Level badge ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
              decoration: BoxDecoration(
                color: levelColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: levelColor.withValues(alpha: 0.25), width: 1.5),
              ),
              child: Text(
                levelLabel,
                style: TextStyle(
                  color: levelColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Stats row ──
            Row(
              children: [
                _StatCard(
                  label: 'Reps tốt',
                  value: '${d.goodReps}/${d.totalReps}',
                  color: _success,
                ),
                const SizedBox(width: 10),
                _StatCard(
                  label: 'Độ sâu TB',
                  value: '${d.avgDepthAngle?.toStringAsFixed(0) ?? '-'}°',
                  color: _cyan,
                ),
                const SizedBox(width: 10),
                _StatCard(
                  label: 'Nhịp TB',
                  value: '${d.avgDescentTime?.toStringAsFixed(1) ?? '-'}s',
                  color: const Color(0xFFAB47BC),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Insights ──
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'HLV AI NHẬN XÉT',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 10),
            ..._insights.map((ins) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _InsightCard(insight: ins),
                )),
            const SizedBox(height: 24),

            // ── CTA ──
            SizedBox(
              width: double.infinity,
              height: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_cyan, _blue]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _cyan.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: widget.onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'TIẾP TỤC →',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tạo tài khoản để lưu kết quả và nhận chương trình',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.2),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Insight {
  final IconData icon;
  final String title;
  final String desc;
  final Color color;
  const _Insight({
    required this.icon,
    required this.title,
    required this.desc,
    required this.color,
  });
}

class _InsightCard extends StatelessWidget {
  final _Insight insight;
  const _InsightCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: insight.color.withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(insight.icon, color: insight.color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  insight.desc,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
