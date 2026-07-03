// ExerciseIntroPage — v3 (engineering spec edition).
//
// The intro reads like a *spec sheet* for the exercise, not a sales
// page. Sections, in order of importance to a user who wants to get
// started fast:
//
//   ▲ STAGE HERO — name + difficulty + 16:9 video card
//   1. CHUẨN BỊ — setup (moved up; first thing they read)
//   2. AI THEO DÕI — anatomy diagram + per-metric config card list
//      with explicit thresholds + adaptive notes
//   3. MỤC TIÊU BUỔI NÀY — session targets (sets / reps / rest / total)
//   ▼ STICKY CTA DOCK — yellow "Bắt đầu tập" pill
//
// Each metric in the config list shows:
//   • Number that matches the body marker
//   • Metric name (uppercase, engineering)
//   • Threshold value (italic with units)
//   • Range bar showing the safe zone
//   • Adaptive note explaining how Vika personalizes it
//
// Coach-quote + editorial closer from v2 are removed — they read as
// "selling" and add length the user explicitly didn't want.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../interpreter/interpreter_base.dart';
import '../../theme/app_colors.dart';
import '../../theme/vf_theme.dart';
import '../../widgets/exercise/auto_start_countdown.dart';
import '../../widgets/exercise/looping_asset_video.dart';
import '../../widgets/exercise/previous_exercise_rating_dialog.dart';
import 'widgets/metric_diagrams.dart';
import 'widgets/skeleton_annotation.dart';

class ExerciseIntroBadge {
  const ExerciseIntroBadge({
    required this.title,
    required this.value,
    required this.color,
  });
  final String title;
  final String value;
  final Color color;
}

class ExerciseIntroPage extends StatefulWidget {
  const ExerciseIntroPage({
    super.key,
    required this.title,
    required this.difficulty,
    required this.totalSets,
    required this.repsPerSet,
    required this.muscles,
    required this.tips,
    required this.badges,
    required this.callouts,
    required this.coachNote,
    required this.onStart,
    required this.onBack,
    this.onReviewerDemoHold,
    this.videoAsset,
    this.restSeconds = 45,
    this.subtitle,
    this.posture = SkeletonPosture.standing,
    this.onWatchVideo,
    this.targetLabel = 'REP/HIỆP',
    this.secondsPerUnit = 4,
    this.sessionProgressLabel,
    this.isContinuation = false,
    this.previousExerciseName,
    this.previousExerciseFormScore,
    this.previousExerciseIssueQuestion,
    this.onPreviousDifficulty,
  });

  final String title;
  final String difficulty;
  final int totalSets;
  final int repsPerSet;
  final List<String> muscles;
  final List<String> tips;

  /// Temporal metrics — no anatomy anchor (e.g. descent tempo, hold).
  final List<ExerciseIntroBadge> badges;

  /// Anatomical metrics — anchored to body positions.
  final List<SkeletonCallout> callouts;
  final String? videoAsset;

  /// Retained for backward compat. Not rendered in v3 — the page is
  /// for specs, not selling.
  final String coachNote;

  final VoidCallback onStart;
  final VoidCallback onBack;

  /// When non-null, a deliberate 5-second press-and-hold on the
  /// "Bắt đầu tập" pill fires this instead of starting the workout —
  /// used to surface the reviewer tracking-demo overlay. A quick tap
  /// (sub-5s press) still starts normally. Null = no long-press wiring.
  final VoidCallback? onReviewerDemoHold;

  final int restSeconds;
  final String? subtitle;
  final SkeletonPosture posture;
  final VoidCallback? onWatchVideo;
  final String targetLabel;
  final double secondsPerUnit;
  final String? sessionProgressLabel;
  final bool isContinuation;

  /// When non-null, an "đánh giá bài vừa rồi" block surfaces at the top
  /// of the body. Filled in only for exercises after the first in a
  /// multi-exercise sequence. The sticky CTA stays gated (locked + grey)
  /// until the user picks a difficulty.
  final String? previousExerciseName;
  final int? previousExerciseFormScore;

  /// Optional detected form issue from the previous exercise. When present,
  /// the rating popup adds a short, optional issue-confirm section.
  final DetectedEvidence? previousExerciseIssueQuestion;
  final ValueChanged<String>? onPreviousDifficulty;

  @override
  State<ExerciseIntroPage> createState() => _ExerciseIntroPageState();
}

class _ExerciseIntroPageState extends State<ExerciseIntroPage> {
  String? _selectedPreviousDifficulty;
  bool _ratingPopupHandled = false;

  @override
  void initState() {
    super.initState();
    // For continuation slots, surface the rating popup as soon as the
    // intro lands. The popup is barrier-non-dismissible — the user can
    // only close it by selecting a rating. After that, the auto-start
    // countdown CTA at the bottom takes over.
    if (widget.previousExerciseName != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _promptRating());
    }
  }

  Future<void> _promptRating() async {
    if (!mounted || _ratingPopupHandled) return;
    _ratingPopupHandled = true;
    final result = await showPreviousExerciseRatingDialog(
      context,
      exerciseName: widget.previousExerciseName!,
      formScore: widget.previousExerciseFormScore,
      issueQuestion: widget.previousExerciseIssueQuestion,
    );
    if (!mounted) return;
    setState(() => _selectedPreviousDifficulty = result);
    widget.onPreviousDifficulty?.call(result);
  }

  /// Combine callouts (anatomy) + badges (temporal) into unified
  /// metric configs. Anatomical ones are numbered first.
  List<_MetricConfig> get _metrics {
    final list = <_MetricConfig>[];
    for (var i = 0; i < widget.callouts.length; i++) {
      final c = widget.callouts[i];
      list.add(_MetricConfig(
        number: i + 1,
        name: c.title,
        value: c.value,
        anchor: c.anchor,
        tempoIcon: null,
        kind: inferMetricKind(c.value),
        adaptation: _defaultAdaptationFor(c.title),
        description: _defaultDescriptionFor(c.title),
      ));
    }
    for (var i = 0; i < widget.badges.length; i++) {
      final b = widget.badges[i];
      list.add(_MetricConfig(
        number: widget.callouts.length + i + 1,
        name: b.title,
        value: b.value,
        anchor: null,
        tempoIcon: _tempoIconFor(b.title),
        kind: MetricKind.time,
        adaptation: _defaultAdaptationFor(b.title),
        description: _defaultDescriptionFor(b.title),
      ));
    }
    return list;
  }

  /// Plain-Vietnamese one-liner: what the metric measures + why it
  /// matters. Surfaces above the target value so users understand the
  /// spec before they see the numbers.
  ///
  /// Keyed by the exact metric title authored per exercise in
  /// `exercise_experience_screen.dart`, so each exercise gets copy that
  /// is actually true for *that* movement (a push-up's "Thân người" is
  /// about plank-body sag, not a squat's trunk lean). A small set of
  /// substring fallbacks keeps any future metric from reading blank.
  String _defaultDescriptionFor(String name) {
    const byTitle = <String, String>{
      // ── Squat / Lunge ──
      'Lưng nghiêng':
          'Đo độ nghiêng của thân trên so với phương dọc. Vừa đủ — không gập quá (hại lưng dưới) cũng không quá thẳng (mất lực đùi).',
      'Độ sâu gối':
          'Đo góc gập đầu gối khi xuống đáy. Đủ sâu để đùi và mông làm việc, nhưng vẫn trong vùng an toàn cho khớp gối.',
      'Gót chân':
          'Đo gót chân có rời sàn không. Gót nhấc khiến trọng tâm dồn lên mũi chân và đầu gối — Vika nhắc bạn ấn gót xuống.',
      'Core & hông':
          'Đo hông và core có giữ vững khi bước xuống không. Giữ chắc giúp lực dồn vào chân thay vì xô lệch sang lưng dưới.',
      // ── Push-up ──
      'Thân người':
          'Đo thân người có thẳng một đường từ vai đến gót không. Võng hông hay chổng mông đều làm mất tải và dễ đau lưng.',
      'Độ sâu khuỷu':
          'Đo góc gập khuỷu tay khi hạ xuống. Đủ sâu để ngực và tay sau làm việc trọn biên độ trong mỗi nhịp.',
      'Khoá khuỷu':
          'Đo tay có duỗi thẳng khi đẩy lên hết không. Khoá đủ ở trên cùng để hoàn thành trọn vẹn một rep.',
      // ── Plank ──
      'Đầu cổ':
          'Đo đầu và cổ có thẳng hàng với cột sống không. Ngẩng hay cúi cổ tạo căng thừa khi giữ tư thế.',
      'Đầu gối':
          'Đo chân có duỗi thẳng khi giữ plank không. Gối cong làm tụt hông và giảm hiệu quả lên core.',
      // ── Jumping jack ──
      'Tay qua đầu':
          'Đo tay có vươn đủ cao qua đầu trong pha mở không. Tay thấp làm hụt biên độ và loãng nhịp cardio.',
      'Khuỷu tay':
          'Đo tay có duỗi thẳng khi vung lên không. Khuỷu gập làm rep trông vội và thiếu trọn vẹn.',
      'Chân rộng':
          'Đo hai chân có mở đủ rộng so với vai trong pha nhảy không. Mở đủ rộng để rep trọn vẹn, không chỉ vung tay.',
      // ── Glute bridge ──
      'Nâng hông':
          'Đo hông có nâng đủ cao không. Mục tiêu là siết mông ở đỉnh, không ưỡn lưng để bù.',
      'Góc gối':
          'Đo góc gối có giữ ổn định khi nâng hông không. Giữ đúng góc giúp lực dồn vào mông thay vì đùi sau.',
      // ── Curl-up ──
      'Biên độ cuộn':
          'Đo thân trên cuộn lên bao nhiêu so với sàn. Curl-up cần biên độ ngắn, vừa đủ để bảo vệ cột sống thắt lưng.',
      'Gối giữ cong':
          'Đo một chân có giữ gối cong suốt rep không. Duỗi thẳng chân kéo lực xuống lưng dưới thay vì vào bụng.',
      'Không kéo cổ':
          'Đo cổ có bị giật về trước không. Kéo cổ bằng tay tạo lực sai và mỏi gáy thay vì làm việc cơ bụng.',
      // ── Temporal badges ──
      'Nhịp xuống':
          'Đo thời gian hạ người xuống đáy. Hạ chậm và có kiểm soát giúp cơ chịu tải lâu hơn và Vika đo chính xác hơn.',
      'Giữ đáy':
          'Đo thời gian dừng ở đáy. Một nhịp dừng ngắn để Vika xác nhận độ sâu trước khi bạn đẩy lên.',
      'Nhịp rep':
          'Đo nhịp mỗi lần nhảy. Giữ nhịp đều giúp duy trì cường độ cardio mà vẫn đúng form.',
      'Thời gian giữ':
          'Đo thời gian giữ mỗi lần plank. Giữ đủ lâu để core chịu tải — Vika đếm khi tư thế còn chuẩn.',
      'Hạ hông':
          'Đo tốc độ hạ hông so với khi nâng. Hạ chậm hơn giúp mông kiểm soát chuyển động thay vì buông rơi.',
      // ── Generic fallback metrics ──
      'Tư thế thân trên':
          'Vika theo dõi tư thế thân trên suốt bài để giữ bạn ổn định và đúng dáng.',
      'Biên độ chính':
          'Vika theo dõi biên độ chuyển động chính của bài để bạn tập đủ sâu và trọn vẹn mỗi nhịp.',
      'Nhịp chuyển động':
          'Vika theo dõi nhịp chuyển động để bạn giữ đều và kiểm soát, không làm quá nhanh.',
      'Nhịp tập':
          'Vika theo dõi nhịp tập để bạn giữ đều và ổn định trong suốt bài.',
      'Kiểm soát':
          'Vika theo dõi mức kiểm soát chuyển động để mỗi nhịp đều chắc và an toàn.',
    };
    final exact = byTitle[name];
    if (exact != null) return exact;

    // Substring fallbacks — keep any unmapped future metric readable.
    final n = name.toLowerCase();
    if (n.contains('cổ')) {
      return 'Đo đầu và cổ có giữ thẳng hàng với cột sống không.';
    }
    if (n.contains('hông')) {
      return 'Đo chuyển động của hông để giữ lực đúng nhóm cơ.';
    }
    if (n.contains('gối') || n.contains('độ sâu')) {
      return 'Đo góc gối trong chuyển động để bạn tập đủ sâu và an toàn cho khớp.';
    }
    if (n.contains('lưng') || n.contains('thân')) {
      return 'Đo tư thế thân người để giữ cột sống an toàn và lực đúng chỗ.';
    }
    if (n.contains('nhịp') || n.contains('giữ')) {
      return 'Đo nhịp và thời gian của chuyển động để bạn giữ kiểm soát.';
    }
    return 'Vika đo điểm này theo thời gian thực và nhắc khi bạn cần chỉnh.';
  }

  /// Returns a realistic session-over-session adaptation per metric
  /// name. Each metric tells a small story about *how* Vika adapted to
  /// the user's previous session — that's the "real coach" feel.
  ///
  /// Curators / the engine will eventually supply this from the
  /// recommendation log; until then these defaults read honestly per
  /// metric so the page shows a varied set of changes (some looser,
  /// some tighter, some unchanged).
  _Adaptation _defaultAdaptationFor(String name) {
    final n = name.toLowerCase();
    if (n.contains('độ sâu') || n.contains('gối')) {
      return const _Adaptation(
        direction: _AdaptationDirection.looser,
        delta: '5°',
        previousValue: '85° — 105°',
        reason: 'Vika nới vì bạn fail metric này 3 lần ở buổi trước.',
      );
    }
    if (n.contains('lưng') || n.contains('thân')) {
      return const _Adaptation(
        direction: _AdaptationDirection.unchanged,
        reason: 'Bạn đang ổn định trong vùng tối ưu — Vika giữ nguyên.',
      );
    }
    if (n.contains('gót') || n.contains('chân')) {
      return const _Adaptation(
        direction: _AdaptationDirection.tighter,
        delta: '2%',
        previousValue: '< 7%',
        reason: 'Bạn đã chạm chuẩn liên tục 5 buổi — Vika đẩy thêm.',
      );
    }
    if (n.contains('nhịp') || n.contains('xuống') || n.contains('tempo')) {
      return const _Adaptation(
        direction: _AdaptationDirection.looser,
        delta: '0.5s',
        previousValue: '≥ 3.0s',
        reason: 'Vika giảm vì bạn fail nhịp xuống 4 lần ở buổi trước.',
      );
    }
    if (n.contains('giữ') || n.contains('đáy') || n.contains('hold')) {
      return const _Adaptation(
        direction: _AdaptationDirection.unchanged,
        reason: 'Bạn đang chạm chuẩn — Vika giữ nguyên.',
      );
    }
    return const _Adaptation(
      direction: _AdaptationDirection.baseline,
      reason: 'Mặc định cho người mới — sẽ cá nhân hoá sau buổi đầu.',
    );
  }

  IconData _tempoIconFor(String name) {
    final n = name.toLowerCase();
    if (n.contains('giữ') || n.contains('đáy') || n.contains('hold')) {
      return Icons.hourglass_bottom_rounded;
    }
    return Icons.south_rounded; // descent / tempo down
  }

  int get _difficultyDots {
    final d = widget.difficulty.toLowerCase();
    if (d.contains('khó') || d.contains('cao')) return 3;
    if (d.contains('trung') || d.contains('vừa')) return 2;
    return 1;
  }

  String get _estimatedMinutes {
    final workSeconds =
        widget.totalSets * widget.repsPerSet * widget.secondsPerUnit;
    final restSecondsTotal = (widget.totalSets - 1) * widget.restSeconds;
    final total = workSeconds + restSecondsTotal;
    final minutes = (total / 60).ceil();
    return '~$minutes phút';
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    // Captured BEFORE the `MediaQuery.removePadding` wrap below.
    // The hero uses this so its top bar (back / save / share) clears
    // the status bar even though the dark gradient itself bleeds all
    // the way to the top edge.
    final mq = MediaQuery.of(context);
    final statusBarInset = mq.viewPadding.top;
    // Clamp accessibility text scaling so the giant italic hero title
    // and tabular session-target numerals can't push themselves off the
    // page on devices with maxed-out system text.
    final clampedScaler = mq.textScaler.clamp(
      minScaleFactor: 0.92,
      maxScaleFactor: 1.12,
    );

    return MediaQuery(
      data: mq.copyWith(textScaler: clampedScaler),
      child: Scaffold(
        backgroundColor: c.bg,
        body: Stack(
          children: [
            MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Hero is rendered for EVERY exercise, including
                    // continuation slots. Earlier we collapsed continuation
                    // slots to a compact header, but the user wanted the
                    // full hero presence to anchor the page consistently.
                    _StageHero(
                      statusBarInset: statusBarInset,
                      title: widget.title,
                      subtitle: widget.subtitle ??
                          'Phân tích tư thế · $_estimatedMinutes',
                      muscles: widget.muscles,
                      difficulty: widget.difficulty,
                      difficultyDots: _difficultyDots,
                      videoAsset: widget.videoAsset,
                      sessionProgressLabel: widget.sessionProgressLabel,
                      onBack: widget.onBack,
                      onWatchVideo: widget.onWatchVideo,
                    ),
                    const SizedBox(height: 24),

                    // Continuation rating is collected via the forced
                    // popup launched in `initState`, not inline on the page
                    // — so we drop directly into CHUẨN BỊ here.

                    // 1. CHUẨN BỊ — moved up so the people-who-just-want-
                    // to-start crowd see setup first.
                    _SectionHeader(
                      eyebrow: 'CHUẨN BỊ',
                      meta: '${widget.tips.length} BƯỚC',
                      intro:
                          'Vài giây để dựng camera đúng. AI cần thấy rõ dáng của bạn.',
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _SetupChecklist(tips: widget.tips),
                    ),
                    const SizedBox(height: 40),

                    // 2. AI THEO DÕI — diagram + per-metric config list.
                    _SectionHeader(
                      eyebrow: 'AI THEO DÕI',
                      meta: '${_metrics.length} ĐIỂM ĐO',
                      intro:
                          'Vuốt qua từng điểm Vika chấm theo thời gian thực để giữ form chuẩn từ rep đầu.',
                    ),
                    const SizedBox(height: 16),
                    // Full-bleed (no horizontal padding) so the neighbouring
                    // card can peek past the screen edge — the cue that the
                    // metrics are a horizontal, swipeable gallery.
                    _MetricPager(metrics: _metrics),
                    const SizedBox(height: 40),

                    // 3. MỤC TIÊU BUỔI NÀY — session targets.
                    _SectionHeader(
                      eyebrow: 'MỤC TIÊU BUỔI NÀY',
                      intro:
                          'Con số bạn cần đẩy. AI sẽ giữ rep mục tiêu khi form chuẩn.',
                    ),
                    const SizedBox(height: 14),
                    _SessionTargetBand(
                      sets: widget.totalSets,
                      repsPerSet: widget.repsPerSet,
                      restSeconds: widget.restSeconds,
                      estimatedMinutes: _estimatedMinutes,
                      targetLabel: widget.targetLabel,
                    ),

                    // Bottom-of-page safe space for the sticky dock.
                    // Tall enough for the notice line + button + insets so
                    // the last section never sits underneath the dock.
                    SizedBox(
                      height: 168 + MediaQuery.viewPaddingOf(context).bottom,
                    ),
                  ],
                ),
              ),
            ),

            // Sticky CTA dock:
            //   • First exercise / no prev rating needed → classic
            //     "Bắt đầu tập" pill, force-press model.
            //   • Continuation slot, rating already collected via popup →
            //     auto-countdown CTA (30s) with start-now + extend.
            //   • Continuation slot, popup still up (rating null) → nothing
            //     visible at the bottom (the popup itself blocks everything).
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomDock(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomDock(BuildContext context) {
    final isContinuation = widget.previousExerciseName != null;
    if (isContinuation && _selectedPreviousDifficulty == null) {
      // Popup is up — leave the dock empty so the page reads cleanly
      // behind the dialog.
      return const SizedBox.shrink();
    }
    if (isContinuation) {
      return AutoStartCountdown(
        totalSeconds: 30,
        onStartNow: widget.onStart,
      );
    }
    return _StickyCtaDock(
      onStart: widget.onStart,
      onWatchVideo: widget.onWatchVideo,
      onReviewerDemoHold: widget.onReviewerDemoHold,
      showReadNotice: true,
    );
  }
}

/// Internal: a unified metric config used by both the diagram and the
/// config list.
class _MetricConfig {
  const _MetricConfig({
    required this.number,
    required this.name,
    required this.value,
    required this.anchor,
    required this.tempoIcon,
    required this.kind,
    required this.adaptation,
    required this.description,
  });
  final int number;
  final String name;
  final String value;
  final Offset? anchor;
  final IconData? tempoIcon;
  final MetricKind kind;

  /// Plain-Vietnamese one-liner explaining *what* this metric measures
  /// and *why* it matters. Surfaces above the threshold value so the
  /// user understands the spec, not just sees the numbers.
  final String description;

  /// How Vika's threshold for this metric changed since the user's
  /// previous session. The whole "real coach that adapts" promise
  /// surfaces through this field — it shows the *direction* of the
  /// change (looser / tighter / unchanged / first session), the
  /// numeric delta, and a one-line reason.
  final _Adaptation adaptation;
}

/// Direction of Vika's session-over-session threshold change.
enum _AdaptationDirection {
  /// Threshold relaxed since last session — usually because the user
  /// failed this metric repeatedly.
  looser,

  /// Threshold tightened since last session — user is hitting the
  /// metric consistently so Vika pushes them further.
  tighter,

  /// No change — user is in the optimal zone.
  unchanged,

  /// No previous baseline — first time the user is doing this exercise.
  baseline,
}

class _Adaptation {
  const _Adaptation({
    required this.direction,
    required this.reason,
    this.delta,
    this.previousValue,
  });

  final _AdaptationDirection direction;

  /// e.g. "5°", "0.5s", "2%". Optional — null for unchanged / baseline.
  final String? delta;

  /// e.g. "85° — 105°" — the previous session's threshold. Optional.
  final String? previousValue;

  /// Italic one-liner explaining *why* Vika made this change.
  final String reason;

  String get chipLabel {
    return switch (direction) {
      _AdaptationDirection.looser => delta != null ? 'Đã nới $delta' : 'Đã nới',
      _AdaptationDirection.tighter =>
        delta != null ? 'Đã thắt $delta' : 'Đã thắt',
      _AdaptationDirection.unchanged => 'Giữ nguyên',
      _AdaptationDirection.baseline => 'Buổi đầu',
    };
  }

  IconData get chipIcon {
    return switch (direction) {
      _AdaptationDirection.looser => Icons.south_east_rounded,
      _AdaptationDirection.tighter => Icons.north_east_rounded,
      _AdaptationDirection.unchanged => Icons.drag_handle_rounded,
      _AdaptationDirection.baseline => Icons.fiber_manual_record_rounded,
    };
  }
}

class _SessionProgressThread extends StatelessWidget {
  const _SessionProgressThread({
    required this.label,
    this.dark = false,
  });

  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: c.yellow,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            color: dark ? c.invInkSoft : c.inkSoft,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// STAGE HERO — unchanged from v2 (the user explicitly said keep it).
// ═══════════════════════════════════════════════════════════════

class _StageHero extends StatelessWidget {
  const _StageHero({
    required this.statusBarInset,
    required this.title,
    required this.subtitle,
    required this.muscles,
    required this.difficulty,
    required this.difficultyDots,
    required this.onBack,
    this.videoAsset,
    this.sessionProgressLabel,
    this.onWatchVideo,
  });

  /// Captured by the parent BEFORE `MediaQuery.removePadding(removeTop)`
  /// wraps the page. Reading `MediaQuery.viewPaddingOf(context).top` in
  /// here returns 0 (the parent removed it so the dark gradient could
  /// bleed to the top edge); we need the original status-bar height so
  /// the top-bar buttons clear it.
  final double statusBarInset;

  final String title;
  final String subtitle;
  final List<String> muscles;
  final String difficulty;
  final int difficultyDots;
  final String? videoAsset;
  final VoidCallback onBack;
  final String? sessionProgressLabel;
  final VoidCallback? onWatchVideo;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final topInset = statusBarInset;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(36),
      ),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: const Alignment(-0.7, -1),
              end: const Alignment(0.7, 1),
              colors: [c.bgInverse, c.bgInverseHi],
            ),
            boxShadow: [
              BoxShadow(
                color: c.ink.withValues(alpha: 0.22),
                blurRadius: 48,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -130,
                right: -110,
                child: IgnorePointer(
                  child: SizedBox(
                    width: 420,
                    height: 420,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            c.yellow.withValues(alpha: 0.22),
                            c.yellow.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -180,
                left: -140,
                child: IgnorePointer(
                  child: SizedBox(
                    width: 440,
                    height: 380,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            Color(0x33CD7C45),
                            Color(0x00CD7C45),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: topInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TopBar(onBack: onBack),
                    if (sessionProgressLabel != null) ...[
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _SessionProgressThread(
                          label: sessionProgressLabel!,
                          dark: true,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _EyebrowChip(muscles: muscles),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '$title.',
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(
                                  fontFamily: 'BeVietnamPro',
                                  fontSize: 56,
                                  fontWeight: FontWeight.w800,
                                  fontStyle: FontStyle.italic,
                                  letterSpacing: -2.8,
                                  height: 0.95,
                                  color: c.invInk,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Container(
                                width: 24,
                                height: 2,
                                decoration: BoxDecoration(
                                  color: c.yellow,
                                  borderRadius: BorderRadius.circular(1),
                                  boxShadow: [
                                    BoxShadow(
                                      color: c.yellow.withValues(alpha: 0.5),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'BeVietnamPro',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    fontStyle: FontStyle.italic,
                                    height: 1.45,
                                    color: c.invInkSoft,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _DifficultyMeter(
                            label: difficulty,
                            dots: difficultyDots,
                          ),
                          const SizedBox(height: 22),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      child: _VideoCard(
                        asset: videoAsset,
                        onTap: onWatchVideo,
                      ),
                    ),
                    const SizedBox(height: 26),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onBack,
  });
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: Row(
        children: [
          _CircleButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Quay lại',
            onTap: onBack,
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _CircleButton extends StatefulWidget {
  const _CircleButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  State<_CircleButton> createState() => _CircleButtonState();
}

class _CircleButtonState extends State<_CircleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final bg = Colors.white.withValues(alpha: 0.06);
    final borderColor = Colors.white.withValues(alpha: 0.18);

    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap?.call();
        },
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 1),
            ),
            alignment: Alignment.center,
            child: Icon(widget.icon, size: 18, color: c.invInk),
          ),
        ),
      ),
    );
  }
}

class _EyebrowChip extends StatelessWidget {
  const _EyebrowChip({required this.muscles});
  final List<String> muscles;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final label = 'BÀI TẬP · ${muscles.join(' · ').toUpperCase()}';
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
      decoration: BoxDecoration(
        color: c.yellow.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: c.yellow.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: c.yellow,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: c.yellow, blurRadius: 4)],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
                color: c.yellow,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DifficultyMeter extends StatelessWidget {
  const _DifficultyMeter({required this.label, required this.dots});
  final String label;
  final int dots;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'ĐỘ KHÓ',
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
            color: c.invInkSoft.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 13,
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
            letterSpacing: -0.3,
            color: c.invInk,
          ),
        ),
        const SizedBox(width: 12),
        Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i < dots
                      ? c.yellow
                      : c.invInkSoft.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  boxShadow: i < dots
                      ? [BoxShadow(color: c.yellow, blurRadius: 5)]
                      : null,
                ),
              ),
              if (i < 2) const SizedBox(width: 5),
            ],
          ],
        ),
      ],
    );
  }
}

class _VideoCard extends StatefulWidget {
  const _VideoCard({this.asset, this.onTap});
  final String? asset;
  final VoidCallback? onTap;

  @override
  State<_VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<_VideoCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap?.call();
      },
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.99 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  c.ink.withValues(alpha: 0.55),
                  c.ink.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: c.invInk.withValues(alpha: 0.08),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: c.ink.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                if (widget.asset != null)
                  Positioned.fill(
                    child: LoopingAssetVideo(
                      asset: widget.asset!,
                      fit: BoxFit.contain,
                    ),
                  )
                else ...[
                  Positioned(
                    left: -40,
                    top: -30,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            c.yellow.withValues(alpha: 0.18),
                            c.yellow.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.yellow,
                        boxShadow: [
                          BoxShadow(
                            color: c.yellow.withValues(alpha: 0.5),
                            blurRadius: 22,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          size: 32,
                          color: c.yellowInk,
                        ),
                      ),
                    ),
                  ),
                ],
                if (widget.asset == null)
                  Positioned(
                    left: 16,
                    bottom: 14,
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: c.yellow,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'XEM HƯỚNG DẪN',
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.6,
                            color: c.invInk.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SECTION HEADER — matches the grammar across other tabs.
// ═══════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.eyebrow,
    this.meta,
    this.intro,
  });
  final String eyebrow;
  final String? meta;

  /// Italic editorial sub-head that explains what the section is for.
  /// Surfaces directly below the section rule.
  final String? intro;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 5,
                height: 22,
                decoration: BoxDecoration(
                  color: c.yellow,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                eyebrow,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                  color: c.ink,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: Container(height: 1, color: c.border)),
              if (meta != null) ...[
                const SizedBox(width: 14),
                Text(
                  meta!.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: c.inkFaint,
                    fontFeatures: VikaIvoryMain.tabularFigures,
                  ),
                ),
              ],
            ],
          ),
          if (intro != null) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 17),
              child: Text(
                intro!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                  height: 1.45,
                  color: c.inkSoft,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SETUP CHECKLIST — compact numbered tips, hairline-bordered rows.
// ═══════════════════════════════════════════════════════════════

class _SetupChecklist extends StatelessWidget {
  const _SetupChecklist({required this.tips});
  final List<String> tips;

  /// Detects an icon + short label from the tip's content. Falls back
  /// to a generic numbered medallion + "Bước N" label when nothing
  /// matches — so this scales to any exercise's setup instructions.
  (IconData, String) _iconAndLabelFor(String tip, int index) {
    final t = tip.toLowerCase();
    if (t.contains('camera') || t.contains('máy ảnh')) {
      return (Icons.photo_camera_outlined, 'CAMERA');
    }
    if (t.contains('ánh sáng') || t.contains('sáng')) {
      return (Icons.wb_sunny_outlined, 'ÁNH SÁNG');
    }
    if (t.contains('góc') ||
        t.contains('nghiêng') ||
        t.contains('quay') ||
        t.contains('hướng')) {
      return (Icons.rotate_right_rounded, 'GÓC NHÌN');
    }
    if (t.contains('khoảng cách') || t.contains('mét') || t.contains('m ')) {
      return (Icons.straighten_rounded, 'KHOẢNG CÁCH');
    }
    if (t.contains('mat') || t.contains('thảm') || t.contains('sàn')) {
      return (Icons.bed_outlined, 'SÀN');
    }
    return (Icons.check_circle_outline_rounded, 'BƯỚC ${index + 1}');
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.bgRaised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: c.ink.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            for (var i = 0; i < tips.length; i++) ...[
              _SetupRow(
                index: i,
                tip: tips[i],
                iconAndLabel: _iconAndLabelFor(tips[i], i),
              ),
              if (i < tips.length - 1)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: c.border,
                  indent: 64,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SetupRow extends StatelessWidget {
  const _SetupRow({
    required this.index,
    required this.tip,
    required this.iconAndLabel,
  });

  final int index;
  final String tip;
  final (IconData, String) iconAndLabel;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final (icon, label) = iconAndLabel;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Square icon medallion + tiny step number badge.
          SizedBox(
            width: 36,
            height: 36,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: c.yellowGhost,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: c.yellow.withValues(alpha: 0.4),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, size: 17, color: c.ink),
                  ),
                ),
                Positioned(
                  top: -5,
                  right: -5,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: c.ink,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.bgRaised, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      (index + 1).toString(),
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                        letterSpacing: -0.3,
                        height: 1.0,
                        color: c.yellow,
                        fontFeatures: VikaIvoryMain.tabularFigures,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                    color: c.inkFaint,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tip,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                    letterSpacing: -0.1,
                    color: c.ink,
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

// ═══════════════════════════════════════════════════════════════
// AI METRIC GALLERY — horizontal, swipeable deck of "instrument" cards.
//
// One metric per card. Replaces the old long vertical list: the user
// flicks sideways through each thing Vika watches, with the neighbour
// card peeking past the screen edge and a focus scale/dim on the active
// card. Page dots + a 0N/0M counter mark position.
// ═══════════════════════════════════════════════════════════════

class _MetricPager extends StatefulWidget {
  const _MetricPager({required this.metrics});

  final List<_MetricConfig> metrics;

  @override
  State<_MetricPager> createState() => _MetricPagerState();
}

class _MetricPagerState extends State<_MetricPager> {
  // <1 so the next card peeks; this is the swipeability cue.
  static const double _viewportFraction = 0.82;
  static const double _cardHeight = 392;

  late final PageController _controller =
      PageController(viewportFraction: _viewportFraction);
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  void _onScroll() {
    final p = _controller.page ?? 0;
    if (p != _page) setState(() => _page = p);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metrics = widget.metrics;
    return Column(
      children: [
        SizedBox(
          height: _cardHeight,
          child: PageView.builder(
            controller: _controller,
            itemCount: metrics.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, i) {
              // Distance of this card from the focused page, 0..1.
              final delta = (_page - i).abs().clamp(0.0, 1.0);
              final scale = 1 - delta * 0.06;
              final opacity = 1 - delta * 0.30;
              return Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  // showAdaptation stays false until real per-user
                  // thresholds are wired (see _MetricCard.showAdaptation).
                  child: _MetricCard(metric: metrics[i], showAdaptation: false),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _MetricDots(count: metrics.length, page: _page),
              const Spacer(),
              Text(
                '${(_page.round() + 1).toString().padLeft(2, '0')}'
                ' / ${metrics.length.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 0.4,
                  color: VikaColors.of(context).inkFaint,
                  fontFeatures: VikaIvoryMain.tabularFigures,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Page-position dots — the active one stretches into a yellow pill.
class _MetricDots extends StatelessWidget {
  const _MetricDots({required this.count, required this.page});

  final int count;
  final double page;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final active = page.round();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOut,
            margin: const EdgeInsets.only(right: 5),
            width: i == active ? 20 : 6,
            height: 6,
            decoration: BoxDecoration(
              color:
                  i == active ? c.yellow : c.inkFaint.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(3),
              boxShadow: i == active
                  ? [
                      BoxShadow(
                          color: c.yellow.withValues(alpha: 0.5), blurRadius: 6)
                    ]
                  : null,
            ),
          ),
      ],
    );
  }
}

/// One metric, presented as a precision-instrument card: medallion +
/// Vietnamese kind label + name, a CAD-style gauge paired with its target
/// readout, and plain-language "what + why".
class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.metric,
    this.showAdaptation = false,
  });

  final _MetricConfig metric;

  /// Reserved. Real per-user threshold adaptation isn't wired yet, so the
  /// session-over-session delta is intentionally hidden — showing a
  /// "personalised" change while every threshold is hard-coded and equal
  /// for all users would be dishonest. Flip to true once the engine feeds
  /// real per-user thresholds; the display (`_AdaptationStrip`) is kept.
  final bool showAdaptation;

  String get _kindLabel {
    return switch (metric.kind) {
      MetricKind.angle => 'GÓC ĐO',
      MetricKind.time => 'NHỊP ĐỘ',
      MetricKind.position => 'KHOẢNG CÁCH',
    };
  }

  /// Numeric specs (85° — 105°, ≥ 3.0s) get the giant tabular treatment;
  /// soft phrase values (Giữ ổn định) read better at a calmer size.
  bool get _isNumericValue => RegExp(r'[0-9]').hasMatch(metric.value);

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.bgRaised,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: c.ink.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── HEADER: medallion · kind label · VIKA tag ──
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: c.yellow,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.ink, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: c.yellow.withValues(alpha: 0.32),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    metric.number.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      letterSpacing: -0.4,
                      height: 1.0,
                      color: c.yellowInk,
                      fontFeatures: VikaIvoryMain.tabularFigures,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Text(
                  _kindLabel,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                    color: c.inkFaint,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: c.yellow,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: c.yellow, blurRadius: 4)],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'VIKA ĐO',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    color: c.inkSoft,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── NAME — the headline of the card ──
            Text(
              metric.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 22,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
                letterSpacing: -0.7,
                height: 1.05,
                color: c.ink,
              ),
            ),
            const SizedBox(height: 20),

            // ── INSTRUMENT: gauge + target readout ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                MetricDiagram(
                  kind: metric.kind,
                  value: metric.value,
                  size: 104,
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'MỤC TIÊU FORM',
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                          color: c.inkFaint,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (_isNumericValue)
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            metric.value,
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              fontStyle: FontStyle.italic,
                              letterSpacing: -1.2,
                              height: 1.0,
                              color: c.ink,
                              fontFeatures: VikaIvoryMain.tabularFigures,
                            ),
                          ),
                        )
                      else
                        Text(
                          metric.value,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            fontStyle: FontStyle.italic,
                            letterSpacing: -0.4,
                            height: 1.1,
                            color: c.ink,
                          ),
                        ),
                      const SizedBox(height: 10),
                      Container(width: 22, height: 2, color: c.yellow),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(height: 1, color: c.border),
            const SizedBox(height: 16),

            // ── WHAT it measures + WHY it matters ──
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: c.yellow,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      metric.description,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                        letterSpacing: -0.1,
                        color: c.inkSoft,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Reserved per-user adaptation delta (hidden — see field doc).
            if (showAdaptation) ...[
              const SizedBox(height: 14),
              _AdaptationStrip(adaptation: metric.adaptation),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ADAPTATION STRIP — diff chip + previous-value + italic reason.
//
// The "Vika changes thresholds like a real coach" moment. Per metric,
// shows:
//   1. A colored pill with the direction + delta (e.g. "↘ Đã nới 5°")
//   2. A small "← Trước 85° — 105°" line (when previousValue is set)
//   3. An italic reason explaining WHY Vika made the change
//
// Colors:
//   • Looser   → yellow fill (Vika eased the threshold)
//   • Tighter  → ink fill, yellow accent (Vika pushed you harder)
//   • Unchanged → cream outline (stable)
//   • Baseline → cream outline (first session)
// ═══════════════════════════════════════════════════════════════

class _AdaptationStrip extends StatelessWidget {
  const _AdaptationStrip({required this.adaptation});
  final _Adaptation adaptation;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _AdaptationChip(adaptation: adaptation),
            if (adaptation.previousValue != null) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '← Trước  ${adaptation.previousValue}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -0.1,
                    color: c.inkFaint,
                    fontFeatures: VikaIvoryMain.tabularFigures,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          adaptation.reason,
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            fontStyle: FontStyle.italic,
            height: 1.45,
            letterSpacing: -0.1,
            color: c.inkFaint,
          ),
        ),
      ],
    );
  }
}

class _AdaptationChip extends StatelessWidget {
  const _AdaptationChip({required this.adaptation});
  final _Adaptation adaptation;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    // Direction-specific palette.
    final Color bg;
    final Color border;
    final Color iconColor;
    final Color textColor;
    final List<BoxShadow>? shadow;
    switch (adaptation.direction) {
      case _AdaptationDirection.looser:
        bg = c.yellow;
        border = c.yellow;
        iconColor = c.yellowInk;
        textColor = c.yellowInk;
        shadow = [
          BoxShadow(
            color: c.yellow.withValues(alpha: 0.36),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ];
        break;
      case _AdaptationDirection.tighter:
        bg = c.ink;
        border = c.ink;
        iconColor = c.yellow;
        textColor = c.invInk;
        shadow = [
          BoxShadow(
            color: c.ink.withValues(alpha: 0.22),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ];
        break;
      case _AdaptationDirection.unchanged:
      case _AdaptationDirection.baseline:
        bg = Colors.transparent;
        border = c.borderHi;
        iconColor = c.inkSoft;
        textColor = c.inkSoft;
        shadow = null;
        break;
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 11, 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 1.2),
        boxShadow: shadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(adaptation.chipIcon, size: 12, color: iconColor),
          const SizedBox(width: 5),
          Text(
            adaptation.chipLabel,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: textColor,
              fontFeatures: VikaIvoryMain.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SESSION TARGET BAND — editorial stat strip.
// ═══════════════════════════════════════════════════════════════

class _SessionTargetBand extends StatelessWidget {
  const _SessionTargetBand({
    required this.sets,
    required this.repsPerSet,
    required this.restSeconds,
    required this.estimatedMinutes,
    required this.targetLabel,
  });

  final int sets;
  final int repsPerSet;
  final int restSeconds;
  final String estimatedMinutes;
  final String targetLabel;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final stats = [
      ('$sets', 'HIỆP'),
      ('$repsPerSet', targetLabel),
      ('${restSeconds}s', 'NGHỈ'),
      (estimatedMinutes.replaceFirst('~', ''), 'TỔNG'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(2, 16, 2, 18),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: c.border),
            bottom: BorderSide(color: c.border),
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < stats.length; i++) ...[
                Expanded(
                  child: _TargetStatColumn(
                    value: stats[i].$1,
                    label: stats[i].$2,
                  ),
                ),
                if (i < stats.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Container(width: 1, color: c.border),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TargetStatColumn extends StatelessWidget {
  const _TargetStatColumn({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 32,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(
                value,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -1.4,
                  height: 1.0,
                  color: c.ink,
                  fontFeatures: VikaIvoryMain.tabularFigures,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(width: 14, height: 1, color: c.yellow),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: 1.2,
              color: c.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// STICKY CTA DOCK — pinned bottom action bar.
// ═══════════════════════════════════════════════════════════════

class _StickyCtaDock extends StatefulWidget {
  const _StickyCtaDock({
    required this.onStart,
    this.onWatchVideo,
    this.onReviewerDemoHold,
    this.showReadNotice = false,
  });

  final VoidCallback onStart;
  final VoidCallback? onWatchVideo;

  /// When non-null, a 5-second press-and-hold on the start pill fires
  /// this (reviewer tracking-demo) instead of starting; a sub-5s press
  /// still starts. Null = no long-press wiring (today's behaviour).
  final VoidCallback? onReviewerDemoHold;

  /// When true, a small editorial notice sits above the CTA telling
  /// the user to read the page before starting.
  final bool showReadNotice;

  @override
  State<_StickyCtaDock> createState() => _StickyCtaDockState();
}

class _StickyCtaDockState extends State<_StickyCtaDock> {
  bool _pressed = false;

  /// Armed on press-down when [_StickyCtaDock.onReviewerDemoHold] is wired;
  /// fires the demo at 5s. Cancelled by an early release.
  Timer? _holdTimer;
  bool _demoFired = false;

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  void _startHold() {
    if (widget.onReviewerDemoHold == null) return;
    _demoFired = false;
    _holdTimer?.cancel();
    _holdTimer = Timer(const Duration(seconds: 5), () {
      _holdTimer = null;
      _demoFired = true;
      if (mounted) setState(() => _pressed = false);
      widget.onReviewerDemoHold?.call();
    });
  }

  void _endHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
    if (_demoFired) {
      // The 5s demo already fired — swallow the release, don't start.
      _demoFired = false;
      return;
    }
    // A sub-5s press still starts the workout.
    HapticFeedback.mediumImpact();
    widget.onStart();
  }

  void _cancelHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _demoFired = false;
  }

  void _handlePressDown() {
    setState(() => _pressed = true);
    _startHold();
  }

  void _handlePressUp() {
    setState(() => _pressed = false);
    _endHold();
  }

  void _handlePressCancel() {
    setState(() => _pressed = false);
    _cancelHold();
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 14 + bottomInset),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            c.bg.withValues(alpha: 0),
            c.bg.withValues(alpha: 0.92),
            c.bg,
          ],
          stops: const [0.0, 0.4, 0.78],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showReadNotice) ...[
            const _ReadNotice(),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              if (widget.onWatchVideo != null) ...[
                _WatchVideoCircle(onTap: widget.onWatchVideo!),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: GestureDetector(
                  onTapDown: (_) => _handlePressDown(),
                  onTapUp: (_) => _handlePressUp(),
                  onTapCancel: _handlePressCancel,
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedScale(
                    scale: _pressed ? 0.98 : 1.0,
                    duration: const Duration(milliseconds: 120),
                    curve: Curves.easeOut,
                    child: Container(
                      height: 60,
                      padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
                      decoration: BoxDecoration(
                        color: c.yellow,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: c.yellow.withValues(alpha: 0.5),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                          BoxShadow(
                            color: c.ink.withValues(alpha: 0.15),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Bắt đầu tập',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'BeVietnamPro',
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                fontStyle: FontStyle.italic,
                                letterSpacing: -0.4,
                                color: c.yellowInk,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: c.ink,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.play_arrow_rounded,
                              size: 22,
                              color: c.yellow,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReadNotice extends StatelessWidget {
  const _ReadNotice();

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    const headline = 'Đọc kỹ trước — form chuẩn từ rep đầu tiên';
    const tagText = 'NHẮC NHẸ';
    final accent = c.yellow;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 14, 9),
      decoration: BoxDecoration(
        color: c.bgRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accent.withValues(alpha: 0.45),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: c.ink.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: accent.withValues(alpha: 0.6), blurRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: accent.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Text(
              tagText,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: accent,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              headline,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                fontStyle: FontStyle.italic,
                letterSpacing: -0.2,
                color: c.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WatchVideoCircle extends StatefulWidget {
  const _WatchVideoCircle({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_WatchVideoCircle> createState() => _WatchVideoCircleState();
}

class _WatchVideoCircleState extends State<_WatchVideoCircle> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: c.bgRaised,
            shape: BoxShape.circle,
            border: Border.all(color: c.borderHi, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: c.ink.withValues(alpha: 0.1),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.play_arrow_rounded,
            size: 22,
            color: c.ink,
          ),
        ),
      ),
    );
  }
}
