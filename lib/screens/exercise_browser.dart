// ExerciseBrowser — the Library / "Khám phá" sheet. Slides up from the
// bottom when the central FAB is tapped. Premium Ivory v1.
//
// Mirrors `BrowserSheet` in vika-main-app-ivory-v1.jsx. Layout:
//   • Drag handle (also the swipe-down dismiss target)
//   • SheetHeader (THƯ VIỆN · 100 BÀI · Khám phá. + tagline + close)
//   • SheetSearch
//   • AISpotlight (warm-dark hero — the prestige tier)
//   • Programs rail (horizontal scroll, 4 programs)
//   • Section header + 3 IntentCollections
//   • Section header + AllExercisesGrid (filter chips + dense rows)
//   • Editorial closer
//
// Interaction:
//   • Tap on dimmed scrim → close
//   • Tap on X button in header → close
//   • Swipe DOWN on the drag handle / header area → close (interactive
//     drag follows the finger; release past 100px or with downward
//     velocity ≥ 600 dismisses; otherwise snaps back)
//   • Tap on an exercise row in the all-exercises grid → resolves the
//     row's `definitionName` to a real `ExerciseDefinition` and pushes
//     /exercise via the `onSelectExercise` callback.

import 'package:flutter/material.dart';
import '../data/library_mock.dart';
import '../models/exercise_definition.dart';
import '../models/exercise_lookup.dart';
import '../theme/vf_theme.dart';
import '../widgets/library/ai_spotlight.dart';
import '../widgets/library/all_exercises_grid.dart';
import '../widgets/library/intent_collection.dart';
import '../widgets/library/programs_rail.dart';
import '../widgets/library/sheet_chrome.dart';
import '../widgets/plan/plan_typography.dart';
import '../theme/app_colors.dart';

class ExerciseBrowser extends StatefulWidget {
  const ExerciseBrowser({
    super.key,
    required this.bottomPadding,
    required this.onClose,
    required this.onSelectExercise,
  });

  final double bottomPadding;
  final VoidCallback onClose;
  final void Function(ExerciseDefinition) onSelectExercise;

  @override
  State<ExerciseBrowser> createState() => _ExerciseBrowserState();
}

class _ExerciseBrowserState extends State<ExerciseBrowser>
    with SingleTickerProviderStateMixin {
  // Live drag offset (>= 0 = pushed down). Resets to 0 when the user
  // releases without dismissing. Animated back via _snapBackController.
  double _dragOffset = 0;
  late final AnimationController _snapBackController;
  Animation<double>? _snapBackAnim;

  // Thresholds — feel-tuned for sheet dismissal.
  static const double _dismissDistanceThreshold = 100;
  static const double _dismissVelocityThreshold = 600;

  @override
  void initState() {
    super.initState();
    _snapBackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        if (_snapBackAnim != null) {
          setState(() => _dragOffset = _snapBackAnim!.value);
        }
      });
  }

  @override
  void dispose() {
    _snapBackController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      // Only allow downward drag.
      _dragOffset = (_dragOffset + details.delta.dy).clamp(0, 800);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final shouldDismiss = _dragOffset > _dismissDistanceThreshold ||
        velocity > _dismissVelocityThreshold;
    if (shouldDismiss) {
      widget.onClose();
      // Reset for next open.
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) setState(() => _dragOffset = 0);
      });
    } else {
      _snapBackAnim = Tween<double>(begin: _dragOffset, end: 0).animate(
        CurvedAnimation(parent: _snapBackController, curve: Curves.easeOutCubic),
      );
      _snapBackController
        ..reset()
        ..forward();
    }
  }

  void _onSelectByName(String? name) {
    if (name == null) {
      // Yoga / not-yet-implemented entries.
      debugPrint('[Library] Selected an entry without a real ExerciseDefinition.');
      return;
    }
    final def = lookupExerciseDefinition(name);
    if (def == null) {
      debugPrint('[Library] No ExerciseDefinition found for "$name".');
      return;
    }
    widget.onSelectExercise(def);
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Stack(
      children: [
        // Dimmed scrim — tapping it closes the sheet. Opacity follows
        // the drag offset so as the user drags down the scrim fades.
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            child: Container(
              color: c.ink.withValues(
                alpha: (0.4 * (1 - (_dragOffset / 400))).clamp(0.0, 0.4),
              ),
            ),
          ),
        ),
        // The sheet itself, translated by the live drag offset.
        Align(
          alignment: Alignment.bottomCenter,
          child: Transform.translate(
            offset: Offset(0, _dragOffset),
            child: FractionallySizedBox(
              heightFactor: 0.94,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: c.bg,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                child: Column(
                  children: [
                    // The drag handle + header are the swipe-to-dismiss
                    // target. Anywhere else inside the sheet is normal
                    // scrolling.
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: _onDragUpdate,
                      onVerticalDragEnd: _onDragEnd,
                      child: Column(
                        children: [
                          const SheetDragHandle(),
                          SheetHeader(onClose: widget.onClose),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.only(
                            bottom: widget.bottomPadding + 24),
                        child: _SheetBody(onSelectByName: _onSelectByName),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.onSelectByName});

  final void Function(String? name) onSelectByName;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SheetSearch(),
        // AI spotlight.
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: AISpotlight(onEnter: _stub),
        ),
        // Programs rail.
        const SizedBox(height: 28),
        const _SectionHeader(
          eyebrow: 'LỘ TRÌNH',
          title: 'Đi từng tuần.',
          meta: '4 lộ trình',
        ),
        const ProgramsRail(programs: libraryMockPrograms),
        // Intent collections.
        const SizedBox(height: 32),
        const _SectionHeader(
          eyebrow: 'BỘ SƯU TẬP',
          title: 'Theo lúc trong ngày.',
          meta: '6 bộ',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              for (var i = 0; i < libraryMockCollections.length; i++) ...[
                IntentCollection(mock: libraryMockCollections[i]),
                if (i < libraryMockCollections.length - 1)
                  const SizedBox(height: 14),
              ],
            ],
          ),
        ),
        // All exercises.
        const SizedBox(height: 36),
        const _SectionHeader(
          eyebrow: 'KHO BÀI TẬP',
          title: 'Tất cả 100 bài.',
          meta: 'Lọc theo nhu cầu',
        ),
        AllExercisesGrid(
          rows: libraryMockAllExercises,
          onSelectByName: onSelectByName,
        ),
        // Editorial closer.
        Padding(
          padding: const EdgeInsets.fromLTRB(40, 32, 40, 0),
          child: Container(
            padding: const EdgeInsets.only(top: 20),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.border)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'VIKA · CAT.01',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                      color: c.inkFaint,
                      fontFeatures: VikaIvoryMain.tabularFigures,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Container(height: 1, color: c.border),
                ),
                const SizedBox(width: 14),
                Text(
                  'Mỗi tuần thêm bài mới.',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      color: c.inkFaint,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static void _stub() {
    debugPrint('[Library] AI spotlight CTA tapped (stubbed).');
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.eyebrow,
    required this.title,
    required this.meta,
  });

  final String eyebrow;
  final String title;
  final String meta;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                PlanEyebrow(eyebrow, size: 10, letterSpacing: 2),
                const SizedBox(height: 6),
                PlanH1(title, size: 22, letterSpacing: -0.8, height: 1),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              meta.toUpperCase(),
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: c.inkFaint,
                  fontFeatures: VikaIvoryMain.tabularFigures,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
