import 'dart:math';

import 'package:flutter/material.dart';

import '../onboarding_assessment_thresholds.dart';
import '../onboarding_data.dart';
import '../onboarding_primitives.dart';
import '../vf_theme.dart';

class LevelIssuePage extends StatefulWidget {
  const LevelIssuePage({
    super.key,
    required this.data,
    required this.onNext,
    required this.onBack,
  });

  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  State<LevelIssuePage> createState() => _LevelIssuePageState();
}

class _LevelIssuePageState extends State<LevelIssuePage> {
  static const _levels = [
    (
      id: 'beginner',
      title: 'Người mới',
      desc: 'Mới bắt đầu hoặc lâu không tập. Form cần xây từ nền.',
      preview: 'Tuần 1-2: học form. Tuần 3-4: tăng rep.',
    ),
    (
      id: 'intermediate',
      title: 'Trung cấp',
      desc: 'Đã tập đều, form khá. Cần thử thách hơn.',
      preview: 'Tập 4 ngày/tuần. Kết hợp sức mạnh + dẻo dai.',
    ),
    (
      id: 'advanced',
      title: 'Nâng cao',
      desc: 'Form tốt, muốn tối ưu chi tiết nhỏ.',
      preview: 'Tập 5+ ngày. Tối ưu tempo, ROM, consistency.',
    ),
  ];

  late final _SquatSummary _summary;
  late final String _predictedLevel;
  late String _selectedLevel;

  @override
  void initState() {
    super.initState();
    _summary = _buildSummary();
    _predictedLevel = _computeLevel();
    _selectedLevel = widget.data.confirmedLevel ?? _predictedLevel;
    widget.data.confirmedLevel = _selectedLevel;
  }

  _SquatSummary _buildSummary() {
    try {
      final logger = widget.data.squatLogger;
      final totalReps = logger.repLogs.length;
      final goodReps = (logger.setLogs['good_rep_count'] as int?) ?? 0;
      final heelFails = (logger.setLogs['heel_fails_count'] as int?) ?? 0;
      final depthFails = (logger.setLogs['depth_fails_count'] as int?) ?? 0;
      final trunkFails =
          (logger.setLogs['trunk_lean_fails_count'] as int?) ?? 0;
      final tempoFails = (logger.setLogs['tempo_fails_count'] as int?) ?? 0;
      final syncFails =
          (logger.setLogs['hip_shoulder_sync_fails_count'] as int?) ?? 0;

      final depths = logger.repLogs
          .map((r) => r.data['peak_knee_angle'] as num?)
          .whereType<num>()
          .map((v) => v.toDouble())
          .toList();
      final avgDepth = depths.isEmpty
          ? null
          : depths.reduce((a, b) => a + b) / depths.length;

      final repRatio = totalReps == 0 ? 0.0 : goodReps / totalReps;
      final score = OnboardingAssessmentThresholds.computeFormScore(
        repRatio: repRatio,
        heelFails: heelFails,
        depthFails: depthFails,
        trunkFails: trunkFails,
        tempoFails: tempoFails,
        syncFails: syncFails,
      );

      final primaryIssue = widget.data.squatInterpreter.getPrimaryIssueId() ??
          (widget.data.detectedIssues.isNotEmpty
              ? widget.data.detectedIssues.first
              : null);

      return _SquatSummary(
        totalReps: totalReps,
        goodReps: goodReps,
        heelFails: heelFails,
        depthFails: depthFails,
        trunkFails: trunkFails,
        tempoFails: tempoFails,
        syncFails: syncFails,
        avgDepth: avgDepth,
        score: score,
        primaryIssue: primaryIssue,
      );
    } catch (_) {
      return const _SquatSummary(
        totalReps: 5,
        goodReps: 3,
        heelFails: 2,
        depthFails: 1,
        trunkFails: 1,
        tempoFails: 0,
        syncFails: 0,
        avgDepth: 114,
        score: 68,
        primaryIssue:
            'ankle_mobility', // this is just temporary for development purposes; but need to return null and the UI should handle it gracefully without issue-specific feedback
      );
    }
  }

  double _computeKneeAngleCV() {
    final angles = widget.data.squatLogger.repLogs
        .map((r) => r.data['peak_knee_angle'] as num?)
        .whereType<num>()
        .map((v) => v.toDouble())
        .toList();
    if (angles.length < 3) return -1;
    final mean = angles.reduce((a, b) => a + b) / angles.length;
    if (mean == 0) return -1;
    final variance =
        angles.map((a) => (a - mean) * (a - mean)).reduce((a, b) => a + b) /
            angles.length;
    return (sqrt(variance) / mean) * 100;
  }

  String _computeLevel() {
    final goodRatio =
        _summary.totalReps == 0 ? 0.0 : _summary.goodReps / _summary.totalReps;
    return OnboardingAssessmentThresholds.computeLevel(
      avgDepth: _summary.avgDepth,
      goodRatio: goodRatio,
      trainingDuration: widget.data.trainingDuration,
      kneeAngleCv: _computeKneeAngleCV(),
    );
  }

  String? _issueQuestion() {
    try {
      return widget.data.squatInterpreter.getQuestion();
    } catch (_) {
      return '';
    }
  }

  String _issueLead() {
    switch (_summary.primaryIssue) {
      case 'ankle_mobility':
        return 'AI nhận thấy gót chân nâng lên ở phần lớn các rep';
      case 'ankle_mobility_restriction':
        return 'AI nhận thấy bạn vừa nhấc gót vừa đổ người về trước khi squat';
      case 'hip_flexor_overactivity':
        return 'AI nhận thấy thân trên phải nghiêng về trước khá nhiều để vào squat';
      case 'limited_mobility':
        return 'AI nhận thấy độ sâu squat chưa ổn định';
      default:
        return 'AI nhận thấy một điểm cần cải thiện ở bài squat';
    }
  }

  String _scoreCaption() =>
      OnboardingAssessmentThresholds.scoreCaption(_summary.score);

  String _depthLabel() =>
      OnboardingAssessmentThresholds.depthCaption(_summary.avgDepth);

  String _faultCaption(
    int count,
    String label, {
    String zeroText = 'ổn định',
  }) {
    if (_summary.totalReps == 0) return 'chưa có dữ liệu';
    if (count == 0) return zeroText;
    return '$count rep $label';
  }

  List<_SummaryMetric> _metrics() {
    final depthText = _summary.avgDepth == null
        ? '--'
        : '${_summary.avgDepth!.toStringAsFixed(0)}°';
    final heelText = '${_summary.heelFails}/${_summary.totalReps}';
    final formText = '${_summary.goodReps}/${_summary.totalReps}';

    return [
      _SummaryMetric(
        title: 'Rep đúng form',
        value: formText,
        caption: 'rep đạt yêu cầu',
      ),
      _SummaryMetric(
        title: 'Độ sâu',
        value: depthText,
        caption: _depthLabel(),
      ),
      _SummaryMetric(
        title: 'Gót chân',
        value: heelText,
        caption: _summary.heelFails == 0 ? 'ổn định' : 'rep bị nhấc gót',
      ),
      _SummaryMetric(
        title: 'Rep nông',
        value: '${_summary.depthFails}/${_summary.totalReps}',
        caption: _faultCaption(_summary.depthFails, 'độ sâu chưa đạt'),
      ),
      _SummaryMetric(
        title: 'Lưng nghiêng',
        value: '${_summary.trunkFails}/${_summary.totalReps}',
        caption: _faultCaption(_summary.trunkFails, 'đổ người'),
      ),
      _SummaryMetric(
        title: 'Nhịp lỗi',
        value: '${_summary.tempoFails}/${_summary.totalReps}',
        caption: _faultCaption(_summary.tempoFails, 'thiếu kiểm soát'),
      ),
      _SummaryMetric(
        title: 'Hông-vai',
        value: '${_summary.syncFails}/${_summary.totalReps}',
        caption: _faultCaption(_summary.syncFails, 'lệch nhịp'),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final s = VF.scale(context);
    final issueQuestion = _issueQuestion();
    final hasIssue = issueQuestion != null && issueQuestion.isNotEmpty;
    final metrics = _metrics();

    return ColoredBox(
      color: VF.bg,
      child: Stack(
        children: [
          const VFDarkCurveBackdrop(height: 332, radius: 40),
          Positioned(
            top: 36 * s,
            right: -18 * s,
            child: const VFDecorativeRing(size: 100, opacity: 0.04),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VFOnboardingNavBar(
                current: 7,
                total: 10,
                onBack: widget.onBack,
                dark: true,
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(28 * s, 16 * s, 28 * s, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KẾT QUẢ ĐÁNH GIÁ',
                      style: VF.textStyle(
                        context,
                        size: 10,
                        weight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: VF.jadeGlow.withValues(alpha: 0.35),
                      ),
                    ),
                    SizedBox(height: 8 * s),
                    Text(
                      'Tóm tắt squat của bạn',
                      style: VF.textStyle(
                        context,
                        size: 28,
                        weight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -1.5,
                        height: 1.1,
                      ),
                    ),
                    SizedBox(height: 8 * s),
                    Text(
                      'Dùng dữ liệu rep, lỗi gót chân và độ sâu từ bài squat vừa hoàn thành.',
                      style: VF.textStyle(
                        context,
                        size: 13,
                        weight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.30),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20 * s, 20 * s, 20 * s, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: EdgeInsets.all(18 * s),
                        decoration: BoxDecoration(
                          color: VF.surface,
                          borderRadius: BorderRadius.circular(24 * s),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10 * s,
                              offset: Offset(0, 4 * s),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                VFProgressRing(
                                  progress: (_summary.score / 100)
                                      .clamp(0.0, 1.0)
                                      .toDouble(),
                                  size: 76,
                                  strokeWidth: 5,
                                  glowWidth: 14,
                                  color: VF.accent,
                                  backgroundColor:
                                      VF.textMuted.withValues(alpha: 0.14),
                                  center: Text(
                                    '${_summary.score}',
                                    style: VF.textStyle(
                                      context,
                                      size: 24,
                                      weight: FontWeight.w900,
                                      color: VF.text,
                                      letterSpacing: -1.2,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 16 * s),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Điểm form squat',
                                        style: VF.textStyle(
                                          context,
                                          size: 16,
                                          weight: FontWeight.w800,
                                          color: VF.text,
                                        ),
                                      ),
                                      SizedBox(height: 4 * s),
                                      Text(
                                        _scoreCaption(),
                                        style: VF.textStyle(
                                          context,
                                          size: 12,
                                          weight: FontWeight.w500,
                                          color: VF.textMuted,
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16 * s),
                            Row(
                              children: [
                                Text(
                                  'Chi tiết chỉ số',
                                  style: VF.textStyle(
                                    context,
                                    size: 11,
                                    weight: FontWeight.w700,
                                    color: VF.textMuted,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'Vuốt sang phải',
                                  style: VF.textStyle(
                                    context,
                                    size: 10,
                                    weight: FontWeight.w600,
                                    color: VF.textMuted.withValues(alpha: 0.86),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 10 * s),
                            SizedBox(
                              height: 104 * s,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                itemCount: metrics.length,
                                separatorBuilder: (_, __) =>
                                    SizedBox(width: 8 * s),
                                itemBuilder: (context, index) {
                                  return SizedBox(
                                    width: 128 * s,
                                    child: _ResultMetricCard(
                                      metric: metrics[index],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 14 * s),
                      Padding(
                        padding: EdgeInsets.only(left: 4 * s, bottom: 10 * s),
                        child: Text(
                          'Trình độ phù hợp',
                          style: VF.textStyle(
                            context,
                            size: 13,
                            weight: FontWeight.w700,
                            color: VF.text.withValues(alpha: 0.92),
                          ),
                        ),
                      ),
                      ..._levels.map((level) {
                        final selected = _selectedLevel == level.id;
                        final predicted = _predictedLevel == level.id;
                        return Padding(
                          padding: EdgeInsets.only(bottom: 10 * s),
                          child: VFLeftAccentOptionCard(
                            selected: selected,
                            accentColor: VF.accent,
                            onTap: () => setState(() {
                              _selectedLevel = level.id;
                              widget.data.confirmedLevel = level.id;
                            }),
                            child: Padding(
                              padding: EdgeInsets.all(16 * s),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        level.title,
                                        style: VF.textStyle(
                                          context,
                                          size: 17,
                                          weight: FontWeight.w900,
                                          letterSpacing: -0.3,
                                          color:
                                              selected ? VF.text : VF.textSec,
                                        ),
                                      ),
                                      if (predicted) ...[
                                        SizedBox(width: 8 * s),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 10 * s,
                                            vertical: 3 * s,
                                          ),
                                          decoration: BoxDecoration(
                                            color: VF.accentSoft,
                                            borderRadius:
                                                BorderRadius.circular(8 * s),
                                          ),
                                          child: Text(
                                            'AI đề xuất',
                                            style: VF.textStyle(
                                              context,
                                              size: 10,
                                              weight: FontWeight.w700,
                                              color: VF.accent,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  SizedBox(height: 4 * s),
                                  Text(
                                    level.desc,
                                    style: VF.textStyle(
                                      context,
                                      size: 12,
                                      weight: FontWeight.w500,
                                      color: VF.textMuted,
                                      height: 1.5,
                                    ),
                                  ),
                                  if (selected) ...[
                                    SizedBox(height: 10 * s),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 12 * s,
                                        vertical: 8 * s,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            VF.accent.withValues(alpha: 0.06),
                                        borderRadius:
                                            BorderRadius.circular(10 * s),
                                      ),
                                      child: Text(
                                        level.preview,
                                        style: VF.textStyle(
                                          context,
                                          size: 11,
                                          weight: FontWeight.w600,
                                          color: VF.accent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      if (hasIssue)
                        Padding(
                          padding: EdgeInsets.fromLTRB(0, 6 * s, 0, 20 * s),
                          child: Container(
                            padding: EdgeInsets.all(16 * s),
                            decoration: BoxDecoration(
                              color: VF.amber.withValues(alpha: 0.06),
                              border: Border.all(
                                color: VF.amber.withValues(alpha: 0.08),
                              ),
                              borderRadius: BorderRadius.circular(18 * s),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.lightbulb_outline_rounded,
                                  size: 16 * s,
                                  color: VF.amber,
                                ),
                                SizedBox(width: 10 * s),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _issueLead(),
                                        style: VF.textStyle(
                                          context,
                                          size: 12,
                                          weight: FontWeight.w600,
                                          color: VF.amber,
                                        ),
                                      ),
                                      SizedBox(height: 4 * s),
                                      Text(
                                        issueQuestion,
                                        style: VF.textStyle(
                                          context,
                                          size: 13,
                                          weight: FontWeight.w700,
                                          color:
                                              VF.text.withValues(alpha: 0.88),
                                          height: 1.5,
                                        ),
                                      ),
                                      SizedBox(height: 10 * s),
                                      Row(
                                        children: ['Có', 'Không'].map((label) {
                                          final selected =
                                              widget.data.issueAnswer == label;
                                          return Padding(
                                            padding: EdgeInsets.only(
                                              right: label == 'Có' ? 8 * s : 0,
                                            ),
                                            child: GestureDetector(
                                              onTap: () => setState(
                                                () => widget.data.issueAnswer =
                                                    label,
                                              ),
                                              child: AnimatedContainer(
                                                duration: const Duration(
                                                  milliseconds: 160,
                                                ),
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 20 * s,
                                                  vertical: 7 * s,
                                                ),
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          10 * s),
                                                  color: selected
                                                      ? VF.amber.withValues(
                                                          alpha: 0.15,
                                                        )
                                                      : VF.textMuted.withValues(
                                                          alpha: 0.06,
                                                        ),
                                                  border: Border.all(
                                                    color: selected
                                                        ? VF.amber.withValues(
                                                            alpha: 0.25,
                                                          )
                                                        : Colors.transparent,
                                                    width: 1.5 * s,
                                                  ),
                                                ),
                                                child: Text(
                                                  label,
                                                  style: VF.textStyle(
                                                    context,
                                                    size: 13,
                                                    weight: FontWeight.w700,
                                                    color: selected
                                                        ? VF.amber
                                                        : VF.textMuted,
                                                  ),
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
                    ],
                  ),
                ),
              ),
              VFOnboardingButton(
                label: 'Tiếp tục',
                onTap: widget.onNext,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultMetricCard extends StatelessWidget {
  const _ResultMetricCard({required this.metric});

  final _SummaryMetric metric;

  @override
  Widget build(BuildContext context) {
    final s = VF.scale(context);
    return Container(
      padding: EdgeInsets.fromLTRB(12 * s, 12 * s, 12 * s, 10 * s),
      decoration: BoxDecoration(
        color: VF.bg.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16 * s),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metric.title,
            style: VF.textStyle(
              context,
              size: 10,
              weight: FontWeight.w700,
              color: VF.textMuted,
            ),
          ),
          SizedBox(height: 6 * s),
          Text(
            metric.value,
            style: VF.textStyle(
              context,
              size: 20,
              weight: FontWeight.w900,
              color: VF.text,
              letterSpacing: -0.8,
            ),
          ),
          SizedBox(height: 2 * s),
          Text(
            metric.caption,
            style: VF.textStyle(
              context,
              size: 10,
              weight: FontWeight.w500,
              color: VF.textMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric {
  const _SummaryMetric({
    required this.title,
    required this.value,
    required this.caption,
  });

  final String title;
  final String value;
  final String caption;
}

class _SquatSummary {
  const _SquatSummary({
    required this.totalReps,
    required this.goodReps,
    required this.heelFails,
    required this.depthFails,
    required this.trunkFails,
    required this.tempoFails,
    required this.syncFails,
    required this.avgDepth,
    required this.score,
    required this.primaryIssue,
  });

  final int totalReps;
  final int goodReps;
  final int heelFails;
  final int depthFails;
  final int trunkFails;
  final int tempoFails;
  final int syncFails;
  final double? avgDepth;
  final int score;
  final String? primaryIssue;
}
