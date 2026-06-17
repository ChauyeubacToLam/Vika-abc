import 'package:flutter/material.dart';
import 'package:vika/models/pain_regions.dart';
import 'package:vika/widgets/progress/body_heat_map.dart';

import '../../onboarding_data.dart';
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

  BodyGender get _bodyGender =>
      widget.data.gender == 'female' ? BodyGender.female : BodyGender.male;

  Map<String, PainMark> get _reports => {
        for (final region in widget.data.painAreas)
          region: PainMark(
            intensity: widget.data.painIntensities[region],
            notes:
                region == kOtherPainRegion ? widget.data.painOtherText : null,
          ),
      };

  void _handleReport(String region, int intensity, String? notes) {
    setState(() {
      widget.data.noPain = false;
      if (!widget.data.painAreas.contains(region)) {
        widget.data.painAreas.add(region);
      }
      widget.data.painIntensities[region] = intensity.clamp(1, 5);
      if (region == kOtherPainRegion) {
        widget.data.painOtherText = notes;
      }
    });
  }

  void _handleResolve(String region) {
    setState(() {
      widget.data.painAreas.remove(region);
      widget.data.painIntensities.remove(region);
      if (region == kOtherPainRegion) {
        widget.data.painOtherText = null;
      }
    });
  }

  void _setNoPain() {
    setState(() {
      widget.data.noPain = true;
      widget.data.painAreas.clear();
      widget.data.painIntensities.clear();
      widget.data.painOtherText = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = V5Responsive.of(context);
    return V5Page(
      index: 6,
      onBack: widget.onBack,
      scroll: true,
      cta: V5PillCTA(
        label: 'Tiếp tục',
        enabled: _canContinue,
        onTap: widget.onNext,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          V5ScreenHeader(
            eyebrow: 'Để tập an toàn',
            title: 'Bạn có đang\nđau ở đâu không?',
            size: r.isVeryShort ? V5HeaderSize.medium : V5HeaderSize.large,
          ),
          SizedBox(height: r.pick(cozy: V5.space12, short: V5.space8)),
          V5FadeIn(
            delay: const Duration(milliseconds: 120),
            child: BodyPainReporter(
              reports: _reports,
              gender: _bodyGender,
              figureHeight: r.pick(cozy: 248.0, short: 218.0, veryShort: 188.0),
              onReport: _handleReport,
              onResolve: _handleResolve,
            ),
          ),
          SizedBox(height: r.pick(cozy: V5.space12, short: V5.space8)),
          V5FadeIn(
            delay: const Duration(milliseconds: 240),
            slideY: 8,
            child: SizedBox(
              height: r.pick(cozy: 50.0, short: 46.0, veryShort: 44.0),
              child: _NoPainChip(
                selected: widget.data.noPain,
                onTap: _setNoPain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// No-pain chip — explicit onboarding escape hatch
// ─────────────────────────────────────────────────────────────

class _NoPainChip extends StatelessWidget {
  const _NoPainChip({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dense = constraints.maxHeight < 46;
        return V5Card(
          onTap: onTap,
          selected: selected,
          tint: selected ? V5CardTint.ink : V5CardTint.cream,
          borderRadius: V5.radiusMd,
          padding: EdgeInsets.symmetric(
            horizontal: 18,
            vertical: dense ? 8 : 12,
          ),
          elevation: selected ? 2 : 1,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              V5CheckCircle(selected: selected, size: 18, dark: selected),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  'Tôi không đau ở đâu cả',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: V5.titleSm(
                    context,
                    color: selected ? V5.invInk : V5.ink,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
