// GoalEditSheet — Premium Ivory bottom sheet for changing the user's training
// goal (profiles.goals[0]). Mirrors the onboarding goal step's grammar — a live
// hero preview + selectable options — in the main-app Ivory register. Returns
// the chosen goal id (health | body | strength | flexible) via Navigator.pop,
// or null if dismissed.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/profile_goal_quote.dart';
import '../../theme/app_colors.dart';
import 'edit_sheet_chrome.dart';

class _GoalOption {
  const _GoalOption({
    required this.id,
    required this.title,
    required this.sub,
    required this.icon,
  });
  final String id;
  final String title;
  final String sub;
  final IconData icon;
}

const List<_GoalOption> _goalOptions = [
  _GoalOption(
    id: 'health',
    title: 'Sức khỏe',
    sub: 'Dẻo dai, ít đau mỏi',
    icon: Icons.favorite_rounded,
  ),
  _GoalOption(
    id: 'body',
    title: 'Vóc dáng',
    sub: 'Săn chắc, gọn người',
    icon: Icons.straighten_rounded,
  ),
  _GoalOption(
    id: 'strength',
    title: 'Sức mạnh',
    sub: 'Cơ bắp, sức bền',
    icon: Icons.fitness_center_rounded,
  ),
  _GoalOption(
    id: 'flexible',
    title: 'Linh hoạt',
    sub: 'Mềm dẻo, an toàn',
    icon: Icons.self_improvement_rounded,
  ),
];

class GoalEditSheet extends StatefulWidget {
  const GoalEditSheet({super.key, this.currentGoal, required this.onSave});

  final String? currentGoal;

  /// Persists the chosen goal. Returns true on success; the sheet stays open
  /// and shows nothing extra on failure (the caller surfaces the error).
  final Future<bool> Function(String goal) onSave;

  @override
  State<GoalEditSheet> createState() => _GoalEditSheetState();
}

class _GoalEditSheetState extends State<GoalEditSheet> {
  late String? _selected = widget.currentGoal;
  bool _saving = false;

  bool get _dirty => _selected != null && _selected != widget.currentGoal;

  Future<void> _save() async {
    final goal = _selected;
    if (goal == null || _saving) return;
    setState(() => _saving = true);
    final ok = await widget.onSave(goal);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(goal);
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Chưa lưu được mục tiêu, thử lại sau.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProfileEditSheetCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ProfileSheetHeader(
            icon: Icons.flag_rounded,
            eyebrow: 'MỤC TIÊU',
            title: 'Bạn muốn đạt gì?',
          ),
          const SizedBox(height: 18),
          _GoalPreview(goalId: _selected),
          const SizedBox(height: 16),
          for (var i = 0; i < _goalOptions.length; i++) ...[
            _GoalRow(
              option: _goalOptions[i],
              selected: _selected == _goalOptions[i].id,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selected = _goalOptions[i].id);
              },
            ),
            if (i != _goalOptions.length - 1) const SizedBox(height: 10),
          ],
          const SizedBox(height: 20),
          ProfileSheetSaveButton(
            label: 'Lưu mục tiêu',
            saving: _saving,
            onPressed: _dirty ? _save : null,
          ),
        ],
      ),
    );
  }
}

// ─── Live preview — dark hero echoing the selected goal's copy ───────────
class _GoalPreview extends StatelessWidget {
  const _GoalPreview({required this.goalId});
  final String? goalId;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final title = goalTitleFor(goalId);
    final quote = goalQuoteFor(goalId);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.bgInverse,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: c.ink.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -50,
            child: IgnorePointer(
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      c.yellow.withValues(alpha: 0.22),
                      c.yellow.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.7],
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: c.yellow,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: c.yellow, blurRadius: 6)],
                    ),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    'XEM TRƯỚC',
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                      color: c.yellow,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title.endsWith('.') ? title : '$title.',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -1.2,
                  height: 1.05,
                  color: c.invInk,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '"$quote"',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                  color: c.invInkSoft,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Selectable goal row ─────────────────────────────────────────────────
class _GoalRow extends StatelessWidget {
  const _GoalRow({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _GoalOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? c.ink : c.bgRaised,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? c.ink : c.border,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: c.ink.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              option.icon,
              size: 20,
              color: selected ? c.yellow : c.inkSoft,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    option.title,
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      letterSpacing: -0.3,
                      color: selected ? c.invInk : c.ink,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    option.sub,
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: selected ? c.invInkSoft : c.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _CheckDot(selected: selected),
          ],
        ),
      ),
    );
  }
}

class _CheckDot extends StatelessWidget {
  const _CheckDot({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: selected ? c.yellow : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? c.yellow : c.borderHi,
          width: 1.5,
        ),
      ),
      child: selected
          ? Icon(Icons.check_rounded, size: 14, color: c.yellowInk)
          : null,
    );
  }
}
