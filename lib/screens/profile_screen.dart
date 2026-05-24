// ProfileScreen — the Hồ sơ tab. Premium Ivory v2 (cinematic).
//
// Architecture (top to bottom):
//   ▲ Stage hero — dark, full-bleed, italic name, edit/share pills
//   1. Mục tiêu — goal card with progress meter
//   2. Hành trình tính đến hôm nay — lifetime stats card + coach
//   3. Thành tựu — achievements rail (editorial medallions)
//   4. Hành trình — journey timeline with TODAY anchor
//   5. Vóc dáng — refined body card + BMI chip
//   6. Mời bạn dùng Vika — referral card
//   7. Kết nối — connected services
//   8. Cài đặt — settings groups
//   9. Closer + back-to-top + version
//   ▼ Sticky pill bar (slides in after scroll past hero)

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../data/profile_mock.dart';
import '../services/user_profile_service.dart';
import '../theme/app_colors.dart';
import '../theme/vf_theme.dart';
import '../utils/orientation_lock.dart';
import '../widgets/profile/achievements_rail.dart';
import '../widgets/profile/body_card.dart';
import '../widgets/profile/connect_share_section.dart';
import '../widgets/profile/goal_card.dart';
import '../widgets/profile/journey_timeline.dart';
import '../widgets/profile/lifetime_hero.dart';
import '../widgets/profile/profile_stage_hero.dart';
import '../widgets/profile/settings_group.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.bottomPadding,
    this.userProfile,
    this.onProfileChanged,
  });

  final double bottomPadding;
  final AppUserProfile? userProfile;
  final ValueChanged<AppUserProfile>? onProfileChanged;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ScrollController _scrollController = ScrollController();
  final _profileService = UserProfileService();
  bool _showStickyBar = false;
  AppUserProfile? _profile;

  static const double _stickyBarThreshold = 260;

  @override
  void initState() {
    super.initState();
    unawaited(OrientationLock.portraitOnly());
    _scrollController.addListener(_onScroll);
    _profile = widget.userProfile;
    unawaited(_loadProfile());
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userProfile != widget.userProfile &&
        widget.userProfile != null) {
      _profile = widget.userProfile;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final shouldShow = _scrollController.offset > _stickyBarThreshold;
    if (shouldShow != _showStickyBar) {
      setState(() => _showStickyBar = shouldShow);
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _loadProfile() async {
    final profile = await _profileService.fetchCurrentProfile();
    if (!mounted || profile == null) return;
    setState(() => _profile = profile);
    widget.onProfileChanged?.call(profile);
  }

  Future<void> _openEditProfileSheet() async {
    final saved = await showModalBottomSheet<AppUserProfile>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _EditProfileSheet(
        current: _profile,
        profileService: _profileService,
      ),
    );
    if (!mounted) return;
    if (saved != null) {
      setState(() => _profile = saved);
      widget.onProfileChanged?.call(saved);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Đã cập nhật hồ sơ.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final profile = _profile;
    final displayName = profile?.displayName ?? profileMockName;
    final userInitial = profile?.initial ?? profileMockInitial;
    final avatarUrl = profile?.avatarUrl;
    final streakDays = profile?.streakDays ?? 0;
    final memberSince = profile?.memberSinceLabel ?? profileMockMemberSince;
    final memberSinceLine =
        'Thành viên từ $memberSince · $streakDays ngày liên tiếp';
    final height = profile?.heightCm ?? profileMockHeight;
    final weight = profile?.weightKg ?? profileMockWeight;
    final age = profile?.age ?? profileMockAge;
    final bmi = profile?.bmiLabel ?? profileMockBMI;
    final bmiCategory = profile?.bmiCategory ?? profileMockBMILabel;

    return Container(
      color: c.bg,
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: Stack(
          children: [
            SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(bottom: widget.bottomPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ProfileStageHero(
                    name: displayName,
                    userInitial: userInitial,
                    avatarUrl: avatarUrl,
                    phaseLabel: profileMockPhaseShort,
                    memberSinceLine: memberSinceLine,
                    goalProgress: profileMockGoalProgress,
                    inlineStats: [
                      '$streakDays NGÀY',
                      '8 BUỔI',
                      '74% FORM',
                    ],
                    onEdit: _openEditProfileSheet,
                    onEditPhoto: _openEditProfileSheet,
                  ),
                  const SizedBox(height: 24),

                  // 1. Mục tiêu — goal card with progress meter.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GoalCard(
                      title: profileMockGoalTitle,
                      quote: profileMockGoalQuote,
                      progress: profileMockGoalProgress,
                      daysLeft: profileMockGoalDaysLeft,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // 2. Hành trình tính đến hôm nay — lifetime stats.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: LifetimeHero(
                      stats: profileMockLifetimeStats,
                      coach: profileMockCoachLine,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // 3. Thành tựu — achievements rail.
                  _SectionHeader(
                    eyebrow: 'THÀNH TỰU',
                    meta:
                        '${profileMockAchievements.where((a) => a.unlocked).length} / ${profileMockAchievements.length}',
                    intro:
                        'Những cột mốc Vika ghi lại trong hành trình. Mỗi chương là một dấu mốc.',
                  ),
                  const SizedBox(height: 14),
                  const AchievementsRail(
                    achievements: profileMockAchievements,
                  ),
                  const SizedBox(height: 40),

                  // 4. Hành trình — journey timeline.
                  _SectionHeader(
                    eyebrow: 'HÀNH TRÌNH',
                    meta: '${profileMockJourney.length} MỐC',
                    intro: 'Câu chuyện của bạn từ ngày đầu đến hôm nay.',
                  ),
                  const SizedBox(height: 14),
                  const JourneyTimeline(
                    milestones: profileMockJourney,
                  ),
                  const SizedBox(height: 40),

                  // 5. Vóc dáng — body card.
                  _SectionHeader(
                    eyebrow: 'VÓC DÁNG',
                    intro: 'Số đo hiện tại. Sửa khi cần.',
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: BodyCard(
                      height: height,
                      weight: weight,
                      age: age,
                      bmi: bmi,
                      bmiCategory: bmiCategory,
                      onEdit: _openEditProfileSheet,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // 6. Mời bạn — referral card.
                  _SectionHeader(
                    eyebrow: 'MỜI BẠN',
                    intro: 'Một lượt mời thành công tặng bạn 1 tuần Vika+.',
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ReferralCard(
                      count: profileMockReferralCount,
                      subtitle: profileMockReferralLine,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // 7. Kết nối — connected services.
                  _SectionHeader(
                    eyebrow: 'KẾT NỐI',
                    intro: 'Đồng bộ buổi tập với các dịch vụ sức khoẻ khác.',
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const ConnectionsList(
                      services: profileMockConnections,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // 8. Cài đặt — settings groups.
                  _SectionHeader(
                    eyebrow: 'CÀI ĐẶT',
                    intro: 'Tuỳ chỉnh trải nghiệm Vika theo cách của bạn.',
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SettingsGroup(
                          label: 'Tập luyện',
                          rows: [
                            SettingRow(
                              icon: Icons.notifications_none_rounded,
                              label: 'Nhắc tập',
                              sub: 'T2 / T4 / T6 · 17:30',
                              onTap: () {},
                            ),
                            SettingRow(
                              icon: Icons.mic_none_rounded,
                              label: 'Giọng huấn luyện viên',
                              sub: 'Nữ · Tự nhiên',
                              onTap: () {},
                            ),
                          ],
                        ),
                        SettingsGroup(
                          label: 'Quyền riêng tư',
                          rows: [
                            SettingRow(
                              icon: Icons.shield_outlined,
                              label: 'Camera xử lý trong máy',
                              sub: 'Hình ảnh không rời thiết bị',
                              onTap: () {},
                            ),
                            SettingRow(
                              icon: Icons.download_rounded,
                              label: 'Tải dữ liệu của bạn',
                              onTap: () {},
                            ),
                          ],
                        ),
                        SettingsGroup(
                          label: 'Hỗ trợ',
                          rows: [
                            SettingRow(
                              icon: Icons.help_outline_rounded,
                              label: 'Trợ giúp & Phản hồi',
                              onTap: () {},
                            ),
                            SettingRow(
                              icon: Icons.info_outline_rounded,
                              label: 'Về Vika',
                              sub: profileMockVersion,
                              onTap: () {},
                            ),
                          ],
                        ),
                        SettingsGroup(
                          label: 'Tài khoản',
                          rows: [
                            SettingRow(
                              icon: Icons.person_outline_rounded,
                              label: 'Sửa hồ sơ',
                              sub: displayName,
                              onTap: _openEditProfileSheet,
                            ),
                            if (profile?.email != null)
                              SettingRow(
                                icon: Icons.alternate_email_rounded,
                                label: 'Email',
                                sub: profile!.email,
                                onTap: () {},
                              ),
                            SettingRow(
                              icon: Icons.logout_rounded,
                              label: 'Đăng xuất',
                              danger: true,
                              onTap: () {},
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // 9. Closer + back-to-top.
                  _Closer(
                    onBackToTop: _scrollToTop,
                    version: profileMockVersion,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            _StickyPillBar(
              visible: _showStickyBar,
              userInitial: userInitial,
              avatarUrl: avatarUrl,
              name: displayName,
              onTap: _scrollToTop,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SECTION HEADER — eyebrow + accent bar + intro pull-quote.
// Mirrors the grammar used on Library and Tien bo.
// ═══════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.eyebrow,
    this.meta,
    this.intro,
  });

  final String eyebrow;
  final String? meta;
  final String? intro;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, intro == null ? 0 : 10),
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
// EDIT PROFILE SHEET — owns its TextEditingController + selected
// avatar file so the lifecycle is bound to this widget, not to a
// parent async function.
// ═══════════════════════════════════════════════════════════════

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({
    required this.current,
    required this.profileService,
  });

  final AppUserProfile? current;
  final UserProfileService profileService;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.current?.displayName ?? profileMockName,
  );
  File? _selectedAvatar;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1200,
      );
      if (picked == null || !mounted) return;
      setState(() => _selectedAvatar = File(picked.path));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Không chọn được ảnh: $e')),
        );
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final profile = await widget.profileService.saveCurrentProfile(
        displayName: _nameController.text,
        avatarFile: _selectedAvatar,
      );
      if (!mounted) return;
      Navigator.of(context).pop(profile);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Chưa lưu được hồ sơ: $e')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Material(
        color: c.bgRaised,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    'Sửa hồ sơ',
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      color: c.ink,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Center(
                child: GestureDetector(
                  onTap: _pickAvatar,
                  child: _EditableAvatarPreview(
                    initial: widget.current?.initial ?? profileMockInitial,
                    avatarUrl: widget.current?.avatarUrl,
                    localAvatar: _selectedAvatar,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Tên hiển thị',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: const Text('Lưu thay đổi'),
              ),
              TextButton.icon(
                onPressed: _pickAvatar,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Đổi ảnh đại diện'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// EDIT AVATAR PREVIEW
// ═══════════════════════════════════════════════════════════════

class _EditableAvatarPreview extends StatelessWidget {
  const _EditableAvatarPreview({
    required this.initial,
    this.avatarUrl,
    this.localAvatar,
  });

  final String initial;
  final String? avatarUrl;
  final File? localAvatar;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final local = localAvatar;
    final remote = avatarUrl;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            color: c.ink,
            shape: BoxShape.circle,
            border: Border.all(color: c.yellow, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          alignment: Alignment.center,
          child: local != null
              ? Image.file(local, fit: BoxFit.cover, width: 92, height: 92)
              : remote != null
                  ? Image.network(
                      remote,
                      fit: BoxFit.cover,
                      width: 92,
                      height: 92,
                      errorBuilder: (_, __, ___) =>
                          _AvatarInitial(initial: initial),
                    )
                  : _AvatarInitial(initial: initial),
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: c.yellow,
              shape: BoxShape.circle,
              border: Border.all(color: c.bgRaised, width: 2),
            ),
            child: Icon(
              Icons.photo_camera_outlined,
              size: 15,
              color: c.yellowInk,
            ),
          ),
        ),
      ],
    );
  }
}

class _AvatarInitial extends StatelessWidget {
  const _AvatarInitial({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Text(
      initial,
      style: TextStyle(
        fontFamily: 'BeVietnamPro',
        fontSize: 28,
        fontWeight: FontWeight.w800,
        fontStyle: FontStyle.italic,
        color: c.yellow,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// STICKY PILL BAR — slides in after the user scrolls past the hero.
// Carries V medallion + name + "Hồ sơ" descriptor.
// ═══════════════════════════════════════════════════════════════

class _StickyPillBar extends StatelessWidget {
  const _StickyPillBar({
    required this.visible,
    required this.userInitial,
    required this.name,
    required this.onTap,
    this.avatarUrl,
  });

  final bool visible;
  final String userInitial;
  final String? avatarUrl;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final topInset = MediaQuery.viewPaddingOf(context).top;
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, -1.4),
        duration: const Duration(milliseconds: 340),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
          child: Container(
            padding: EdgeInsets.fromLTRB(14, topInset + 10, 14, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  c.bg.withValues(alpha: 0.96),
                  c.bg.withValues(alpha: 0.78),
                  c.bg.withValues(alpha: 0),
                ],
                stops: const [0.0, 0.7, 1.0],
              ),
            ),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onTap();
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: c.bgRaised,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: c.borderHi, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: c.ink.withValues(alpha: 0.14),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: c.ink.withValues(alpha: 0.05),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: c.bgInverse,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.yellow, width: 1.5),
                      ),
                      clipBehavior: Clip.antiAlias,
                      alignment: Alignment.center,
                      child: avatarUrl == null
                          ? _StickyAvatarInitial(initial: userInitial)
                          : Image.network(
                              avatarUrl!,
                              fit: BoxFit.cover,
                              width: 34,
                              height: 34,
                              errorBuilder: (_, __, ___) =>
                                  _StickyAvatarInitial(initial: userInitial),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'HỒ SƠ',
                            style: TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.6,
                              color: c.inkFaint,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$name.',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              fontStyle: FontStyle.italic,
                              letterSpacing: -0.3,
                              color: c.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: c.ink,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Lên đầu',
                            style: TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              fontStyle: FontStyle.italic,
                              letterSpacing: -0.1,
                              color: c.invInk,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_up_rounded,
                            size: 14,
                            color: c.invInkSoft,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StickyAvatarInitial extends StatelessWidget {
  const _StickyAvatarInitial({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Text(
      initial,
      style: TextStyle(
        fontFamily: 'BeVietnamPro',
        fontSize: 14,
        fontWeight: FontWeight.w800,
        fontStyle: FontStyle.italic,
        letterSpacing: -0.6,
        color: c.yellow,
        height: 1,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CLOSER — editorial sign-off + back-to-top pill.
// ═══════════════════════════════════════════════════════════════

class _Closer extends StatelessWidget {
  const _Closer({required this.onBackToTop, required this.version});
  final VoidCallback onBackToTop;
  final String version;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Container(height: 1, color: c.border)),
              const SizedBox(width: 14),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: c.yellow,
                  borderRadius: BorderRadius.circular(5),
                ),
                alignment: Alignment.center,
                child: Text(
                  'V',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: c.ink,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'VIKA · HỒ SƠ',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                  color: c.inkSoft,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: Container(height: 1, color: c.border)),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Cảm ơn vì đã tin Vika.',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                        letterSpacing: -0.3,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Mỗi tuần Vika thêm bài mới · $version',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: c.inkFaint,
                        letterSpacing: -0.1,
                        fontFeatures: VikaIvoryMain.tabularFigures,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _BackToTopButton(onTap: onBackToTop),
            ],
          ),
        ],
      ),
    );
  }
}

class _BackToTopButton extends StatefulWidget {
  const _BackToTopButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_BackToTopButton> createState() => _BackToTopButtonState();
}

class _BackToTopButtonState extends State<_BackToTopButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 0, 6, 0),
          height: 40,
          decoration: BoxDecoration(
            color: c.ink,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Lên đầu',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -0.2,
                  color: c.invInk,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: c.yellow,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.arrow_upward_rounded,
                  size: 14,
                  color: c.yellowInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
