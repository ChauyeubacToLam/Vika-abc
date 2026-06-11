// ProfileScreen — the Hồ sơ tab. Premium Ivory v2 (cinematic).
//
// Architecture (top to bottom):
//   ▲ Stage hero — dark, full-bleed, italic name, edit/share pills
//   1. Mục tiêu — goal card with progress meter
//   5. Vóc dáng — refined body card + BMI chip
//   6. Mời bạn dùng Vika — referral card
//   7. Kết nối — connected services
//   8. Cài đặt — settings groups
//   9. Closer + back-to-top + version
//   ▼ Sticky pill bar (slides in after scroll past hero)

import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/profile_goal_quote.dart';
import '../data/profile_mock.dart';
import '../services/data_export_service.dart';
import '../services/recommendation/recommendation_service.dart';
import '../services/session_persistence.dart';
import '../services/streak_tier.dart';
import '../services/user_profile_service.dart';
import '../theme/app_colors.dart';
import '../theme/vf_theme.dart';
import '../utils/orientation_lock.dart';
import '../widgets/profile/body_card.dart';
import '../widgets/profile/body_edit_sheet.dart';
import '../widgets/profile/goal_card.dart';
import '../widgets/profile/goal_edit_sheet.dart';
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
  final _sessions = SessionPersistence();
  final _recommendations = RecommendationService();
  bool _showStickyBar = false;
  bool _showDownFab = false;
  bool _deleting = false;
  bool _exporting = false;
  AppUserProfile? _profile;

  // Lifetime aggregate from completed workout_sessions. Null until the first
  // fetch resolves; treated as "no history" (0 sessions) while null so the UI
  // never shows fake numbers before data arrives.
  ({
    int sessionCount,
    int totalSeconds,
    int? avgForm,
    int? formDeltaFromStart,
    int sessionsThisWeek,
  })? _lifetime;

  // Plan-derived goal progress (completion-anchored, not calendar).
  int _goalProgress = 0;
  String? _weeksLeftLabel; // "Còn N tuần nữa", null when no active plan
  String? _phaseLabel; // "TUẦN n / N", null when no active plan

  // Support contact + legal links. /terms and /support are not live yet, so
  // only the live privacy page is linked; support is handled over email.
  static const String _privacyUrl = 'https://vikavn.app/privacy';
  static const String _supportEmail = 'support@vikavn.app';

  static const double _stickyBarThreshold = 260;

  // How close to either end (in px) before the directional scroll FAB hides —
  // there's nowhere meaningful left to jump to.
  static const double _fabEdge = 140;

  @override
  void initState() {
    super.initState();
    unawaited(OrientationLock.portraitOnly());
    _scrollController.addListener(_onScroll);
    _profile = widget.userProfile;
    unawaited(_loadProfile());
    unawaited(_loadStats());
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
    final pos = _scrollController.position;
    final offset = pos.pixels;
    final shouldShow = offset > _stickyBarThreshold;

    // "Xuống cuối" FAB — only while heading down (the sticky bar up top already
    // covers going back to the top). Scrolling up hides it; near the bottom
    // there's nowhere left to jump, so it hides there too. On idle the last
    // state persists so the user can still tap after the flick settles.
    var showDown = _showDownFab;
    switch (pos.userScrollDirection) {
      case ScrollDirection.reverse:
        showDown = offset < pos.maxScrollExtent - _fabEdge;
      case ScrollDirection.forward:
        showDown = false;
      case ScrollDirection.idle:
        break;
    }

    if (shouldShow != _showStickyBar || showDown != _showDownFab) {
      setState(() {
        _showStickyBar = shouldShow;
        _showDownFab = showDown;
      });
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 560),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _loadProfile() async {
    final profile = await _profileService.fetchCurrentProfile();
    if (!mounted || profile == null) return;
    setState(() => _profile = profile);
    widget.onProfileChanged?.call(profile);
  }

  /// Loads the real lifetime aggregate + plan-derived goal progress. Both feed
  /// the staged display (empty / counts-only / full) so the tab never shows
  /// placeholder numbers.
  Future<void> _loadStats() async {
    final lifetime = await _sessions.lifetimeStats();

    var goalProgress = 0;
    String? weeksLeftLabel;
    String? phaseLabel;
    final snapshot =
        await _recommendations.fetchLatestActivePlanSnapshotForCurrentUser();
    if (snapshot != null) {
      final weeks = snapshot.plan.weeks;
      final totalWeeks = weeks.length;
      if (totalWeeks > 0) {
        // A week counts as done only when every one of its sessions is in the
        // completion map for that week.
        var completedWeeks = 0;
        for (final w in weeks) {
          final done = snapshot.completionMap[w.weekNumber] ?? const <int>{};
          final allDone = w.sessions.isNotEmpty &&
              w.sessions.every((s) => done.contains(s.sessionIndex));
          if (allDone) completedWeeks++;
        }
        goalProgress = ((completedWeeks / totalWeeks) * 100).round();
        weeksLeftLabel = 'Còn ${totalWeeks - completedWeeks} tuần nữa';
        final currentWeek = snapshot.currentWeek?.weekNumber;
        if (currentWeek != null) {
          phaseLabel = 'TUẦN $currentWeek / $totalWeeks';
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _lifetime = lifetime;
      _goalProgress = goalProgress;
      _weeksLeftLabel = weeksLeftLabel;
      _phaseLabel = phaseLabel;
    });
  }

  /// Compact uppercase hero strip. Empty for a brand-new user (0 sessions) so
  /// the strip is hidden rather than showing a placeholder. The streak chip is
  /// the tier duration label (e.g. 'CHUỖI 1 THÁNG'), dropped when there's no
  /// streak — never a raw count.
  List<String> _buildInlineStats() {
    final lt = _lifetime;
    if (lt == null || lt.sessionCount == 0) return const [];
    final stats = <String>[];
    final streakLabel = streakTierLabel(_profile?.streakWeeks ?? 0);
    if (streakLabel.isNotEmpty) stats.add('CHUỖI ${streakLabel.toUpperCase()}');
    stats.add('${lt.sessionCount} BUỔI');
    if (lt.avgForm != null) stats.add('${lt.avgForm}% FORM');
    return stats;
  }

  Future<void> _openEditProfileSheet() async {
    final result = await showModalBottomSheet<_EditProfileResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _EditProfileSheet(
        current: _profile,
        profileService: _profileService,
      ),
    );
    if (!mounted || result == null) return;
    setState(() => _profile = result.profile);
    widget.onProfileChanged?.call(result.profile);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            result.emailChangePending
                ? 'Đã lưu. Kiểm tra hộp thư email mới để xác nhận thay đổi.'
                : 'Đã cập nhật hồ sơ.',
          ),
        ),
      );
  }

  // ─── Goal editor (GoalCard "Sửa") ─────────────────────────────────────
  Future<void> _openGoalEditSheet() async {
    await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GoalEditSheet(
        currentGoal: _profile?.goal,
        onSave: (goal) async {
          final updated = await _profileService.updateProfileFields(goal: goal);
          if (updated == null) return false;
          if (!mounted) return true;
          setState(() => _profile = updated);
          widget.onProfileChanged?.call(updated);
          return true;
        },
      ),
    );
  }

  // ─── Body stats editor (BodyCard "Sửa") ───────────────────────────────
  Future<void> _openBodyEditSheet() async {
    await showModalBottomSheet<BodyStats>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BodyEditSheet(
        currentHeight: _profile?.heightCm,
        currentWeight: _profile?.weightKg,
        currentAge: _profile?.age,
        onSave: (stats) async {
          final updated = await _profileService.updateProfileFields(
            heightCm: stats.height,
            weightKg: stats.weight,
            age: stats.age,
          );
          if (updated == null) return false;
          if (!mounted) return true;
          setState(() => _profile = updated);
          widget.onProfileChanged?.call(updated);
          return true;
        },
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await _showConfirmDialog(
      icon: Icons.logout_rounded,
      eyebrow: 'TÀI KHOẢN',
      title: 'Đăng xuất?',
      body: 'Bạn sẽ quay về màn hình đăng nhập. Tiến trình của bạn vẫn '
          'được giữ khi đăng nhập lại.',
      confirmLabel: 'Đăng xuất',
    );
    if (!confirmed || !mounted) return;

    final rootNavigator = Navigator.of(context, rootNavigator: true);
    try {
      await Supabase.instance.client.auth.signOut();
      if (!rootNavigator.mounted) return;
      rootNavigator.pushNamedAndRemoveUntil(
        '/',
        (route) => false,
        arguments: const {'entryState': 'login'},
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Chưa đăng xuất được: $e')),
        );
    }
  }

  // ─── Delete account (Apple 5.1.1(v) hard gate) ────────────────────────
  Future<void> _confirmDeleteAccount() async {
    if (_deleting) return;

    final confirmed = await _showConfirmDialog(
      icon: Icons.delete_outline_rounded,
      eyebrow: 'XÓA TÀI KHOẢN',
      title: 'Xóa tài khoản?',
      body: 'Toàn bộ dữ liệu của bạn sẽ bị xóa vĩnh viễn và không thể '
          'khôi phục.',
      confirmLabel: 'Xóa vĩnh viễn',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    // Guard against a double-tap while the request is in flight.
    if (_deleting) return;
    setState(() => _deleting = true);

    final messenger = ScaffoldMessenger.of(context);
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final client = Supabase.instance.client;

    // The edge function is the real deletion. If it fails, surface the error
    // and let the user retry — nothing has changed.
    try {
      await client.functions.invoke('delete-account');
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Chưa xóa được tài khoản, thử lại sau.')),
        );
      return;
    }

    // Account is gone server-side. Everything below is best-effort cleanup —
    // its failure must not read as "delete failed". Sign out locally (the
    // server session no longer exists), clear the local onboarding flag so the
    // app starts as a brand-new user, then route to a fresh onboarding.
    try {
      await client.auth.signOut(scope: SignOutScope.local);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('onboarding_complete');
    } catch (_) {}

    if (!rootNavigator.mounted) return;
    rootNavigator.pushNamedAndRemoveUntil(
      '/',
      (route) => false,
      arguments: const {
        'entryState': 'onboarding',
        'onboardingComplete': false,
      },
    );
  }

  // ─── Data export (Tải dữ liệu của bạn) ────────────────────────────────
  Future<void> _exportData() async {
    if (_exporting) return;
    setState(() => _exporting = true);

    final messenger = ScaffoldMessenger.of(context);
    try {
      final json = await DataExportService().buildExportJson();
      if (!mounted) return;
      if (json == null) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Hãy đăng nhập để tải dữ liệu.')),
          );
        return;
      }
      // Write to a real .json file and share *that*, not raw text — only a
      // file lets the user "Lưu vào Files"/Drive, i.e. actually download it.
      final dir = await Directory.systemTemp.createTemp('vika_export');
      final file = File('${dir.path}/vika_data.json');
      await file.writeAsString(json);
      if (!mounted) return;

      // iPad needs an anchor rect for the share popover.
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [
          XFile(
            file.path,
            mimeType: 'application/json',
            name: 'vika_data.json',
          ),
        ],
        subject: 'Dữ liệu Vika của bạn',
        sharePositionOrigin:
            box != null ? box.localToGlobal(Offset.zero) & box.size : null,
      );
    } catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Chưa tải được dữ liệu, thử lại sau.')),
        );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ─── Help & feedback — opens the user's mail app to support ────────────
  Future<void> _openSupportMail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: {'subject': 'Phản hồi về Vika'},
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Hãy gửi phản hồi tới $_supportEmail'),
          ),
        );
    }
  }

  Future<void> _openExternal(String url) async {
    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Chưa mở được liên kết, thử lại sau.')),
        );
    }
  }

  // ─── About Vika — privacy link + version ──────────────────────────────
  Future<void> _showAboutSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final c = VikaColors.of(sheetContext);
        return _InfoSheet(
          eyebrow: 'VỀ VIKA',
          title: 'VIKA',
          body:
              'Người bạn đồng hành tập luyện thông minh. Cảm ơn bạn đã tin Vika '
              'trên hành trình khoẻ mạnh hơn mỗi ngày.',
          version: profileMockVersion,
          actions: [
            _InfoSheetAction(
              icon: Icons.shield_outlined,
              label: 'Chính sách quyền riêng tư',
              onTap: () {
                Navigator.of(sheetContext).pop();
                unawaited(_openExternal(_privacyUrl));
              },
            ),
            _InfoSheetAction(
              icon: Icons.mail_outline_rounded,
              label: 'Liên hệ hỗ trợ',
              onTap: () {
                Navigator.of(sheetContext).pop();
                unawaited(_openSupportMail());
              },
            ),
          ],
          accent: c.phase2,
        );
      },
    );
  }

  // ─── Camera privacy explainer ─────────────────────────────────────────
  Future<void> _showCameraInfoSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final c = VikaColors.of(sheetContext);
        return _InfoSheet(
          eyebrow: 'QUYỀN RIÊNG TƯ',
          title: 'Camera xử lý trong máy',
          body: 'Hình ảnh xử lý ngay trên máy, không gửi đi đâu cả.',
          accent: c.phase4,
        );
      },
    );
  }

  // ─── Premium Ivory confirm dialog ─────────────────────────────────────
  // Replaces the stock AlertDialog for the destructive account actions so the
  // moment of decision feels intentional and on-brand: blurred backdrop,
  // gradient card, accent medallion, italic display title.
  Future<bool> _showConfirmDialog({
    required IconData icon,
    required String eyebrow,
    required String title,
    required String body,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Đóng',
      barrierColor: const Color(0xCC0F0A06),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (dialogContext, _, __) => _ConfirmDialog(
        icon: icon,
        eyebrow: eyebrow,
        title: title,
        body: body,
        confirmLabel: confirmLabel,
        destructive: destructive,
      ),
      transitionBuilder: (context, animation, _, child) {
        final t = Curves.easeOutCubic.transform(
          animation.value.clamp(0.0, 1.0),
        );
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 7 * t, sigmaY: 7 * t),
          child: Opacity(
            opacity: t,
            child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
          ),
        );
      },
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final profile = _profile;
    final displayName = profile?.displayName ?? profileMockName;
    final userInitial = profile?.initial ?? profileMockInitial;
    final avatarUrl = profile?.avatarUrl;
    final streakLabel = streakTierLabel(profile?.streakWeeks ?? 0);
    final memberSince = profile?.memberSinceLabel ?? profileMockMemberSince;
    final memberSinceLine = streakLabel.isEmpty
        ? 'Thành viên từ $memberSince'
        : 'Thành viên từ $memberSince · chuỗi $streakLabel';
    // Body stats stay null when unknown — BodyCard renders "—", never a fake
    // number.
    final height = profile?.heightCm;
    final weight = profile?.weightKg;
    final age = profile?.age;
    final bmi = profile?.bmiValue != null ? profile!.bmiLabel : null;
    final bmiCategory = profile?.bmiCategory ?? 'Chưa đủ dữ liệu';

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
                    phaseLabel: _phaseLabel,
                    memberSinceLine: memberSinceLine,
                    goalProgress: _goalProgress,
                    inlineStats: _buildInlineStats(),
                    onEdit: _openEditProfileSheet,
                    onEditPhoto: _openEditProfileSheet,
                  ),
                  const SizedBox(height: 24),

                  // 1. Mục tiêu — goal card with progress meter.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GoalCard(
                      title: goalTitleFor(profile?.goal),
                      quote: goalQuoteFor(profile?.goal),
                      progress: _goalProgress,
                      daysLeft: _weeksLeftLabel,
                      onEdit: _openGoalEditSheet,
                    ),
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
                      onEdit: _openBodyEditSheet,
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
                          label: 'Quyền riêng tư',
                          accentColor: c.phase4,
                          rows: [
                            SettingRow(
                              icon: Icons.shield_outlined,
                              label: 'Camera xử lý trong máy',
                              sub: 'Hình ảnh không rời thiết bị',
                              accentColor: c.phase4,
                              onTap: _showCameraInfoSheet,
                            ),
                            SettingRow(
                              icon: Icons.download_rounded,
                              label: 'Tải dữ liệu của bạn',
                              sub: _exporting ? 'Đang chuẩn bị...' : null,
                              accentColor: c.phase4,
                              onTap: _exporting ? null : _exportData,
                            ),
                          ],
                        ),
                        SettingsGroup(
                          label: 'Hỗ trợ',
                          accentColor: c.phase2,
                          rows: [
                            SettingRow(
                              icon: Icons.help_outline_rounded,
                              label: 'Trợ giúp & Phản hồi',
                              accentColor: c.phase2,
                              onTap: _openSupportMail,
                            ),
                            SettingRow(
                              icon: Icons.info_outline_rounded,
                              label: 'Về Vika',
                              sub: profileMockVersion,
                              accentColor: c.phase2,
                              onTap: _showAboutSheet,
                            ),
                          ],
                        ),
                        SettingsGroup(
                          label: 'Tài khoản',
                          accentColor: c.phase3,
                          rows: [
                            SettingRow(
                              icon: Icons.person_outline_rounded,
                              label: 'Sửa hồ sơ',
                              sub: displayName,
                              accentColor: c.phase3,
                              onTap: _openEditProfileSheet,
                            ),
                            if (profile?.email != null)
                              // Display-only — changing email is an auth flow,
                              // out of scope. No chevron, no tap.
                              SettingRow(
                                icon: Icons.alternate_email_rounded,
                                label: 'Email',
                                sub: profile!.email,
                                accentColor: c.phase3,
                                showChevron: false,
                              ),
                            SettingRow(
                              icon: Icons.logout_rounded,
                              label: 'Đăng xuất',
                              danger: true,
                              onTap: _confirmSignOut,
                            ),
                            SettingRow(
                              icon: Icons.delete_outline_rounded,
                              label: 'Xóa tài khoản',
                              danger: true,
                              onTap: _deleting ? null : _confirmDeleteAccount,
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
            _ScrollDownFab(
              visible: _showDownFab,
              bottomInset: widget.bottomPadding,
              onTap: _scrollToBottom,
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
    this.intro,
  });

  final String eyebrow;
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
// INFO SHEET — small Premium Ivory bottom sheet for read-only
// explainers (About Vika, camera privacy). Optional version line +
// optional action rows (external links / mail).
// ═══════════════════════════════════════════════════════════════

class _InfoSheet extends StatelessWidget {
  const _InfoSheet({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.accent,
    this.version,
    this.actions = const [],
  });

  final String eyebrow;
  final String title;
  final String body;
  final Color accent;
  final String? version;
  final List<_InfoSheetAction> actions;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final sheetTint = Color.lerp(c.bgRaised, accent, c.isDark ? 0.10 : 0.055)!;
    final outline = Color.lerp(c.border, accent, c.isDark ? 0.28 : 0.34)!;
    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: MediaQuery.viewPaddingOf(context).bottom + 12,
      ),
      child: Material(
        color: Colors.transparent,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [c.bgRaised, sheetTint],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: outline),
            boxShadow: [
              BoxShadow(
                color: c.ink.withValues(alpha: c.isDark ? 0.30 : 0.12),
                blurRadius: 42,
                offset: const Offset(0, 22),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.borderHi,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 5,
                      height: 18,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      eyebrow,
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                        color: c.inkSoft,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -0.7,
                    color: c.ink,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  body,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                    color: c.inkSoft,
                  ),
                ),
                if (version != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    version!,
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                      color: c.inkFaint,
                      fontFeatures: VikaIvoryMain.tabularFigures,
                    ),
                  ),
                ],
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  for (final action in actions) ...[
                    action,
                    if (action != actions.last) const SizedBox(height: 10),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoSheetAction extends StatelessWidget {
  const _InfoSheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: c.bg.withValues(alpha: c.isDark ? 0.28 : 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: c.inkSoft),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                    color: c.ink,
                  ),
                ),
              ),
              Icon(Icons.north_east_rounded, size: 16, color: c.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// EDIT PROFILE SHEET — owns its TextEditingController + selected
// avatar file so the lifecycle is bound to this widget, not to a
// parent async function.
// ═══════════════════════════════════════════════════════════════

/// Result of the edit-profile sheet. [emailChangePending] is true when the
/// user requested a new email (which only takes effect after they confirm the
/// link Supabase mails them), so the caller can show the right message.
class _EditProfileResult {
  const _EditProfileResult({
    required this.profile,
    required this.emailChangePending,
  });

  final AppUserProfile profile;
  final bool emailChangePending;
}

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
  late final TextEditingController _emailController = TextEditingController(
    text: widget.current?.email ?? '',
  );
  File? _selectedAvatar;
  late String? _gender = widget.current?.gender;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

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

    // Only request an email change when the field actually differs from the
    // current address. Validate it client-side so we don't fire a doomed
    // auth call on an obvious typo.
    final currentEmail = widget.current?.email ?? '';
    final newEmail = _emailController.text.trim();
    final emailChanged = newEmail.isNotEmpty && newEmail != currentEmail;
    if (emailChanged && !_emailPattern.hasMatch(newEmail)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Email chưa hợp lệ.')),
        );
      return;
    }

    setState(() => _saving = true);
    try {
      final profile = await widget.profileService.saveCurrentProfile(
        displayName: _nameController.text,
        avatarFile: _selectedAvatar,
        email: emailChanged ? newEmail : null,
        gender: _gender,
      );
      if (!mounted) return;
      Navigator.of(context).pop(
        profile == null
            ? null
            : _EditProfileResult(
                profile: profile,
                emailChangePending: emailChanged,
              ),
      );
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
    final accent = c.phase3;
    final sheetTint = Color.lerp(c.bgRaised, accent, c.isDark ? 0.10 : 0.055)!;
    final fieldFill = Color.lerp(c.bg, c.bgRaised, c.isDark ? 0.20 : 0.58)!;
    final outline = Color.lerp(c.border, accent, c.isDark ? 0.28 : 0.34)!;
    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
      ),
      child: Material(
        color: Colors.transparent,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [c.bgRaised, sheetTint],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: outline),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: c.isDark ? 0.14 : 0.16),
                blurRadius: 34,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: c.ink.withValues(alpha: c.isDark ? 0.30 : 0.12),
                blurRadius: 42,
                offset: const Offset(0, 22),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.borderHi,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: c.isDark ? 0.16 : 0.12),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.34),
                        ),
                      ),
                      child: Icon(
                        Icons.person_outline_rounded,
                        size: 18,
                        color: Color.lerp(
                          accent,
                          c.ink,
                          c.isDark ? 0.06 : 0.34,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hồ sơ',
                            style: TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                              color: c.inkSoft,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Sửa thông tin',
                            style: TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              fontStyle: FontStyle.italic,
                              letterSpacing: -0.7,
                              color: c.ink,
                              height: 1.05,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: c.bg.withValues(alpha: 0.72),
                        foregroundColor: c.ink,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
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
                const SizedBox(height: 18),
                TextField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  cursorColor: accent,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: c.ink,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Tên hiển thị',
                    labelStyle: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontWeight: FontWeight.w700,
                      color: c.inkSoft,
                    ),
                    prefixIcon: Icon(
                      Icons.badge_outlined,
                      size: 18,
                      color: accent,
                    ),
                    filled: true,
                    fillColor: fieldFill,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 16),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: c.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: accent, width: 1.4),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autocorrect: false,
                  cursorColor: accent,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: c.ink,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Email',
                    helperText: 'Đổi email cần xác nhận qua hộp thư mới.',
                    helperStyle: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: c.inkFaint,
                    ),
                    labelStyle: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontWeight: FontWeight.w700,
                      color: c.inkSoft,
                    ),
                    prefixIcon: Icon(
                      Icons.alternate_email_rounded,
                      size: 18,
                      color: accent,
                    ),
                    filled: true,
                    fillColor: fieldFill,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 16),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: c.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: accent, width: 1.4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _GenderSelectField(
                  selected: _gender,
                  accent: accent,
                  fieldFill: fieldFill,
                  onSelect: (id) {
                    HapticFeedback.selectionClick();
                    setState(() => _gender = id);
                  },
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: c.yellow,
                      disabledBackgroundColor: c.yellowGhost,
                      foregroundColor: c.yellowInk,
                      disabledForegroundColor: c.inkSoft,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: c.yellowInk,
                            ),
                          )
                        : const Icon(Icons.check_rounded),
                    label: const Text('Lưu thay đổi'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: c.ink,
                    textStyle: const TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onPressed: _saving ? null : _pickAvatar,
                  icon: Icon(
                    Icons.photo_camera_outlined,
                    size: 17,
                    color: accent,
                  ),
                  label: const Text('Đổi ảnh đại diện'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// GENDER SELECT — segmented pills, accent-themed to the identity sheet
// ═══════════════════════════════════════════════════════════════

/// Premium gender picker for the identity editor. Four options as soft pills
/// that reflow (the wide 'Không muốn trả lời' drops to its own run, capped to
/// the line width so it can't overflow). Selected = warm-ink fill with an
/// accent hairline, a reserved-yellow glyph, and a soft lift — matching the
/// sheet's field rhythm without shouting.
class _GenderSelectField extends StatelessWidget {
  const _GenderSelectField({
    required this.selected,
    required this.onSelect,
    required this.accent,
    required this.fieldFill,
  });

  final String? selected;
  final ValueChanged<String> onSelect;
  final Color accent;
  final Color fieldFill;

  static const _options = <({String id, String label, IconData icon})>[
    (id: 'male', label: 'Nam', icon: Icons.male_rounded),
    (id: 'female', label: 'Nữ', icon: Icons.female_rounded),
    (id: 'other', label: 'Khác', icon: Icons.transgender_rounded),
    (
      id: 'prefer_not_to_say',
      label: 'Không muốn trả lời',
      icon: Icons.visibility_off_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Row(
            children: [
              Icon(Icons.wc_rounded, size: 18, color: accent),
              const SizedBox(width: 8),
              Text(
                'Giới tính',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: c.inkSoft,
                ),
              ),
            ],
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              for (final o in _options)
                _GenderPill(
                  label: o.label,
                  icon: o.icon,
                  selected: selected == o.id,
                  maxWidth: constraints.maxWidth,
                  accent: accent,
                  fieldFill: fieldFill,
                  onTap: () => onSelect(o.id),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GenderPill extends StatelessWidget {
  const _GenderPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.maxWidth,
    required this.accent,
    required this.fieldFill,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final double maxWidth;
  final Color accent;
  final Color fieldFill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [c.ink, Color.lerp(c.ink, accent, 0.22)!],
                  )
                : null,
            color: selected ? null : fieldFill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? accent.withValues(alpha: 0.55) : c.border,
              width: selected ? 1.4 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: c.ink.withValues(alpha: c.isDark ? 0.40 : 0.20),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? c.yellow : c.inkSoft,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: selected ? c.invInk : c.ink,
                  ),
                ),
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
    final hasImage = local != null || remote != null;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: c.ink,
            shape: BoxShape.circle,
            border: hasImage ? null : Border.all(color: c.yellow, width: 2),
            boxShadow: [
              BoxShadow(
                color: c.ink.withValues(alpha: c.isDark ? 0.34 : 0.18),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          alignment: Alignment.center,
          child: local != null
              ? Image.file(local, fit: BoxFit.cover, width: 96, height: 96)
              : remote != null
                  ? Image.network(
                      remote,
                      fit: BoxFit.cover,
                      width: 96,
                      height: 96,
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
              color: c.bgInverse,
              shape: BoxShape.circle,
              border: Border.all(color: c.bgRaised, width: 2),
            ),
            child: Icon(
              Icons.photo_camera_outlined,
              size: 15,
              color: c.yellow,
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
                        border: avatarUrl == null
                            ? Border.all(color: c.yellow, width: 1.5)
                            : null,
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
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: c.yellow,
                  shape: BoxShape.circle,
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

// ═══════════════════════════════════════════════════════════════
// SCROLL-DOWN FAB — a floating "Xuống cuối" pill that appears only
// while the user is scrolling down (going back up is handled by the
// sticky bar at the top). Lives bottom-right, clears the bottom nav,
// and slides away near the end of the list.
// ═══════════════════════════════════════════════════════════════

class _ScrollDownFab extends StatelessWidget {
  const _ScrollDownFab({
    required this.visible,
    required this.bottomInset,
    required this.onTap,
  });

  final bool visible;
  final double bottomInset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Positioned(
      right: 16,
      bottom: bottomInset + 16,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, 1.4),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: visible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                onTap();
              },
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 6, 0),
                height: 44,
                decoration: BoxDecoration(
                  color: c.ink,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: c.ink.withValues(alpha: c.isDark ? 0.5 : 0.24),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Xuống cuối',
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
                        Icons.arrow_downward_rounded,
                        size: 15,
                        color: c.yellowInk,
                      ),
                    ),
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

// ═══════════════════════════════════════════════════════════════
// CONFIRM DIALOG — Premium Ivory replacement for the stock AlertDialog on
// account actions. Built as a compact dark "stage hero": warm-dark gradient
// + ambient accent glow + medallion + italic display title + halo CTA. The
// accent is brand gold for normal actions, warm amber for destructive ones.
// ═══════════════════════════════════════════════════════════════

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.confirmLabel,
    this.destructive = false,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String body;
  final String confirmLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    // The dialog echoes the app's signature dark "stage hero": warm-dark
    // gradient, an ambient accent glow, italic display title, and the halo
    // CTA. Normal actions ride the brand gold; a destructive action swaps the
    // accent to the warm amber alarm — same composition, clearly graver.
    final accent = destructive ? c.attention : c.yellow;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: const Alignment(-0.7, -1),
                    end: const Alignment(0.7, 1),
                    colors: [c.bgInverse, c.bgInverseHi],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.22),
                      blurRadius: 44,
                      offset: const Offset(0, 18),
                    ),
                    BoxShadow(
                      color: c.ink.withValues(alpha: 0.5),
                      blurRadius: 54,
                      offset: const Offset(0, 28),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Ambient accent glow, top-right shoulder.
                    Positioned(
                      top: -80,
                      right: -70,
                      child: IgnorePointer(
                        child: _DialogGlow(color: accent, opacity: 0.24),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(26, 28, 26, 22),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Accent medallion with a soft glow.
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: accent.withValues(alpha: 0.5),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withValues(alpha: 0.32),
                                    blurRadius: 20,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Icon(icon, size: 25, color: accent),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Eyebrow with accent tick.
                          Row(
                            children: [
                              Container(
                                width: 5,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: accent,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 9),
                              Text(
                                eyebrow,
                                style: TextStyle(
                                  fontFamily: 'BeVietnamPro',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.8,
                                  color: c.invInkSoft,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            title,
                            style: TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              fontStyle: FontStyle.italic,
                              letterSpacing: -0.8,
                              color: c.invInk,
                              height: 1.02,
                            ),
                          ),
                          const SizedBox(height: 11),
                          Text(
                            body,
                            style: TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              height: 1.55,
                              color: c.invInkSoft,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _DialogConfirmButton(
                            label: confirmLabel,
                            accent: accent,
                            onTap: () => Navigator.of(context).pop(true),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 46,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: c.invInkSoft,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                textStyle: const TextStyle(
                                  fontFamily: 'BeVietnamPro',
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Ở lại'),
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
        ),
      ),
    );
  }
}

/// Soft radial accent glow painted behind the confirm-dialog content.
class _DialogGlow extends StatelessWidget {
  const _DialogGlow({required this.color, required this.opacity});

  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 240,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

/// Halo CTA pill with a press-scale and an arrow knob — mirrors the home
/// hero's start button so the confirm action feels first-class.
class _DialogConfirmButton extends StatefulWidget {
  const _DialogConfirmButton({
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  State<_DialogConfirmButton> createState() => _DialogConfirmButtonState();
}

class _DialogConfirmButtonState extends State<_DialogConfirmButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: Container(
          height: 54,
          padding: const EdgeInsets.fromLTRB(22, 0, 6, 0),
          decoration: BoxDecoration(
            color: widget.accent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: widget.accent.withValues(alpha: 0.36),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: widget.accent.withValues(alpha: 0.18),
                blurRadius: 60,
                offset: const Offset(0, 26),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: c.yellowInk,
                  ),
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c.ink,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: widget.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
