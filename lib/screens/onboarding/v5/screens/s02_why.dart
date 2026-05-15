import 'package:flutter/material.dart';

import '../../onboarding_data.dart';
import '../v5_models.dart';
import '../v5_primitives.dart';
import '../v5_theme.dart';

class S02Why extends StatefulWidget {
  const S02Why({
    super.key,
    required this.data,
    required this.onNext,
    required this.onBack,
  });

  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  State<S02Why> createState() => _S02WhyState();
}

class _S02WhyState extends State<S02Why> {
  late final TextEditingController _customController;
  final FocusNode _customFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _customController = TextEditingController(text: widget.data.whyCustomText);
    _customFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _customController.dispose();
    _customFocus.dispose();
    super.dispose();
  }

  bool get _canContinue =>
      widget.data.whyStep1 != null &&
      (widget.data.whyStep2 != null ||
          widget.data.whyCustomText.trim().isNotEmpty);

  V5WhyOption? get _stem {
    final id = widget.data.whyStep1;
    if (id == null) return null;
    for (final option in whyOptions) {
      if (option.id == id) return option;
    }
    return null;
  }

  void _pickStem(String id) {
    setState(() {
      widget.data.whyStep1 = id;
      widget.data.why = id;
      widget.data.whyStep2 = null;
      widget.data.whyCustomText = '';
      _customController.clear();
    });
  }

  void _resetStem() {
    setState(() {
      widget.data.whyStep1 = null;
      widget.data.why = null;
      widget.data.whyStep2 = null;
      widget.data.whyCustomText = '';
      _customController.clear();
      _customFocus.unfocus();
    });
  }

  void _pickFollowup(String label) {
    setState(() {
      widget.data.whyStep2 = label;
      widget.data.whyCustomText = '';
      _customController.clear();
      _customFocus.unfocus();
    });
  }

  void _writeCustom(String value) {
    // TODO(LOGIC-REFINEMENT-#11): S02 `whyCustomText` reflective answer surfacing is collected but not surfaced anywhere in the app.
    // Currently using v1 placeholder from JSX prototype. Real logic deferred to Phase 2.
    // See Notion: Vika State > Onboarding Logic Refinement block for full context.
    setState(() {
      widget.data.whyCustomText = value;
      if (value.trim().isNotEmpty) widget.data.whyStep2 = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final stem = _stem;
    final compact = MediaQuery.sizeOf(context).height < 720;
    final heroTop = compact ? 126.0 : 144.0;
    final heroHeight = compact ? 180.0 : 200.0;
    final contentTop = compact ? 320.0 : 360.0;
    return V5Screen(
      index: 2,
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
                    child: V5Eyebrow(label: 'Lý do của bạn', dark: true),
                  ),
                  Positioned(
                    top: 0,
                    right: -40,
                    bottom: 0,
                    width: 260,
                    child: V5FadeIn(
                      key: ValueKey(stem?.id ?? 'empty-why'),
                      child: V5HeroFigure(pose: stem?.pose ?? 'squat'),
                    ),
                  ),
                  if (stem != null)
                    Positioned(
                      left: 24,
                      bottom: 20,
                      child: V5FadeIn(
                        key: ValueKey('stat-${stem.id}'),
                        slideY: 12,
                        curve: Curves.easeOutBack,
                        child: SizedBox(
                          width: 180,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SAU 4 TUẦN',
                                style: V5.text(
                                  context,
                                  size: 11,
                                  weight: FontWeight.w600,
                                  color: V5.invInkSoft,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                stem.stat,
                                style: V5.text(
                                  context,
                                  size: 42,
                                  weight: FontWeight.w800,
                                  color: V5.yellow,
                                  letterSpacing: -2,
                                  height: 0.92,
                                ),
                              ),
                              Text(
                                stem.statLabel,
                                style: V5.text(
                                  context,
                                  size: 11,
                                  weight: FontWeight.w500,
                                  color: V5.invInkSoft,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _SentenceBuilder(stem: stem, data: widget.data),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: stem == null ? _stemOptions() : _followups(stem),
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

  Widget _stemOptions() {
    final compact = MediaQuery.sizeOf(context).height < 720;
    return Column(
      children: whyOptions.asMap().entries.map((entry) {
        final i = entry.key;
        final option = entry.value;
        return Padding(
          padding: EdgeInsets.only(bottom: compact ? 8 : 10),
          child: V5FadeIn(
            delay: Duration(milliseconds: i * 45),
            slideY: 8,
            child: GestureDetector(
              onTap: () => _pickStem(option.id),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: compact ? 58 : 66),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: compact ? 12 : 14,
                  ),
                  decoration: BoxDecoration(
                    color: V5.surface,
                    border: Border.all(color: V5.border),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [V5.cardShadow(0.08)],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              option.label,
                              style: V5.text(
                                context,
                                size: 15,
                                weight: FontWeight.w800,
                                color: V5.ink,
                                letterSpacing: -0.2,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              option.sub,
                              style: V5.text(
                                context,
                                size: 12,
                                weight: FontWeight.w500,
                                color: V5.inkSoft,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                          color: V5.bgSoft,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.chevron_right_rounded,
                            size: 21, color: V5.inkSoft),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _followups(V5WhyOption stem) {
    final items = whyFollowups[stem.id] ?? const <String>[];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Text(
                'CỤ THỂ HƠN',
                style: V5.text(
                  context,
                  size: 10,
                  weight: FontWeight.w700,
                  color: V5.inkSoft,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _resetStem,
                child: Row(
                  children: [
                    const Icon(Icons.arrow_back_rounded,
                        size: 13, color: V5.yellowDeep),
                    const SizedBox(width: 4),
                    Text(
                      'ĐỔI Ý',
                      style: V5.text(
                        context,
                        size: 10,
                        weight: FontWeight.w700,
                        color: V5.yellowDeep,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ...items.asMap().entries.map((entry) {
          final i = entry.key;
          final label = entry.value;
          final selected = widget.data.whyStep2 == label;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: V5FadeIn(
              delay: Duration(milliseconds: i * 40),
              slideY: 8,
              child: _ChoiceRow(
                label: label,
                selected: selected,
                onTap: () => _pickFollowup(label),
              ),
            ),
          );
        }),
        V5FadeIn(
          delay: Duration(milliseconds: items.length * 40),
          slideY: 8,
          child: _customInput(),
        ),
      ],
    );
  }

  Widget _customInput() {
    final customSelected = widget.data.whyCustomText.trim().isNotEmpty;
    final active = _customFocus.hasFocus || customSelected;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 58),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: customSelected ? V5.ink : V5.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: customSelected
                ? V5.ink
                : active
                    ? V5.yellow
                    : V5.border,
          ),
          boxShadow: [
            if (customSelected)
              V5.cardShadow(0.18)
            else if (active)
              BoxShadow(color: V5.yellowSoft, spreadRadius: 2),
            V5.cardShadow(0.08),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: active || customSelected ? V5.yellow : V5.bgSoft,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(Icons.edit_rounded,
                  size: 15,
                  color: active || customSelected ? V5.yellowInk : V5.inkSoft),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _customController,
                focusNode: _customFocus,
                maxLength: 48,
                onChanged: _writeCustom,
                style: V5.text(
                  context,
                  size: 14,
                  weight: FontWeight.w700,
                  color: customSelected ? V5.invInk : V5.ink,
                  letterSpacing: -0.1,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'Tự viết câu của bạn...',
                  hintStyle: V5.text(
                    context,
                    size: 14,
                    weight: FontWeight.w600,
                    color: V5.ink.withValues(alpha: 0.30),
                  ),
                ),
              ),
            ),
            if (customSelected) ...[
              Text(
                '${widget.data.whyCustomText.length}/48',
                style: V5.text(
                  context,
                  size: 9,
                  weight: FontWeight.w600,
                  color: V5.invInkFaint,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(width: 8),
              const V5CheckCircle(selected: true, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}

class _SentenceBuilder extends StatelessWidget {
  const _SentenceBuilder({required this.stem, required this.data});

  final V5WhyOption? stem;
  final OnboardingData data;

  @override
  Widget build(BuildContext context) {
    final chosen = data.whyStep2 ?? data.whyCustomText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: V5.text(
              context,
              size: 21,
              weight: FontWeight.w800,
              color: V5.ink,
              letterSpacing: -0.6,
              height: 1.2,
            ),
            children: [
              const TextSpan(text: 'Tôi tập vì muốn '),
              TextSpan(
                text: stem?.label.toLowerCase() ?? '........',
                style: TextStyle(color: stem == null ? V5.inkDim : V5.ink),
              ),
            ],
          ),
        ),
        Container(
          width: stem == null ? 72 : 150,
          height: 3,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: stem == null ? V5.yellowSoft : V5.yellow,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        if (stem != null)
          V5FadeIn(
            delay: const Duration(milliseconds: 120),
            slideY: 8,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: RichText(
                text: TextSpan(
                  style: V5.text(
                    context,
                    size: 13,
                    weight: FontWeight.w500,
                    color: V5.inkSoft,
                    height: 1.3,
                  ),
                  children: [
                    const TextSpan(text: 'Trong 4 tuần tới tôi sẽ '),
                    TextSpan(
                      text: chosen.trim().isEmpty
                          ? '........'
                          : chosen.toLowerCase(),
                      style: TextStyle(
                        color: chosen.trim().isEmpty ? V5.inkDim : V5.ink,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                        decorationColor:
                            chosen.trim().isEmpty ? V5.borderHi : V5.yellow,
                        decorationThickness: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? V5.ink : V5.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? V5.ink : V5.border),
            boxShadow: [selected ? V5.cardShadow(0.18) : V5.cardShadow(0.08)],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: V5.text(
                    context,
                    size: 14,
                    weight: FontWeight.w700,
                    color: selected ? V5.invInk : V5.ink,
                    letterSpacing: -0.1,
                    height: 1.2,
                  ),
                ),
              ),
              if (selected) const V5CheckCircle(selected: true, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
