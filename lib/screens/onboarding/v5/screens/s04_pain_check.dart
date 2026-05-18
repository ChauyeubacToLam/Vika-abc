import 'package:flutter/material.dart';

import '../../onboarding_data.dart';
import '../v5_models.dart';
import '../v5_primitives.dart';
import '../v5_theme.dart';

class S04PainCheck extends StatefulWidget {
  const S04PainCheck({
    super.key,
    required this.data,
    required this.onNext,
    required this.onBack,
  });

  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  State<S04PainCheck> createState() => _S04PainCheckState();
}

class _S04PainCheckState extends State<S04PainCheck> {
  bool get _canContinue =>
      widget.data.noPain || widget.data.painAreas.isNotEmpty;

  void _togglePain(String id) {
    // TODO(LOGIC-REFINEMENT-#10): S04→S14 painAreas → exercise modification wiring stores painAreas but Journey does not adjust suggested exercises.
    // Currently using v1 placeholder from JSX prototype. Real logic deferred to Phase 2.
    // See Notion: Vika State > Onboarding Logic Refinement block for full context.
    setState(() {
      if (widget.data.noPain) widget.data.noPain = false;
      if (widget.data.painAreas.contains(id)) {
        widget.data.painAreas.remove(id);
      } else {
        widget.data.painAreas.add(id);
      }
    });
  }

  void _toggleNoPain() {
    setState(() {
      widget.data.noPain = !widget.data.noPain;
      if (widget.data.noPain) widget.data.painAreas.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 720;
    final heroTop = compact ? 126.0 : 144.0;
    final heroHeight = compact ? 180.0 : 200.0;
    final contentTop = compact ? 318.0 : 360.0;
    final statusText = widget.data.noPain
        ? 'Tất cả ổn — Vika sẽ thiết kế bài an toàn'
        : widget.data.painAreas.isNotEmpty
            ? 'Đã ghi nhận ${widget.data.painAreas.length} vùng — Vika sẽ tránh'
            : 'Vika sẽ tránh khu vực bạn chọn';
    return V5Screen(
      index: 4,
      onBack: widget.onBack,
      children: [
        Positioned(
          top: heroTop,
          left: 16,
          right: 16,
          height: heroHeight,
          child: V5FadeIn(
            child: V5HeroCard(
              child: Stack(
                children: [
                  const Positioned(
                    top: 18,
                    left: 18,
                    child: V5Eyebrow(label: 'An toàn cho bạn', dark: true),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    bottom: 8,
                    width: 170,
                    child: V5BodyDiagram(
                      painAreas: widget.data.painAreas,
                      noPain: widget.data.noPain,
                    ),
                  ),
                  Positioned(
                    left: 24,
                    bottom: 20,
                    width: 170,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TRƯỚC KHI BẮT ĐẦU',
                          style: V5.text(
                            context,
                            size: 11,
                            weight: FontWeight.w600,
                            color: V5.invInkSoft,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'Đang đau\nở đâu?',
                          style: V5.text(
                            context,
                            size: 24,
                            weight: FontWeight.w800,
                            color: V5.invInk,
                            letterSpacing: -0.8,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          statusText,
                          style: V5.text(
                            context,
                            size: 11,
                            weight: FontWeight.w500,
                            color: V5.invInkSoft,
                            height: 1.4,
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
        Positioned(
          top: contentTop,
          left: 0,
          right: 0,
          bottom: 0,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: Column(
                    children: [
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 2.75,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        children: painAreaOptions.asMap().entries.map((entry) {
                          final i = entry.key;
                          final area = entry.value;
                          final selected =
                              widget.data.painAreas.contains(area.id);
                          return V5FadeIn(
                            delay: Duration(milliseconds: i * 30),
                            slideY: 8,
                            child: _PainButton(
                              label: area.label,
                              selected: selected,
                              onTap: () => _togglePain(area.id),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      _PainButton(
                        label: 'Không đau ở đâu cả',
                        selected: widget.data.noPain,
                        centered: true,
                        onTap: _toggleNoPain,
                      ),
                      const SizedBox(height: 14),
                      _HealthNote(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 96),
            ],
          ),
        ),
        V5PillCTA(
          label: 'Tiếp tục',
          disabledLabel: 'Chọn để tiếp',
          enabled: _canContinue,
          onTap: widget.onNext,
        ),
      ],
    );
  }
}

class _PainButton extends StatelessWidget {
  const _PainButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.centered = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: centered ? 58 : 54),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: selected ? V5.ink : V5.surface,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: selected ? V5.ink : V5.border),
            boxShadow: [selected ? V5.cardShadow(0.18) : V5.cardShadow(0.08)],
          ),
          child: Row(
            mainAxisAlignment: centered
                ? MainAxisAlignment.center
                : MainAxisAlignment.spaceBetween,
            children: [
              if (centered) ...[
                V5CheckCircle(selected: selected, size: 20),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: V5.text(
                    context,
                    size: 14,
                    weight: FontWeight.w800,
                    color: selected ? V5.invInk : V5.ink,
                    letterSpacing: -0.2,
                    height: 1.1,
                  ),
                ),
              ),
              if (!centered) V5CheckCircle(selected: selected, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _HealthNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 11, 14, 11),
      decoration: BoxDecoration(
        color: V5.yellow.withValues(alpha: 0.07),
        border: Border.all(color: V5.yellow.withValues(alpha: 0.22)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: V5.yellowSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.favorite_border_rounded,
                color: V5.yellowDeep, size: 18),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lưu ý sức khoẻ',
                  style: V5.text(
                    context,
                    size: 12,
                    weight: FontWeight.w800,
                    color: V5.ink,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Vika không thay thế bác sĩ. Nếu đau nhiều, hãy gặp chuyên khoa.',
                  style: V5.text(
                    context,
                    size: 11,
                    weight: FontWeight.w500,
                    color: V5.inkSoft,
                    height: 1.45,
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
