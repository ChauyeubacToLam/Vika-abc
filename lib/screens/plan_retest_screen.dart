import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/exercise_definition.dart';
import '../models/exercise_lookup.dart';
import '../services/recommendation/fitness_retest_service.dart';
import '../services/recommendation/models/plan.dart';
import '../services/recommendation/progression_service.dart';
import '../services/recommendation/recommendation_service.dart';
import '../services/recommendation/weekly_check_in_service.dart';
import '../theme/app_colors.dart';
import '../theme/responsive.dart';
import '../utils/exercise_logger.dart';
import 'exercise/exercise_launch_args.dart';
import 'weekly_check_in_screen.dart';

class PlanRetestLaunchArgs {
  const PlanRetestLaunchArgs({required this.pending});

  final PendingFitnessRetest pending;
}

class PlanRetestScreen extends StatefulWidget {
  const PlanRetestScreen({
    super.key,
    required this.args,
  });

  final PlanRetestLaunchArgs args;

  @override
  State<PlanRetestScreen> createState() => _PlanRetestScreenState();
}

class _PlanRetestScreenState extends State<PlanRetestScreen> {
  final _retest = FitnessRetestService();
  final _recommendations = RecommendationService();
  final _checkIns = WeeklyCheckInService();
  final _progression = RecommendationProgressionService();

  _RetestStep _step = _RetestStep.intro;
  SubmittedFitnessRetest? _submitted;
  Plan? _newPlan;
  String? _error;
  bool _busy = false;

  Future<void> _startRetest() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    final squat = await _runAssessment(squatAssessmentDefinition);
    if (!mounted || squat == null) {
      setState(() => _busy = false);
      return;
    }

    final wallPushup = await _runAssessment(wallPushupAssessmentDefinition);
    if (!mounted || wallPushup == null) {
      setState(() => _busy = false);
      return;
    }

    await _maybeOpenWeekSevenCheckIn();

    final submitted = await _retest.submitRetest(
      recommendationId: widget.args.pending.recommendationId,
      result: FitnessRetestResult(
        squatLogger: squat,
        wallPushupLogger: wallPushup,
      ),
    );
    if (!mounted) return;

    if (submitted == null) {
      setState(() {
        _busy = false;
        _error = 'Chưa lưu được kết quả. Bạn thử lại nhé.';
      });
      return;
    }

    setState(() {
      _submitted = submitted;
      _step = _RetestStep.result;
      _busy = false;
    });
  }

  Future<ExerciseLogger?> _runAssessment(ExerciseDefinition definition) async {
    final result = await Navigator.of(context).pushNamed(
      '/exercise',
      arguments: definition,
    );
    if (result is Map && result['logger'] is ExerciseLogger) {
      return result['logger'] as ExerciseLogger;
    }
    return null;
  }

  Future<void> _maybeOpenWeekSevenCheckIn() async {
    final due = await _checkIns.isDue(
      recommendationId: widget.args.pending.recommendationId,
      weekNumber: widget.args.pending.weekNumber,
    );
    if (!mounted || !due) return;
    await Navigator.of(context).pushNamed(
      '/weekly-check-in',
      arguments: WeeklyCheckInLaunchArgs(
        recommendationId: widget.args.pending.recommendationId,
        weekNumber: widget.args.pending.weekNumber,
      ),
    );
  }

  Future<void> _acceptSuggestedLevel() async {
    final submitted = _submitted;
    if (submitted == null) return;
    setState(() => _busy = true);
    final ok = await _retest.confirmSuggestedLevel(
      retestId: submitted.retestId,
      suggestedLevel: submitted.suggestion.suggestedLevel,
    );
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _busy = false;
        _error = 'Chưa cập nhật được level. Bạn thử lại nhé.';
      });
      return;
    }
    await _generateNewPlan();
  }

  Future<void> _declineSuggestedLevel() async {
    final submitted = _submitted;
    if (submitted == null) return;
    setState(() => _busy = true);
    await _retest.declineSuggestedLevel(submitted.retestId);
    if (!mounted) return;
    await _generateNewPlan();
  }

  Future<void> _continueWithSameLevel() async {
    setState(() => _busy = true);
    await _generateNewPlan();
  }

  Future<void> _generateNewPlan() async {
    final result = await _recommendations.generatePlanForCurrentUser(
      trigger: 'reassessment',
    );
    if (!mounted) return;
    if (result == null) {
      setState(() {
        _busy = false;
        _error = 'Chưa tạo được kế hoạch mới. Bạn thử lại nhé.';
      });
      return;
    }

    _newPlan = result.plan;
    await _showUnlocksIfAny(result.plan.recommendationId);
    if (!mounted) return;
    setState(() {
      _step = _RetestStep.finalChoice;
      _busy = false;
    });
  }

  Future<void> _showUnlocksIfAny(String recommendationId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final notices = await _progression.fetchPendingUnlockNotices(
      userId,
      recommendationId: recommendationId,
    );
    if (!mounted || notices.isEmpty) return;

    await showDialog<void>(
      context: context,
      builder: (_) => _VariantUnlockDialog(notices: notices),
    );
    await _progression.markUnlockNoticesApplied(
      userId: userId,
      recommendationId: recommendationId,
      notices: notices,
    );
  }

  void _startFirstSessionToday() {
    final plan = _newPlan;
    final firstWeek =
        plan == null || plan.weeks.isEmpty ? null : plan.weeks.first;
    final firstSession = firstWeek == null || firstWeek.sessions.isEmpty
        ? null
        : firstWeek.sessions.first;
    final firstSlot = firstSession == null || firstSession.slots.isEmpty
        ? null
        : firstSession.slots.first;
    if (plan == null || firstWeek == null || firstSlot == null) {
      Navigator.of(context).pop(true);
      return;
    }

    final definition = lookupExerciseDefinition(firstSlot.exerciseId);
    if (definition == null) {
      Navigator.of(context).pop(true);
      return;
    }

    Navigator.of(context).pushReplacementNamed(
      '/exercise',
      arguments: ExerciseLaunchArgs(
        definition: definition,
        catalogExerciseId: firstSlot.exerciseId,
        prescription: firstSlot.volume,
        recommendationId: plan.recommendationId,
        weekNumber: firstWeek.weekNumber,
        slotName: firstSlot.slotName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: switch (_step) {
              _RetestStep.intro => _RetestIntro(
                  busy: _busy,
                  error: _error,
                  onStart: _startRetest,
                ),
              _RetestStep.result => _RetestResultView(
                  submitted: _submitted!,
                  busy: _busy,
                  error: _error,
                  onAccept: _acceptSuggestedLevel,
                  onDecline: _declineSuggestedLevel,
                  onContinue: _continueWithSameLevel,
                ),
              _RetestStep.finalChoice => _NewPlanReadyView(
                  onStartToday: _startFirstSessionToday,
                  onTomorrow: () => Navigator.of(context).pop(true),
                ),
            },
          ),
        ),
      ),
    );
  }
}

class _RetestIntro extends StatelessWidget {
  const _RetestIntro({
    required this.busy,
    required this.error,
    required this.onStart,
  });

  final bool busy;
  final String? error;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final r = Responsive.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Spacer(),
        _Eyebrow('HOÀN THÀNH 7 TUẦN'),
        const SizedBox(height: 18),
        Text(
          'Bạn đã đi hết kế hoạch này.',
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: r.sp(38),
            fontWeight: FontWeight.w800,
            height: 1.02,
            color: c.ink,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Hãy kiểm tra tiến độ trong vài phút để Vika tạo lộ trình tiếp theo đúng sức hơn.',
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: r.sp(15),
            fontWeight: FontWeight.w600,
            height: 1.5,
            color: c.inkSoft,
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 18),
          _ErrorText(error!),
        ],
        const Spacer(),
        _PrimaryButton(
          label: busy ? 'Đang chuẩn bị' : 'Bắt đầu kiểm tra',
          onPressed: busy ? null : onStart,
        ),
      ],
    );
  }
}

class _RetestResultView extends StatelessWidget {
  const _RetestResultView({
    required this.submitted,
    required this.busy,
    required this.error,
    required this.onAccept,
    required this.onDecline,
    required this.onContinue,
  });

  final SubmittedFitnessRetest submitted;
  final bool busy;
  final String? error;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final changed = submitted.suggestion.shouldPromptUser;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Spacer(),
        _Eyebrow('KẾT QUẢ'),
        const SizedBox(height: 22),
        Row(
          children: [
            _LevelColumn(
              label: 'Hiện tại',
              level: submitted.suggestion.previousLevel,
            ),
            Container(width: 1, height: 68, color: c.border),
            _LevelColumn(
              label: changed ? 'Gợi ý mới' : 'Giữ nguyên',
              level: submitted.suggestion.suggestedLevel,
              highlighted: changed,
            ),
          ],
        ),
        const SizedBox(height: 26),
        Text(
          changed
              ? 'Vika thấy bạn đã sẵn sàng đổi level. Bạn vẫn là người quyết định.'
              : 'Bạn đang đúng level. Kế hoạch mới đang được tạo theo nhịp hiện tại.',
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            height: 1.45,
            color: c.ink,
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 18),
          _ErrorText(error!),
        ],
        const Spacer(),
        if (changed) ...[
          _PrimaryButton(
            label: busy ? 'Đang tạo kế hoạch' : 'Đồng ý đổi level',
            onPressed: busy ? null : onAccept,
          ),
          const SizedBox(height: 10),
          _SecondaryButton(
            label: 'Giữ level cũ',
            onPressed: busy ? null : onDecline,
          ),
        ] else
          _PrimaryButton(
            label: busy ? 'Đang tạo kế hoạch' : 'Tạo kế hoạch mới',
            onPressed: busy ? null : onContinue,
          ),
      ],
    );
  }
}

class _NewPlanReadyView extends StatelessWidget {
  const _NewPlanReadyView({
    required this.onStartToday,
    required this.onTomorrow,
  });

  final VoidCallback onStartToday;
  final VoidCallback onTomorrow;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final r = Responsive.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Spacer(),
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(color: c.yellow, shape: BoxShape.circle),
          child: Icon(Icons.check_rounded, color: c.yellowInk),
        ),
        const SizedBox(height: 24),
        Text(
          'Kế hoạch mới đã sẵn sàng.',
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: r.sp(36),
            fontWeight: FontWeight.w800,
            height: 1.04,
            color: c.ink,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Bạn có thể tập buổi đầu hôm nay, hoặc để cơ thể nghỉ và bắt đầu vào ngày mai.',
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.5,
            color: c.inkSoft,
          ),
        ),
        const Spacer(),
        _PrimaryButton(label: 'Có, tập luôn', onPressed: onStartToday),
        const SizedBox(height: 10),
        _SecondaryButton(label: 'Để mai', onPressed: onTomorrow),
      ],
    );
  }
}

class _VariantUnlockDialog extends StatelessWidget {
  const _VariantUnlockDialog({required this.notices});

  final List<VariantUnlockNotice> notices;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Dialog(
      backgroundColor: c.bg,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Eyebrow('MỞ KHÓA BÀI MỚI'),
            const SizedBox(height: 14),
            Text(
              'Bạn đã sẵn sàng cho bài khó hơn.',
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 24,
                fontWeight: FontWeight.w800,
                height: 1.1,
                color: c.ink,
              ),
            ),
            const SizedBox(height: 16),
            for (final notice in notices)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  '${notice.unlockedExerciseName} thay cho ${notice.exerciseName}',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    color: c.inkSoft,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            _PrimaryButton(
              label: 'Xem kế hoạch mới',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelColumn extends StatelessWidget {
  const _LevelColumn({
    required this.label,
    required this.level,
    this.highlighted = false,
  });

  final String label;
  final String level;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: c.inkSoft,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _levelLabel(level),
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: highlighted ? c.yellow : c.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'BeVietnamPro',
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.8,
        color: c.yellow,
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'BeVietnamPro',
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: c.attention,
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: c.yellow,
          foregroundColor: c.yellowInk,
          disabledBackgroundColor: c.border,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'BeVietnamPro',
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.ink,
          side: BorderSide(color: c.borderDark),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'BeVietnamPro',
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

enum _RetestStep { intro, result, finalChoice }

String _levelLabel(String level) {
  return switch (level) {
    'advanced' => 'Nâng cao',
    'intermediate' => 'Trung cấp',
    _ => 'Cơ bản',
  };
}
