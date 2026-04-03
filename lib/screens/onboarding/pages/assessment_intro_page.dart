import 'package:flutter/material.dart';
import 'package:vinafit_mobile/widgets/vf_primitives.dart';

import '../onboarding_data.dart';
import '../onboarding_primitives.dart';
import '../vf_theme.dart';

class AssessmentIntroPage extends StatefulWidget {
  const AssessmentIntroPage({
    super.key,
    required this.data,
    required this.onNext,
    required this.onBack,
  });

  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  State<AssessmentIntroPage> createState() => _AssessmentIntroPageState();
}

class _AssessmentIntroPageState extends State<AssessmentIntroPage> {
  static const _painAreas = [
    (id: 'none', label: 'Không có'),
    (id: 'lower_back', label: 'Lưng dưới'),
    (id: 'knee', label: 'Đầu gối'),
    (id: 'shoulder_neck', label: 'Vai / Cổ'),
    (id: 'hip', label: 'Hông'),
    (id: 'other', label: 'Khác'),
  ];

  final TextEditingController _otherController = TextEditingController();
  final FocusNode _otherFocusNode = FocusNode();

  bool get _hasPainSelectionBeyondNone =>
      widget.data.painAreas.any((id) => id != 'none');

  @override
  void initState() {
    super.initState();
    _otherController.text = widget.data.painOtherText ?? '';
  }

  @override
  void dispose() {
    _otherController.dispose();
    _otherFocusNode.dispose();
    super.dispose();
  }

  void _togglePainArea(String id) {
    final isSelected = widget.data.painAreas.contains(id);

    setState(() {
      if (id == 'none') {
        if (isSelected) {
          widget.data.painAreas.remove('none');
        } else {
          widget.data.painAreas
            ..clear()
            ..add('none');
          widget.data.painOtherText = null;
          _otherController.clear();
          _otherFocusNode.unfocus();
        }
        return;
      }

      if (isSelected) {
        widget.data.painAreas.remove(id);
        if (id == 'other') {
          widget.data.painOtherText = null;
          _otherController.clear();
          _otherFocusNode.unfocus();
        }
      } else {
        widget.data.painAreas.remove('none');
        widget.data.painAreas.add(id);
      }
    });

    if (!isSelected && id == 'other') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _otherFocusNode.requestFocus();
      });
    }
  }

  String _painLabel(String id) {
    if (id == 'other') {
      final value = widget.data.painOtherText?.trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
      return 'vùng khác';
    }

    for (final area in _painAreas) {
      if (area.id == id) return area.label;
    }
    return id;
  }

  String _joinWithAnd(List<String> values) {
    if (values.isEmpty) return '';
    if (values.length == 1) return values.first;
    if (values.length == 2) return '${values.first} và ${values.last}';
    return '${values.sublist(0, values.length - 1).join(', ')} và ${values.last}';
  }

  String get _painSummary {
    final labels = _painAreas
        .where(
          (area) =>
              area.id != 'none' && widget.data.painAreas.contains(area.id),
        )
        .map((area) => _painLabel(area.id))
        .toList();
    return _joinWithAnd(labels);
  }

  Widget _buildPainChip(BuildContext context, String id, String label) {
    final s = VF.scale(context);
    final isSelected = widget.data.painAreas.contains(id);
    final isNone = id == 'none';

    if (id == 'other' && isSelected) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.fromLTRB(14 * s, 5 * s, 8 * s, 5 * s),
        decoration: BoxDecoration(
          color: VF.coral.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12 * s),
          border: Border.all(color: VF.coral.withValues(alpha: 0.35)),
        ),
        child: IntrinsicWidth(
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: 126 * s, maxWidth: 190 * s),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: TextField(
                    controller: _otherController,
                    focusNode: _otherFocusNode,
                    maxLength: 30,
                    buildCounter: (
                      BuildContext context, {
                      required int currentLength,
                      required bool isFocused,
                      required int? maxLength,
                    }) {
                      return null;
                    },
                    cursorColor: VF.coral,
                    style: VF.textStyle(
                      context,
                      size: 12,
                      weight: FontWeight.w700,
                      color: VF.coral,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Khác...',
                      hintStyle: VF.textStyle(
                        context,
                        size: 12,
                        weight: FontWeight.w700,
                        color: VF.coral.withValues(alpha: 0.50),
                      ),
                      border: InputBorder.none,
                      counterText: '',
                    ),
                    onChanged: (value) {
                      setState(() {
                        widget.data.painOtherText = value.trim();
                      });
                    },
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                SizedBox(width: 6 * s),
                GestureDetector(
                  onTap: () => _togglePainArea('other'),
                  child: Container(
                    width: 20 * s,
                    height: 20 * s,
                    decoration: BoxDecoration(
                      color: VF.coral.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.close_rounded,
                      size: 13 * s,
                      color: VF.coral,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final activeTextColor = isNone ? VF.accent : VF.coral;
    final activeBackground = isNone
        ? VF.accent.withValues(alpha: 0.14)
        : VF.coral.withValues(alpha: 0.12);
    final activeBorder = isNone
        ? VF.accent.withValues(alpha: 0.40)
        : VF.coral.withValues(alpha: 0.35);

    return GestureDetector(
      onTap: () => _togglePainArea(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(horizontal: 16 * s, vertical: 10 * s),
        decoration: BoxDecoration(
          color: isSelected
              ? activeBackground
              : VF.textMuted.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12 * s),
          border: Border.all(
            color: isSelected
                ? activeBorder
                : VF.textMuted.withValues(alpha: 0.18),
          ),
        ),
        child: Text(
          label,
          style: VF.textStyle(
            context,
            size: 12,
            weight: FontWeight.w700,
            color: isSelected ? activeTextColor : VF.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildPainQuestion(BuildContext context) {
    final s = VF.scale(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16 * s),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16 * s),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bạn có đang đau ở đâu không?',
            style: VF.textStyle(
              context,
              size: 14,
              weight: FontWeight.w700,
              color: VF.text,
            ),
          ),
          SizedBox(height: 4 * s),
          Text(
            'Để AI điều chỉnh bài tập phù hợp hơn',
            style: VF.textStyle(
              context,
              size: 11,
              weight: FontWeight.w500,
              color: VF.textMuted,
            ),
          ),
          SizedBox(height: 12 * s),
          Wrap(
            spacing: 8 * s,
            runSpacing: 8 * s,
            children: [
              for (final area in _painAreas)
                _buildPainChip(context, area.id, area.label),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: _hasPainSelectionBeyondNone
                ? Padding(
                    padding: EdgeInsets.only(top: 12 * s),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12 * s),
                      decoration: BoxDecoration(
                        color: VF.amber.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12 * s),
                        border: Border.all(
                          color: VF.amber.withValues(alpha: 0.20),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(top: 1 * s),
                            child: Icon(
                              Icons.info_outline_rounded,
                              size: 14 * s,
                              color: VF.amber,
                            ),
                          ),
                          SizedBox(width: 8 * s),
                          Expanded(
                            child: Text(
                              'AI sẽ điều chỉnh bài tập để phù hợp với tình trạng $_painSummary của bạn. Nếu đau nhiều, hãy gặp bác sĩ trước.',
                              style: VF.textStyle(
                                context,
                                size: 11,
                                weight: FontWeight.w600,
                                color: VF.textSec,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = VF.scale(context);
    return ColoredBox(
      color: VF.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VFOnboardingNavBar(
            current: 4,
            total: 10,
            onBack: widget.onBack,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20 * s, 20 * s, 20 * s, 16 * s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8 * s),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bài đánh giá đầu vào',
                          style: VF.textStyle(
                            context,
                            size: 28,
                            weight: FontWeight.w900,
                            color: VF.text,
                            letterSpacing: -1.5,
                            height: 1.1,
                          ),
                        ),
                        SizedBox(height: 10 * s),
                        Text(
                          'AI sẽ đánh giá cách bạn vận động để cá nhân hóa lộ trình.',
                          style: VF.textStyle(
                            context,
                            size: 14,
                            weight: FontWeight.w500,
                            color: VF.textMuted,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20 * s),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24 * s),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          VF.surfaceDark,
                          VF.jadeDark,
                        ],
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24 * s),
                      child: Stack(
                        children: [
                          const Positioned.fill(
                            child: VFGrainOverlay(opacity: 0.035),
                          ),
                          Positioned(
                            top: -10 * s,
                            right: -10 * s,
                            child:
                                const VFDecorativeRing(size: 80, opacity: 0.04),
                          ),
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              22 * s,
                              20 * s,
                              22 * s,
                              20 * s,
                            ),
                            child: Column(
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: _AssessmentTag(
                                    label: 'BẠN TẬP',
                                    color: Colors.white.withValues(alpha: 0.40),
                                    background:
                                        Colors.white.withValues(alpha: 0.06),
                                  ),
                                ),
                                SizedBox(height: 14 * s),
                                Row(
                                  children: [
                                    const Expanded(
                                      child: _AssessmentMiniCard(
                                        title: 'Squat',
                                        subtitle: '5 reps',
                                      ),
                                    ),
                                    SizedBox(width: 10 * s),
                                    const Expanded(
                                      child: _AssessmentMiniCard(
                                        title: 'Wall Push-up',
                                        subtitle: '5 reps',
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 18 * s),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Divider(
                                        color: Colors.white
                                            .withValues(alpha: 0.06),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10 * s,
                                      ),
                                      child: Icon(
                                        Icons.south_rounded,
                                        size: 16 * s,
                                        color:
                                            VF.jadeGlow.withValues(alpha: 0.50),
                                      ),
                                    ),
                                    Expanded(
                                      child: Divider(
                                        color: Colors.white
                                            .withValues(alpha: 0.06),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 14 * s),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: _AssessmentTag(
                                    label: 'AI PHÂN TÍCH',
                                    color: VF.jadeGlow.withValues(alpha: 0.70),
                                    background:
                                        VF.jadeGlow.withValues(alpha: 0.10),
                                  ),
                                ),
                                SizedBox(height: 12 * s),
                                Row(
                                  children: const [
                                    Expanded(
                                      child: _MetricColumn(
                                        icon: Icons.show_chart_rounded,
                                        label: 'Độ sâu & góc',
                                      ),
                                    ),
                                    Expanded(
                                      child: _MetricColumn(
                                        icon: Icons.straighten_rounded,
                                        label: 'Tư thế lưng',
                                      ),
                                    ),
                                    Expanded(
                                      child: _MetricColumn(
                                        icon: Icons.schedule_rounded,
                                        label: 'Nhịp & kiểm soát',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16 * s),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4 * s),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _AssessmentTag(
                          label: 'BẠN NHẬN ĐƯỢC',
                          color: VF.accent,
                          background: VF.accent.withValues(alpha: 0.08),
                        ),
                        SizedBox(height: 12 * s),
                        Container(
                          padding: EdgeInsets.all(20 * s),
                          decoration: BoxDecoration(
                            color: VF.surface,
                            borderRadius: BorderRadius.circular(22 * s),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 8 * s,
                                offset: Offset(0, 4 * s),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  VFProgressRing(
                                    progress: 0.75,
                                    size: 52,
                                    strokeWidth: 3.5,
                                    color: VF.accent.withValues(alpha: 0.50),
                                    backgroundColor:
                                        VF.textMuted.withValues(alpha: 0.15),
                                    center: Text(
                                      '?',
                                      style: VF.textStyle(
                                        context,
                                        size: 15,
                                        weight: FontWeight.w900,
                                        color: VF.text,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 14 * s),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Điểm form & cấp độ',
                                          style: VF.textStyle(
                                            context,
                                            size: 14,
                                            weight: FontWeight.w700,
                                            color: VF.text,
                                          ),
                                        ),
                                        SizedBox(height: 3 * s),
                                        Text(
                                          'Điểm mạnh, điểm yếu, và lộ trình cá nhân hóa',
                                          style: VF.textStyle(
                                            context,
                                            size: 11,
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
                              SizedBox(height: 14 * s),
                              Wrap(
                                spacing: 6 * s,
                                runSpacing: 6 * s,
                                children: [
                                  _chip(context, 'Cấp độ phù hợp', true),
                                  _chip(context, 'Điểm cần cải thiện', false),
                                  _chip(context, 'Chương trình 4 tuần', false),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(8 * s, 14 * s, 8 * s, 8 * s),
                    child: Row(
                      children: [
                        Icon(
                          Icons.videocam_outlined,
                          size: 16 * s,
                          color: VF.textMuted,
                        ),
                        SizedBox(width: 10 * s),
                        Expanded(
                          child: Text(
                            'Đặt điện thoại nghiêng, cách khoảng 2m',
                            style: VF.textStyle(
                              context,
                              size: 12,
                              weight: FontWeight.w600,
                              color: VF.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8 * s),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2 * s),
                    child: _buildPainQuestion(context),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(6 * s, 10 * s, 6 * s, 0),
                    child: Text(
                      'Nếu bạn có bệnh tim, huyết áp cao, đang mang thai, vừa phẫu thuật, hoặc bệnh lý nghiêm trọng, hãy tham khảo ý kiến bác sĩ trước khi tập.',
                      style: VF.textStyle(
                        context,
                        size: 11,
                        weight: FontWeight.w500,
                        color: VF.textMuted,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          VFOnboardingButton(
            label: 'Bắt đầu đánh giá',
            onTap: widget.data.painAreas.isNotEmpty ? widget.onNext : null,
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, bool active) {
    final s = VF.scale(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 5 * s),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10 * s),
        color: active ? VF.accentSoft : VF.textMuted.withValues(alpha: 0.06),
      ),
      child: Text(
        label,
        style: VF.textStyle(
          context,
          size: 11,
          weight: FontWeight.w600,
          color: active ? VF.accent : VF.textMuted,
        ),
      ),
    );
  }
}

class _AssessmentTag extends StatelessWidget {
  const _AssessmentTag({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final s = VF.scale(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 4 * s),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8 * s),
        color: background,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5 * s,
            height: 5 * s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          SizedBox(width: 6 * s),
          Text(
            label,
            style: TextStyle(
              fontSize: VF.sp(context, 10),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5 * s,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssessmentMiniCard extends StatelessWidget {
  const _AssessmentMiniCard({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final s = VF.scale(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 12 * s),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16 * s),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: VF.textStyle(
              context,
              size: 14,
              weight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.80),
            ),
          ),
          SizedBox(height: 2 * s),
          Text(
            subtitle,
            style: VF.textStyle(
              context,
              size: 10,
              weight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.20),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricColumn extends StatelessWidget {
  const _MetricColumn({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final s = VF.scale(context);
    return Column(
      children: [
        Icon(
          icon,
          size: 18 * s,
          color: VF.jadeGlow.withValues(alpha: 0.50),
        ),
        SizedBox(height: 4 * s),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: VF.sp(context, 9),
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.25),
          ),
        ),
      ],
    );
  }
}
