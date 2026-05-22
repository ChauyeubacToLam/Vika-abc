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

  String _status() {
    if (widget.data.noPain) {
      return 'Không đau — tăng thử thách an toàn.';
    }
    if (widget.data.painAreas.isNotEmpty) {
      if (widget.data.painAreas.length == 1) {
        return 'Đang bảo vệ ${_painLabel(widget.data.painAreas.first)}.';
      }
      return 'Đang bảo vệ ${widget.data.painAreas.length} vùng.';
    }
    return 'Chọn vùng cần tránh.';
  }

  String _painLabel(String id) {
    for (final area in painAreaOptions) {
      if (area.id == id) return area.label;
    }
    return 'vùng đã chọn';
  }

  @override
  Widget build(BuildContext context) {
    final r = V5Responsive.of(context);
    return V5Page(
      index: 6,
      onBack: widget.onBack,
      cta: V5PillCTA(
        label: 'Tiếp tục',
        enabled: _canContinue,
        onTap: widget.onNext,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          V5ScreenHeader(
            eyebrow: 'An toàn cho bạn',
            title: 'Bạn đang đau\nở đâu?',
            size: r.isVeryShort ? V5HeaderSize.medium : V5HeaderSize.large,
          ),
          SizedBox(height: r.pick(cozy: V5.space12, short: V5.space8)),
          V5FadeIn(
            delay: const Duration(milliseconds: 120),
            child: SizedBox(
              height: r.pick(cozy: 176.0, short: 132.0, veryShort: 100.0),
              child: _PainMapCard(
                data: widget.data,
                status: _status(),
              ),
            ),
          ),
          SizedBox(height: r.pick(cozy: V5.space12, short: V5.space8)),
          Text(
            'VÙNG CẦN BẢO VỆ',
            style: V5.eyebrow(context, color: V5.inkSoft),
          ),
          SizedBox(height: r.pick(cozy: V5.space8, short: V5.space4)),
          Expanded(
            child: _PainZoneGrid(
              selectedAreas: widget.data.painAreas,
              noPain: widget.data.noPain,
              onPainTap: _togglePain,
              onNoPainTap: _toggleNoPain,
            ),
          ),
        ],
      ),
    );
  }
}

class _PainZoneGrid extends StatelessWidget {
  const _PainZoneGrid({
    required this.selectedAreas,
    required this.noPain,
    required this.onPainTap,
    required this.onNoPainTap,
  });

  final List<String> selectedAreas;
  final bool noPain;
  final ValueChanged<String> onPainTap;
  final VoidCallback onNoPainTap;

  @override
  Widget build(BuildContext context) {
    final r = V5Responsive.of(context);
    final rows = [
      painAreaOptions.take(2).toList(),
      painAreaOptions.skip(2).take(2).toList(),
      painAreaOptions.skip(4).take(2).toList(),
    ];
    final rowGap = r.pick(cozy: V5.space8, short: V5.space6);
    return Column(
      children: [
        for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) ...[
          Expanded(
            child: Row(
              children: rows[rowIndex].asMap().entries.map((entry) {
                final area = entry.value;
                final selected = selectedAreas.contains(area.id);
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: entry.key == rows[rowIndex].length - 1
                          ? 0
                          : V5.space8,
                    ),
                    child: V5FadeIn(
                      delay: Duration(milliseconds: 180 + rowIndex * 70),
                      slideY: 8,
                      child: _PainZoneTile(
                        area: area,
                        selected: selected,
                        onTap: () => onPainTap(area.id),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if (rowIndex != rows.length - 1) SizedBox(height: rowGap),
        ],
        SizedBox(height: rowGap),
        SizedBox(
          height: r.pick(cozy: 48.0, short: 44.0, veryShort: 42.0),
          child: V5FadeIn(
            delay: const Duration(milliseconds: 380),
            child: _NoPainChip(
              selected: noPain,
              onTap: onNoPainTap,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Pain map — dark body-safety summary
// ─────────────────────────────────────────────────────────────

class _PainMapCard extends StatelessWidget {
  const _PainMapCard({
    required this.data,
    required this.status,
  });

  final OnboardingData data;
  final String status;

  @override
  Widget build(BuildContext context) {
    final hasSelection = data.noPain || data.painAreas.isNotEmpty;
    final title = data.noPain
        ? 'Tất cả ổn'
        : data.painAreas.isEmpty
            ? 'Đang chờ'
            : data.painAreas.length == 1
                ? _label(data.painAreas.first)
                : '${data.painAreas.length} vùng';
    return V5HeroCard(
      borderRadius: V5.radiusLg,
      elevation: 2,
      child: Stack(
        children: [
          Positioned(
            right: -70,
            top: -60,
            child: V5AmbientGlow(
              size: const Size(240, 240),
              opacity: hasSelection ? 0.24 : 0.14,
              color: V5.yellow,
            ),
          ),
          Positioned(
            right: 18,
            top: 18,
            bottom: 16,
            width: 96,
            child: V5BodySilhouette(
              gender: data.gender,
              hasSelection: hasSelection,
              selectedAreas: data.painAreas,
              noPain: data.noPain,
            ),
          ),
          Positioned.fill(
            right: 120,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 10, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      V5PulseDot(
                        color: data.noPain ? V5.success : V5.yellow,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'BẢN ĐỒ AN TOÀN',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: V5.eyebrow(context, color: V5.invInkSoft),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: V5.displaySm(context, color: V5.invInk),
                        ),
                      ),
                      const SizedBox(height: V5.space6),
                      Text(
                        status,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: V5.bodySm(context, color: V5.invInkSoft),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _label(String id) {
    for (final area in painAreaOptions) {
      if (area.id == id) return area.label;
    }
    return 'Đã chọn';
  }
}

// ─────────────────────────────────────────────────────────────
// Pain zone tile — grid item
// ─────────────────────────────────────────────────────────────

class _PainZoneTile extends StatelessWidget {
  const _PainZoneTile({
    required this.area,
    required this.selected,
    required this.onTap,
  });

  final PainAreaOption area;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon {
    return switch (area.id) {
      'back' => Icons.airline_seat_recline_normal_rounded,
      'neck' => Icons.self_improvement_rounded,
      'knee' => Icons.directions_walk_rounded,
      'hip' => Icons.accessibility_new_rounded,
      'wrist' => Icons.pan_tool_alt_rounded,
      _ => Icons.more_horiz_rounded,
    };
  }

  String get _sub {
    return switch (area.id) {
      'back' => 'Cúi · nâng · squat',
      'neck' => 'Tư thế · vai',
      'knee' => 'Bước · xuống thấp',
      'hip' => 'Mở hông · xoay',
      'wrist' => 'Chống tay',
      _ => 'Ghi nhớ riêng',
    };
  }

  @override
  Widget build(BuildContext context) {
    return V5Card(
      onTap: onTap,
      selected: selected,
      tint: selected ? V5CardTint.ink : V5CardTint.cream,
      borderRadius: V5.radiusMd,
      padding: EdgeInsets.zero,
      elevation: selected ? 2 : 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dense = constraints.maxHeight < 52;
          return ClipRRect(
            borderRadius: BorderRadius.circular(V5.radiusMd),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 5,
                  color: selected ? V5.yellow : Colors.transparent,
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: dense ? 8 : 10,
                      vertical: dense ? 5 : 8,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: dense ? 26 : 30,
                          height: dense ? 26 : 30,
                          decoration: BoxDecoration(
                            color: selected ? V5.yellow : V5.yellowSoft,
                            borderRadius: BorderRadius.circular(V5.radiusSm),
                            border: selected
                                ? null
                                : Border.all(
                                    color: V5.yellow.withValues(alpha: 0.24),
                                  ),
                          ),
                          child: Icon(
                            _icon,
                            size: dense ? 14 : 16,
                            color: selected ? V5.yellowInk : V5.yellowDeep,
                          ),
                        ),
                        SizedBox(width: dense ? 7 : 9),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                area.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: V5.titleSm(
                                  context,
                                  color: selected ? V5.invInk : V5.ink,
                                ).copyWith(height: 1.12),
                              ),
                              if (!dense) ...[
                                const SizedBox(height: V5.space2),
                                Text(
                                  _sub,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: V5.caption(
                                    context,
                                    color: selected
                                        ? V5.invInkSoft
                                        : V5.inkFaint,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// No-pain chip — full width
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
                  'Không đau ở đâu cả',
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
