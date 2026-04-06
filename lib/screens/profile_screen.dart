import 'package:flutter/material.dart';

import '../theme/vf_theme.dart';
import '../widgets/vf_primitives.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.bottomPadding,
  });

  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);

    return SingleChildScrollView(
      key: const PageStorageKey<String>('profile-scroll'),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 14 * s),
          Padding(
            padding: EdgeInsets.fromLTRB(24 * s, 0, 24 * s, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    VFGradientAvatar(
                      label: 'N',
                      size: (56 * s).roundToDouble(),
                      fontSize: 22 * s,
                      fontWeight: FontWeight.w900,
                    ),
                    SizedBox(width: 16 * s),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nam',
                            style: VFTheme.textStyle(
                              context,
                              size: 22,
                              weight: FontWeight.w900,
                              color: VFTheme.text,
                              letterSpacing: -0.8,
                            ),
                          ),
                          Text(
                            'Thành viên từ tháng 3, 2026',
                            style: VFTheme.textStyle(
                              context,
                              size: 11,
                              weight: FontWeight.w500,
                              color: VFTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 34 * s,
                      height: 34 * s,
                      decoration: BoxDecoration(
                        color: VFTheme.surface,
                        borderRadius: BorderRadius.circular(11 * s),
                        border: Border.all(color: VFTheme.hairline),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.settings_outlined,
                        size: 16 * s,
                        color: VFTheme.textMuted,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16 * s),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: 16 * s,
                    vertical: 12 * s,
                  ),
                  decoration: BoxDecoration(
                    color: VFTheme.jadeMist,
                    borderRadius: BorderRadius.circular(14 * s),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '2 tuần tập đều. Cổ chân cải thiện thấy rõ. Cứ giữ nhịp này.',
                        style: VFTheme.textStyle(
                          context,
                          size: 13,
                          weight: FontWeight.w500,
                          color: VFTheme.jadeDark,
                          fontStyle: FontStyle.italic,
                          height: 1.55,
                        ),
                      ),
                      SizedBox(height: 5 * s),
                      Text(
                        'HLV AI · Cập nhật thứ Hai',
                        style: VFTheme.textStyle(
                          context,
                          size: 9,
                          weight: FontWeight.w600,
                          color: VFTheme.jade.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(14 * s, 16 * s, 14 * s, 0),
            child: Container(
              decoration: BoxDecoration(
                color: VFTheme.surface,
                borderRadius: BorderRadius.circular(24 * s),
                border: Border.all(color: VFTheme.hairline),
              ),
              child: Column(
                children: [
                  Padding(
                    padding:
                        EdgeInsets.fromLTRB(20 * s, 18 * s, 20 * s, 14 * s),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _BodyStat(
                                value: '170',
                                unit: 'cm',
                                label: 'Chiều cao',
                              ),
                            ),
                            Container(
                                width: 1,
                                height: 44 * s,
                                color: VFTheme.background),
                            Expanded(
                              child: _BodyStat(
                                value: '65',
                                unit: 'kg',
                                label: 'Cân nặng',
                              ),
                            ),
                            Container(
                                width: 1,
                                height: 44 * s,
                                color: VFTheme.background),
                            Expanded(
                              child: _BodyStat(
                                value: '22.5',
                                unit: '',
                                label: 'BMI',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _Divider(scale: s),
                  Padding(
                    padding:
                        EdgeInsets.fromLTRB(20 * s, 14 * s, 20 * s, 14 * s),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Chương trình cơ bản',
                                    style: VFTheme.textStyle(
                                      context,
                                      size: 15,
                                      weight: FontWeight.w800,
                                      color: VFTheme.text,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  SizedBox(height: 1 * s),
                                  Text(
                                    '4 tuần · 3 buổi/tuần',
                                    style: VFTheme.textStyle(
                                      context,
                                      size: 11,
                                      weight: FontWeight.w500,
                                      color: VFTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10 * s,
                                vertical: 4 * s,
                              ),
                              decoration: BoxDecoration(
                                color: VFTheme.jadeMist,
                                borderRadius: BorderRadius.circular(7 * s),
                              ),
                              child: Text(
                                'Tuần 2/4',
                                style: VFTheme.textStyle(
                                  context,
                                  size: 10,
                                  weight: FontWeight.w700,
                                  color: VFTheme.jade,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10 * s),
                        Container(
                          height: 5 * s,
                          decoration: BoxDecoration(
                            color: VFTheme.jade.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: 0.42,
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: VFTheme.jadeProgressGradient,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 4 * s),
                        Text(
                          '5 / 12 buổi hoàn thành',
                          style: VFTheme.textStyle(
                            context,
                            size: 10,
                            weight: FontWeight.w500,
                            color: VFTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _Divider(scale: s),
                  Padding(
                    padding:
                        EdgeInsets.fromLTRB(20 * s, 14 * s, 20 * s, 16 * s),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CỘT MỐC',
                          style: VFTheme.textStyle(
                            context,
                            size: 10,
                            weight: FontWeight.w700,
                            color: VFTheme.textMuted,
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(height: 10 * s),
                        Wrap(
                          spacing: 6 * s,
                          runSpacing: 6 * s,
                          children: _milestones
                              .map((milestone) =>
                                  _MilestonePill(milestone: milestone))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(14 * s, 14 * s, 14 * s, 0),
            child: Container(
              decoration: BoxDecoration(
                color: VFTheme.surface,
                borderRadius: BorderRadius.circular(24 * s),
                border: Border.all(color: VFTheme.hairline),
              ),
              child: Column(
                children: [
                  for (int index = 0; index < _settingRows.length; index++) ...[
                    if (_settingRows[index].divider)
                      _Divider(scale: s)
                    else
                      _SettingRow(item: _settingRows[index]),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(22 * s, 14 * s, 22 * s, 24 * s),
            child: Center(
              child: Text(
                'VinaFit v1.0',
                style: VFTheme.textStyle(
                  context,
                  size: 10,
                  weight: FontWeight.w500,
                  color: VFTheme.textMuted.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BodyStat extends StatelessWidget {
  const _BodyStat({
    required this.value,
    required this.unit,
    required this.label,
  });

  final String value;
  final String unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: VFTheme.textStyle(
                context,
                size: 22,
                weight: FontWeight.w900,
                color: VFTheme.text,
                letterSpacing: -1,
              ),
            ),
            if (unit.isNotEmpty) ...[
              SizedBox(width: 1 * s),
              Padding(
                padding: EdgeInsets.only(bottom: 2 * s),
                child: Text(
                  unit,
                  style: VFTheme.textStyle(
                    context,
                    size: 11,
                    weight: FontWeight.w500,
                    color: VFTheme.textMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: 2 * s),
        Text(
          label,
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

class _MilestonePill extends StatelessWidget {
  const _MilestonePill({required this.milestone});

  final _Milestone milestone;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * s,
        vertical: 5 * s,
      ),
      decoration: BoxDecoration(
        color: milestone.done
            ? VFTheme.jade.withValues(alpha: 0.08)
            : VFTheme.textMuted.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8 * s),
        border: Border.all(
          color: milestone.done
              ? VFTheme.jade.withValues(alpha: 0.1)
              : VFTheme.textMuted.withValues(alpha: 0.2),
          style: milestone.done ? BorderStyle.solid : BorderStyle.solid,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          milestone.done
              ? Icon(
                  Icons.check_rounded,
                  size: 12 * s,
                  color: VFTheme.jade,
                )
              : Container(
                  width: 10 * s,
                  height: 10 * s,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: VFTheme.textMuted.withValues(alpha: 0.4),
                      width: 0.9 * s,
                    ),
                  ),
                ),
          SizedBox(width: 5 * s),
          Text(
            milestone.label,
            style: VFTheme.textStyle(
              context,
              size: 11,
              weight: milestone.done ? FontWeight.w600 : FontWeight.w500,
              color: milestone.done ? VFTheme.text : VFTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.item});

  final _SettingItem item;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20 * s),
      child: Row(
        children: [
          SizedBox(
            width: 18 * s,
            child: Icon(
              item.icon,
              size: 16 * s,
              color: item.danger
                  ? VFTheme.coral.withValues(alpha: 0.9)
                  : item.accent
                      ? VFTheme.jade
                      : VFTheme.textMuted.withValues(alpha: 0.6),
            ),
          ),
          SizedBox(width: 12 * s),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 13 * s),
              child: Text(
                item.label,
                style: VFTheme.textStyle(
                  context,
                  size: 13,
                  weight: item.accent
                      ? FontWeight.w700
                      : item.danger
                          ? FontWeight.w600
                          : FontWeight.w500,
                  color: item.danger
                      ? VFTheme.coral.withValues(alpha: 0.9)
                      : item.accent
                          ? VFTheme.jade
                          : VFTheme.textSecondary,
                ),
              ),
            ),
          ),
          if (item.value.isNotEmpty)
            Text(
              item.value,
              style: VFTheme.textStyle(
                context,
                size: 12,
                weight: FontWeight.w500,
                color: VFTheme.textMuted,
              ),
            ),
          if (!item.danger) ...[
            SizedBox(width: 8 * s),
            Icon(
              Icons.chevron_right_rounded,
              size: 14 * s,
              color: VFTheme.textMuted.withValues(alpha: 0.5),
            ),
          ],
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: EdgeInsets.symmetric(horizontal: 20 * scale),
      color: VFTheme.background,
    );
  }
}

class _Milestone {
  const _Milestone({
    required this.label,
    required this.done,
  });

  final String label;
  final bool done;
}

class _SettingItem {
  const _SettingItem({
    this.icon = Icons.circle,
    this.label = '',
    this.value = '',
    this.accent = false,
    this.danger = false,
    this.divider = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool accent;
  final bool danger;
  final bool divider;
}

const List<_Milestone> _milestones = [
  _Milestone(label: 'Tuần đầu tiên', done: true),
  _Milestone(label: 'Form 75%+', done: true),
  _Milestone(label: '10 buổi', done: true),
  _Milestone(label: '30 ngày liên tiếp', done: false),
];

const List<_SettingItem> _settingRows = [
  _SettingItem(
    icon: Icons.calendar_month_outlined,
    label: 'Lịch tập',
    value: 'T2, T4, T6',
  ),
  _SettingItem(
    icon: Icons.notifications_none_rounded,
    label: 'Nhắc nhở',
    value: '18:30',
  ),
  _SettingItem(
    icon: Icons.graphic_eq_rounded,
    label: 'Giọng nói AI',
    value: 'Giọng Bắc',
  ),
  _SettingItem(
    icon: Icons.language_rounded,
    label: 'Ngôn ngữ',
    value: 'Tiếng Việt',
  ),
  _SettingItem(divider: true),
  _SettingItem(
    icon: Icons.auto_fix_high_rounded,
    label: 'Đánh giá lại form',
    accent: true,
  ),
  _SettingItem(
    icon: Icons.help_outline_rounded,
    label: 'Hỗ trợ',
  ),
  _SettingItem(divider: true),
  _SettingItem(
    icon: Icons.logout_rounded,
    label: 'Đăng xuất',
    danger: true,
  ),
];
