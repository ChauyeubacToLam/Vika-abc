import 'package:flutter/material.dart';
import '../onboarding_data.dart';
import '../vf_theme.dart';

class LevelIssuePage extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  const LevelIssuePage({super.key, required this.data, required this.onNext});

  @override
  State<LevelIssuePage> createState() => _LevelIssuePageState();
}

class _LevelIssuePageState extends State<LevelIssuePage> {
  late String _level;

  @override
  void initState() {
    super.initState();
    _level = _computeLevel();
    widget.data.confirmedLevel = _level;
  }

  /// Rule-based level from logger data.
  String _computeLevel() {
    final sqLogs = widget.data.squatLogger.setLogs;
    // final wpLogs = widget.data.pushUpLogger?.setLogs ?? {};

    final sqGood = (sqLogs["good_rep_count"] as int?) ?? 0;
    final sqTotal = widget.data.squatLogger.repLogs.length;
    // final wpGood = (wpLogs["good_rep_count"] as int?) ?? 0;
    // final wpTotal = widget.data.pushUpLogger?.repLogs.length ?? 0;

    final totalGood = sqGood; // + wpGood;
    final totalReps = sqTotal; // + wpTotal;
    final ratio = totalReps > 0 ? totalGood / totalReps : 0.0;

    if (ratio >= 0.7) return 'advanced';
    if (ratio >= 0.4) return 'intermediate';
    return 'beginner';
  }

  static const _levels = [
    _LevelOption(
      id: 'beginner',
      label: 'Người mới',
      desc: 'Xây nền tảng, form đúng trước',
      icon: '🌱',
      color: VF.green,
      preview: ['3 buổi/tuần', '~10 phút/buổi', 'Squat · Plank · JJ'],
    ),
    _LevelOption(
      id: 'intermediate',
      label: 'Trung bình',
      desc: 'Sẵn sàng thử thách hơn',
      icon: '💪',
      color: VF.brand,
      preview: ['3-4 buổi/tuần', '~12 phút/buổi', 'Squat · Push-up · Plank'],
    ),
    _LevelOption(
      id: 'advanced',
      label: 'Khá tốt',
      desc: 'Muốn nâng cao, tăng cường độ',
      icon: '🔥',
      color: VF.orange,
      preview: ['4-5 buổi/tuần', '~15 phút/buổi', 'Tất cả · Reps cao'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Get top issue from interpreter (if squat assessment ran)
    final issueQuestion = widget.data.squatInterpreter.getQuestion();
    final hasIssue = issueQuestion.isNotEmpty;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                const Text('BƯỚC TIẾP THEO',
                    style: TextStyle(
                      fontSize: 11,
                      color: VF.textMuted,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    )),
                const SizedBox(height: 6),
                const Text('Chọn trình độ của bạn',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: VF.text,
                        letterSpacing: -0.5)),
                const SizedBox(height: 4),
                const Text(
                    'AI gợi ý dựa trên 10 reps. Bạn luôn có thể thay đổi.',
                    style: TextStyle(fontSize: 13, color: VF.textMuted)),
                const SizedBox(height: 20),

                // Level cards
                ..._levels.map((l) => _buildLevelCard(l)),

                // Issue spotlight (only if interpreter found something)
                if (hasIssue) ...[
                  const SizedBox(height: 16),
                  _buildIssueCard(issueQuestion),
                ],
              ],
            ),
          ),
        ),

        // CTA
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
          child: VFButton(label: 'Tiếp tục', onTap: widget.onNext),
        ),
      ],
    );
  }

  Widget _buildLevelCard(_LevelOption l) {
    final on = _level == l.id;
    final isPredicted = l.id == _computeLevel();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => setState(() {
          _level = l.id;
          widget.data.confirmedLevel = l.id;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: on ? l.color.withValues(alpha: 0.35) : VF.border,
              width: 2,
            ),
            boxShadow: on
                ? [
                    BoxShadow(
                        color: l.color.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 4))
                  ]
                : [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 3,
                        offset: const Offset(0, 1))
                  ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Card top
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: on
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            l.color.withValues(alpha: 0.06),
                            l.color.withValues(alpha: 0.02),
                          ],
                        )
                      : null,
                  color: on ? null : VF.surface,
                ),
                child: Row(
                  children: [
                    // Icon
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: on ? l.color.withValues(alpha: 0.12) : VF.bg,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      alignment: Alignment.center,
                      child: Text(l.icon, style: const TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(width: 14),

                    // Text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text(l.label,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: VF.text)),
                            if (isPredicted) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: VF.brand.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('✨ ', style: TextStyle(fontSize: 8)),
                                    Text('AI gợi ý',
                                        style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: VF.brand)),
                                  ],
                                ),
                              ),
                            ],
                          ]),
                          const SizedBox(height: 2),
                          Text(l.desc,
                              style: const TextStyle(
                                  fontSize: 12, color: VF.textMuted)),
                        ],
                      ),
                    ),

                    // Radio
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: on ? l.color : Colors.transparent,
                        border: Border.all(
                          color: on ? l.color : VF.border,
                          width: 2,
                        ),
                      ),
                      child: on
                          ? Center(
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),

              // Expanded preview
              if (on)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  color: l.color.withValues(alpha: 0.02),
                  child: Column(
                    children: [
                      Container(
                        height: 1,
                        color: l.color.withValues(alpha: 0.1),
                        margin: const EdgeInsets.only(bottom: 10),
                      ),
                      Row(
                        children: l.preview.map((p) {
                          return Expanded(
                            child: Container(
                              margin: EdgeInsets.only(
                                  right: p != l.preview.last ? 6 : 0),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 6),
                              decoration: BoxDecoration(
                                color: VF.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: l.color.withValues(alpha: 0.1)),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                p,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: VF.textSec,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIssueCard(String question) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [VF.amberBg, Color(0xFFFEF9EF)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VF.amber.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
              color: VF.amber.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          // Header
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  VF.amber.withValues(alpha: 0.2),
                  VF.amber.withValues(alpha: 0.1),
                ]),
                borderRadius: BorderRadius.circular(11),
              ),
              alignment: Alignment.center,
              child: const Text('👟', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AI phát hiện từ bài tập',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: VF.text)),
                  const SizedBox(height: 1),
                  Text(question,
                      style: const TextStyle(
                          fontSize: 11, color: VF.textSec, height: 1.5)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),

          // Buttons
          Row(children: [
            _IssueButton(
              emoji: '😣',
              label: 'Đúng',
              selected: widget.data.issueAnswer == 'yes',
              activeColor: VF.amber,
              onTap: () => setState(() => widget.data.issueAnswer = 'yes'),
            ),
            const SizedBox(width: 8),
            _IssueButton(
              emoji: '👌',
              label: 'Không',
              selected: widget.data.issueAnswer == 'no',
              activeColor: VF.brand,
              onTap: () => setState(() => widget.data.issueAnswer = 'no'),
            ),
          ]),
        ],
      ),
    );
  }
}

class _IssueButton extends StatelessWidget {
  final String emoji, label;
  final bool selected;
  final Color activeColor;
  final VoidCallback onTap;

  const _IssueButton({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? activeColor.withValues(alpha: 0.1) : VF.surface,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: selected ? activeColor.withValues(alpha: 0.35) : VF.border,
              width: 2,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: activeColor.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: selected ? activeColor : VF.textSec),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelOption {
  final String id, label, desc, icon;
  final Color color;
  final List<String> preview;
  const _LevelOption({
    required this.id,
    required this.label,
    required this.desc,
    required this.icon,
    required this.color,
    required this.preview,
  });
}
