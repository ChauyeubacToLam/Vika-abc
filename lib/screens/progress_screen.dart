import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/vf_theme.dart';
import '../widgets/vf_primitives.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({
    super.key,
    required this.bottomPadding,
  });

  final double bottomPadding;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  int selectedInsight = 0;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);

    return SingleChildScrollView(
      key: const PageStorageKey<String>('progress-scroll'),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: EdgeInsets.only(bottom: widget.bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 10 * s),
          Padding(
            padding: EdgeInsets.fromLTRB(14 * s, 0, 14 * s, 0),
            child: _StreakHero(scale: s),
          ),
          Container(
            height: 20 * s,
            margin: EdgeInsets.symmetric(horizontal: 14 * s),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  VFTheme.jadeMist.withValues(alpha: 0.4),
                  Colors.transparent,
                ],
              ),
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(20 * s),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(22 * s, 22 * s, 22 * s, 0),
            child: _CoachSection(scale: s),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(18 * s, 16 * s, 18 * s, 0),
            child: _BodyBalanceCard(scale: s),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(18 * s, 14 * s, 18 * s, 0),
            child: _TrendCard(scale: s),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(22 * s, 14 * s, 22 * s, 0),
            child: _HistoryStrip(scale: s),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(14 * s, 20 * s, 14 * s, 24 * s),
            child: _LockedInsightsCard(
              scale: s,
              selectedIndex: selectedInsight,
              onSelect: (index) => setState(() => selectedInsight = index),
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakHero extends StatelessWidget {
  const _StreakHero({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28 * scale),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A1D1C), Color(0xFF111312)],
                ),
              ),
            ),
          ),
          const Positioned.fill(child: VFGrainOverlay()),
          Positioned(
            top: -40 * scale,
            right: 72 * scale,
            child: Container(
              width: 180 * scale,
              height: 180 * scale,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: VFTheme.jade.withValues(alpha: 0.03),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              24 * scale,
              24 * scale,
              24 * scale,
              22 * scale,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      'VIKA',
                      style: VFTheme.textStyle(
                        context,
                        size: 9,
                        weight: FontWeight.w700,
                        color: VFTheme.jadeGlow.withValues(alpha: 0.3),
                        letterSpacing: 3,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12 * scale,
                        vertical: 5 * scale,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8 * scale),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.04),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.share_outlined,
                            size: 11 * scale,
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                          SizedBox(width: 5 * scale),
                          Text(
                            'Chia sẻ',
                            style: VFTheme.textStyle(
                              context,
                              size: 10,
                              weight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20 * scale),
                SizedBox(
                  width: 148 * scale,
                  height: 148 * scale,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: Size.square(148 * scale),
                        painter: _StreakRingPainter(progress: 14 / 30),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '14',
                            style: VFTheme.textStyle(
                              context,
                              size: 48,
                              weight: FontWeight.w900,
                              color: VFTheme.white,
                              letterSpacing: -2.6,
                              height: 1,
                            ),
                          ),
                          SizedBox(height: 4 * scale),
                          Text(
                            'ngày liên tiếp',
                            style: VFTheme.textStyle(
                              context,
                              size: 12,
                              weight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20 * scale),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _HeroStat(number: '52', label: 'buổi tập'),
                    SizedBox(width: 24 * scale),
                    const _HeroStat(number: '18.5h', label: 'tổng'),
                    SizedBox(width: 24 * scale),
                    const _HeroStat(number: 'Lv.4', label: 'cấp độ'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.number,
    required this.label,
  });

  final String number;
  final String label;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);

    return Column(
      children: [
        Text(
          number,
          style: VFTheme.textStyle(
            context,
            size: 18,
            weight: FontWeight.w900,
            color: VFTheme.white,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 2 * s),
        Text(
          label,
          style: VFTheme.textStyle(
            context,
            size: 9,
            weight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.2),
          ),
        ),
      ],
    );
  }
}

class _CoachSection extends StatelessWidget {
  const _CoachSection({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28 * scale,
              height: 28 * scale,
              decoration: BoxDecoration(
                color: VFTheme.jadeMist,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.check_rounded,
                size: 15 * scale,
                color: VFTheme.jade,
              ),
            ),
            SizedBox(width: 8 * scale),
            Text(
              'HLV AI của bạn',
              style: VFTheme.textStyle(
                context,
                size: 14,
                weight: FontWeight.w800,
                color: VFTheme.text,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        SizedBox(height: 12 * scale),
        RichText(
          text: TextSpan(
            style: VFTheme.textStyle(
              context,
              size: 15,
              weight: FontWeight.w500,
              color: VFTheme.textSecondary,
              height: 1.7,
            ),
            children: [
              const TextSpan(text: 'Tuần này bạn tập '),
              TextSpan(
                text: 'đều và đúng form',
                style: VFTheme.textStyle(
                  context,
                  size: 15,
                  weight: FontWeight.w800,
                  color: VFTheme.text,
                  height: 1.7,
                ),
              ),
              const TextSpan(text: '. Chân mạnh hơn rõ rệt. '),
              TextSpan(
                text: 'Core cần tăng cường',
                style: VFTheme.textStyle(
                  context,
                  size: 15,
                  weight: FontWeight.w800,
                  color: VFTheme.jade,
                  height: 1.7,
                ),
              ),
              const TextSpan(
                text:
                    ' vì plank ngắn, curl-up chưa đủ. Tuần tới AI sẽ thêm bài core phù hợp hơn.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BodyBalanceCard extends StatelessWidget {
  const _BodyBalanceCard({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          EdgeInsets.fromLTRB(20 * scale, 18 * scale, 20 * scale, 18 * scale),
      decoration: BoxDecoration(
        color: VFTheme.surface,
        borderRadius: BorderRadius.circular(22 * scale),
        border: Border.all(color: VFTheme.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SỨC MẠNH THEO NHÓM CƠ',
            style: VFTheme.textStyle(
              context,
              size: 10,
              weight: FontWeight.w700,
              color: VFTheme.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 14 * scale),
          for (int index = 0; index < _muscleStats.length; index++) ...[
            _MuscleBar(stat: _muscleStats[index]),
            if (index < _muscleStats.length - 1) SizedBox(height: 12 * scale),
          ],
        ],
      ),
    );
  }
}

class _MuscleBar extends StatelessWidget {
  const _MuscleBar({required this.stat});

  final _MuscleStat stat;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              stat.name,
              style: VFTheme.textStyle(
                context,
                size: 13,
                weight: FontWeight.w700,
                color: VFTheme.text,
              ),
            ),
            if (stat.weak) ...[
              SizedBox(width: 6 * s),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 6 * s,
                  vertical: 1 * s,
                ),
                decoration: BoxDecoration(
                  color: VFTheme.amberBg,
                  borderRadius: BorderRadius.circular(4 * s),
                ),
                child: Text(
                  'CẦN CẢI THIỆN',
                  style: VFTheme.textStyle(
                    context,
                    size: 8,
                    weight: FontWeight.w800,
                    color: VFTheme.amber,
                  ),
                ),
              ),
            ],
            const Spacer(),
            Text(
              '${stat.percent}%',
              style: VFTheme.textStyle(
                context,
                size: 11,
                weight: FontWeight.w700,
                color: VFTheme.textMuted,
              ),
            ),
          ],
        ),
        SizedBox(height: 6 * s),
        Container(
          height: 6 * s,
          decoration: BoxDecoration(
            color: stat.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(999),
          ),
          clipBehavior: Clip.antiAlias,
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: stat.percent / 100,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: stat.weak
                      ? [
                          stat.color.withValues(alpha: 0.6),
                          stat.color.withValues(alpha: 0.3),
                        ]
                      : [
                          stat.color,
                          stat.color.withValues(alpha: 0.8),
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

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          EdgeInsets.fromLTRB(20 * scale, 18 * scale, 20 * scale, 14 * scale),
      decoration: BoxDecoration(
        color: VFTheme.surface,
        borderRadius: BorderRadius.circular(22 * scale),
        border: Border.all(color: VFTheme.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'FORM CHUNG',
                style: VFTheme.textStyle(
                  context,
                  size: 10,
                  weight: FontWeight.w700,
                  color: VFTheme.textMuted,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                '+11% trong 4 tuần',
                style: VFTheme.textStyle(
                  context,
                  size: 12,
                  weight: FontWeight.w800,
                  color: VFTheme.jade,
                ),
              ),
            ],
          ),
          SizedBox(height: 4 * scale),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '78%',
                style: VFTheme.textStyle(
                  context,
                  size: 36,
                  weight: FontWeight.w900,
                  color: VFTheme.text,
                  letterSpacing: -2,
                  height: 1,
                ),
              ),
              SizedBox(width: 4 * scale),
              Padding(
                padding: EdgeInsets.only(bottom: 5 * scale),
                child: Text(
                  'trung bình tất cả bài tập',
                  style: VFTheme.textStyle(
                    context,
                    size: 12,
                    weight: FontWeight.w500,
                    color: VFTheme.textMuted,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10 * scale),
          SizedBox(
            height: 40 * scale,
            width: double.infinity,
            child: CustomPaint(painter: _TrendPainter()),
          ),
          SizedBox(height: 4 * scale),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              'Tuần 1',
              'Tuần 2',
              'Tuần 3',
              'Hôm nay',
            ]
                .map(
                  (label) => Text(
                    label,
                    style: VFTheme.textStyle(
                      context,
                      size: 9,
                      weight: FontWeight.w500,
                      color: VFTheme.textMuted,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _HistoryStrip extends StatelessWidget {
  const _HistoryStrip({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              'Lịch sử',
              style: VFTheme.textStyle(
                context,
                size: 14,
                weight: FontWeight.w800,
                color: VFTheme.text,
                letterSpacing: -0.3,
              ),
            ),
            SizedBox(width: 8 * scale),
            Expanded(
              child: Container(
                height: 1,
                color: VFTheme.textMuted.withValues(alpha: 0.15),
              ),
            ),
          ],
        ),
        SizedBox(height: 10 * scale),
        Row(
          children: [
            for (int index = 0; index < _historyWeeks.length; index++) ...[
              Expanded(child: _HistoryBar(item: _historyWeeks[index])),
              if (index < _historyWeeks.length - 1) SizedBox(width: 8 * scale),
            ],
          ],
        ),
      ],
    );
  }
}

class _HistoryBar extends StatelessWidget {
  const _HistoryBar({required this.item});

  final _HistoryWeek item;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    final fillHeight = item.total > 0
        ? math
            .max((item.done / item.total) * (48 * s), item.done > 0 ? 6 : 0)
            .toDouble()
        : 0.0;

    return Column(
      children: [
        Container(
          height: 48 * s,
          decoration: BoxDecoration(
            color: VFTheme.textMuted.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10 * s),
          ),
          clipBehavior: Clip.antiAlias,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: fillHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10 * s),
                gradient: item.current
                    ? LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          VFTheme.jade.withValues(alpha: 0.55),
                          VFTheme.jade,
                        ],
                      )
                    : item.future
                        ? null
                        : LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: item.full
                                ? [VFTheme.jade, VFTheme.jade]
                                : [
                                    VFTheme.jade.withValues(alpha: 0.77),
                                    VFTheme.jade.withValues(alpha: 0.9),
                                  ],
                          ),
                color: item.future ? Colors.transparent : null,
              ),
            ),
          ),
        ),
        SizedBox(height: 4 * s),
        Text(
          '${item.done}/${item.total}',
          style: VFTheme.textStyle(
            context,
            size: 12,
            weight: FontWeight.w800,
            color: item.current
                ? VFTheme.jade
                : item.future
                    ? VFTheme.textMuted
                    : VFTheme.text,
          ),
        ),
        Text(
          item.label,
          style: VFTheme.textStyle(
            context,
            size: 9,
            weight: FontWeight.w500,
            color: VFTheme.textMuted,
          ),
        ),
      ],
    );
  }
}

class _LockedInsightsCard extends StatelessWidget {
  const _LockedInsightsCard({
    required this.scale,
    required this.selectedIndex,
    required this.onSelect,
  });

  final double scale;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final selected = _insights[selectedIndex];

    return ClipRRect(
      borderRadius: BorderRadius.circular(24 * scale),
      child: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(color: Color(0xFF151816)),
            ),
          ),
          const Positioned.fill(child: VFGrainOverlay()),
          Positioned(
            top: -20 * scale,
            right: 32 * scale,
            child: Container(
              width: 120 * scale,
              height: 120 * scale,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected.color.withValues(alpha: 0.08),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20 * scale,
              20 * scale,
              20 * scale,
              18 * scale,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Phân tích form',
                        style: VFTheme.textStyle(
                          context,
                          size: 15,
                          weight: FontWeight.w800,
                          color: VFTheme.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 9 * scale,
                        vertical: 3 * scale,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBB8F0).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(5 * scale),
                        border: Border.all(
                          color:
                              const Color(0xFFCBB8F0).withValues(alpha: 0.06),
                        ),
                      ),
                      child: Text(
                        'PRO',
                        style: VFTheme.textStyle(
                          context,
                          size: 9,
                          weight: FontWeight.w800,
                          color: const Color(0xFFCBB8F0).withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 14 * scale),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  child: Row(
                    children: [
                      for (int index = 0;
                          index < _insights.length;
                          index++) ...[
                        _InsightChip(
                          item: _insights[index],
                          selected: index == selectedIndex,
                          onTap: () => onSelect(index),
                        ),
                        if (index < _insights.length - 1)
                          SizedBox(width: 6 * scale),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 16 * scale),
                ClipRRect(
                  borderRadius: BorderRadius.circular(18 * scale),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.02),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.04),
                            ),
                          ),
                        ),
                      ),
                      ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                        child: Opacity(
                          opacity: 0.3,
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              0,
                              18 * scale,
                              0,
                              18 * scale,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _PreviewMetric(
                                      label: 'Tuần 1',
                                      value: selected.beforeValue,
                                      highlight: false,
                                    ),
                                    SizedBox(width: 20 * scale),
                                    Text(
                                      '→',
                                      style: VFTheme.textStyle(
                                        context,
                                        size: 22,
                                        weight: FontWeight.w900,
                                        color: VFTheme.jadeGlow,
                                      ),
                                    ),
                                    SizedBox(width: 20 * scale),
                                    _PreviewMetric(
                                      label: 'Hôm nay',
                                      value: selected.currentValue,
                                      highlight: true,
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12 * scale),
                                Wrap(
                                  spacing: 8 * scale,
                                  runSpacing: 8 * scale,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    _PreviewPill(label: selected.gainLabel),
                                    _PreviewPill(label: selected.goalLabel),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20 * scale),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16 * scale),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                            child: Container(
                              padding: EdgeInsets.fromLTRB(
                                24 * scale,
                                14 * scale,
                                24 * scale,
                                14 * scale,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFCBB8F0)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16 * scale),
                                border: Border.all(
                                  color: const Color(0xFFCBB8F0)
                                      .withValues(alpha: 0.08),
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.lock_outline_rounded,
                                    size: 20 * scale,
                                    color: const Color(0xFFCBB8F0)
                                        .withValues(alpha: 0.7),
                                  ),
                                  SizedBox(height: 6 * scale),
                                  Text(
                                    'Mở khóa phân tích chi tiết',
                                    textAlign: TextAlign.center,
                                    style: VFTheme.textStyle(
                                      context,
                                      size: 13,
                                      weight: FontWeight.w800,
                                      color: VFTheme.white,
                                    ),
                                  ),
                                  SizedBox(height: 3 * scale),
                                  Text(
                                    'Góc, so sánh, gợi ý cá nhân cho từng bài',
                                    textAlign: TextAlign.center,
                                    style: VFTheme.textStyle(
                                      context,
                                      size: 10,
                                      weight: FontWeight.w500,
                                      color:
                                          Colors.white.withValues(alpha: 0.3),
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightChip extends StatelessWidget {
  const _InsightChip({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _InsightPreview item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14 * s),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.fromLTRB(14 * s, 10 * s, 14 * s, 10 * s),
          decoration: BoxDecoration(
            color: selected
                ? item.color.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14 * s),
            border: Border.all(
              color: selected
                  ? item.color.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.03),
            ),
          ),
          child: Column(
            children: [
              Text(
                item.score,
                style: VFTheme.textStyle(
                  context,
                  size: 16,
                  weight: FontWeight.w900,
                  color: selected
                      ? VFTheme.jadeGlow
                      : Colors.white.withValues(alpha: 0.5),
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 2 * s),
              Text(
                item.name,
                style: VFTheme.textStyle(
                  context,
                  size: 10,
                  weight: FontWeight.w600,
                  color: selected
                      ? Colors.white.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewMetric extends StatelessWidget {
  const _PreviewMetric({
    required this.label,
    required this.value,
    required this.highlight,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: VFTheme.textStyle(
            context,
            size: 28,
            weight: FontWeight.w900,
            color: highlight
                ? VFTheme.jadeGlow
                : Colors.white.withValues(alpha: 0.4),
            letterSpacing: -1.2,
          ),
        ),
        Text(
          label,
          style: VFTheme.textStyle(
            context,
            size: 9,
            weight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.2),
          ),
        ),
      ],
    );
  }
}

class _PreviewPill extends StatelessWidget {
  const _PreviewPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 12 * s,
        vertical: 6 * s,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8 * s),
      ),
      child: Text(
        label,
        style: VFTheme.textStyle(
          context,
          size: 10,
          weight: FontWeight.w500,
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

class _StreakRingPainter extends CustomPainter {
  const _StreakRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = 63 * (size.width / 148);
    const circumference = 396.0;
    final sweep = circumference * progress;

    final track = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round;
    final glow = Paint()
      ..color = VFTheme.jadeGlow.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round;
    final arc = Paint()
      ..color = VFTheme.jadeGlow.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, track);

    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      (sweep / circumference) * math.pi * 2,
      false,
      glow,
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      (sweep / circumference) * math.pi * 2,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _StreakRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _TrendPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x1A1B6B52),
          Color(0x001B6B52),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    final line = Paint()
      ..color = VFTheme.jade.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final dot = Paint()..color = VFTheme.jade.withValues(alpha: 0.7);

    final points = [
      Offset(0, size.height * 0.9),
      Offset(size.width * 0.125, size.height * 0.85),
      Offset(size.width * 0.25, size.height * 0.75),
      Offset(size.width * 0.375, size.height * 0.7),
      Offset(size.width * 0.5, size.height * 0.6),
      Offset(size.width * 0.625, size.height * 0.5),
      Offset(size.width * 0.75, size.height * 0.35),
      Offset(size.width * 0.875, size.height * 0.25),
      Offset(size.width, size.height * 0.1),
    ];

    final area = Path()..moveTo(0, size.height);
    for (final point in points) {
      area.lineTo(point.dx, point.dy);
    }
    area
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(area, fill);

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, line);
    canvas.drawCircle(points.last, 4, dot);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MuscleStat {
  const _MuscleStat({
    required this.name,
    required this.percent,
    required this.color,
    this.weak = false,
  });

  final String name;
  final int percent;
  final Color color;
  final bool weak;
}

class _HistoryWeek {
  const _HistoryWeek({
    required this.label,
    required this.done,
    required this.total,
    this.full = false,
    this.current = false,
    this.future = false,
  });

  final String label;
  final int done;
  final int total;
  final bool full;
  final bool current;
  final bool future;
}

class _InsightPreview {
  const _InsightPreview({
    required this.name,
    required this.score,
    required this.color,
    required this.beforeValue,
    required this.currentValue,
    required this.gainLabel,
    required this.goalLabel,
  });

  final String name;
  final String score;
  final Color color;
  final String beforeValue;
  final String currentValue;
  final String gainLabel;
  final String goalLabel;
}

const List<_MuscleStat> _muscleStats = [
  _MuscleStat(name: 'Chân', percent: 85, color: VFTheme.jade),
  _MuscleStat(name: 'Mông', percent: 72, color: VFTheme.jade),
  _MuscleStat(name: 'Ngực & Vai', percent: 65, color: VFTheme.blue),
  _MuscleStat(name: 'Core', percent: 42, color: VFTheme.amber, weak: true),
];

const List<_HistoryWeek> _historyWeeks = [
  _HistoryWeek(label: 'T1', done: 2, total: 3),
  _HistoryWeek(label: 'T2', done: 3, total: 3, full: true),
  _HistoryWeek(label: 'T3', done: 2, total: 3, current: true),
  _HistoryWeek(label: 'T4', done: 0, total: 3, future: true),
];

const List<_InsightPreview> _insights = [
  _InsightPreview(
    name: 'Squat',
    score: '82%',
    color: VFTheme.jade,
    beforeValue: '118°',
    currentValue: '106°',
    gainLabel: 'Tiến bộ +12°',
    goalLabel: 'Mục tiêu sâu hơn',
  ),
  _InsightPreview(
    name: 'Push-up',
    score: '71%',
    color: VFTheme.blue,
    beforeValue: '32°',
    currentValue: '24°',
    gainLabel: 'Vai ổn định hơn',
    goalLabel: 'Giữ core cứng',
  ),
  _InsightPreview(
    name: 'Plank',
    score: '65%',
    color: VFTheme.amber,
    beforeValue: '18s',
    currentValue: '28s',
    gainLabel: 'Thêm +10s',
    goalLabel: 'Giữ hông ngang',
  ),
  _InsightPreview(
    name: 'Lunge',
    score: '78%',
    color: VFTheme.purple,
    beforeValue: '94°',
    currentValue: '88°',
    gainLabel: 'Bước ổn định hơn',
    goalLabel: 'Cân bằng tốt hơn',
  ),
  _InsightPreview(
    name: 'Curl-up',
    score: '60%',
    color: VFTheme.coral,
    beforeValue: '12 reps',
    currentValue: '18 reps',
    gainLabel: 'Tăng +6 reps',
    goalLabel: 'Giữ cổ trung lập',
  ),
];
