import 'package:flutter/material.dart';

import 'package:vika/services/analytics_service.dart';

import '../v5_primitives.dart';
import '../v5_theme.dart';

class S06Trust extends StatefulWidget {
  const S06Trust({super.key, required this.onNext, required this.onBack});

  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  State<S06Trust> createState() => _S06TrustState();
}

class _S06TrustState extends State<S06Trust> {
  static const _sections = <_PolicySection>[
    _PolicySection(
      number: '01',
      title: 'Camera & xử lý tại thiết bị',
      body: 'Mọi xử lý video chạy ngay trên máy của bạn. Vika không tải video '
          'lên máy chủ, không lưu lại sau khi phân tích và không có ai xem video. '
          'Chỉ kết quả phân tích (góc khớp, số rep, điểm form) được lưu để theo dõi.',
    ),
    _PolicySection(
      number: '02',
      title: 'Dữ liệu thu thập',
      body:
          'Tên, email, ảnh đại diện khi đăng ký. Thông số bạn tự khai (giới tính, '
          'tuổi, chiều cao, cân nặng, vùng đau, mục tiêu). Lịch sử tập và kết quả '
          'phân tích chuyển động. Thông tin thiết bị để cải thiện hiệu năng. '
          'Cách bạn dùng ứng dụng (thao tác, bước hoàn thành, thời gian sử dụng), '
          'gắn với tài khoản để cải thiện trải nghiệm.',
    ),
    _PolicySection(
      number: '03',
      title: 'Mục đích sử dụng',
      body:
          'Tạo & quản lý tài khoản. Cung cấp bài tập, phân tích tư thế, phản hồi. '
          'Cá nhân hoá lộ trình. Liên lạc về cập nhật, nhắc lịch, hỗ trợ. '
          'Vika KHÔNG bán dữ liệu, không chia sẻ cho quảng cáo, không nhắm mục tiêu quảng cáo.',
    ),
    _PolicySection(
      number: '04',
      title: 'Bên thứ ba',
      body:
          'Supabase (Singapore) lưu tài khoản và kết quả tập. MediaPipe của Google '
          'chạy nhận diện tư thế ngay trên máy bạn, không gửi gì cho Google. '
          'Apple / Google chỉ dùng để đăng nhập. PostHog (EU) phân tích '
          'cách bạn dùng ứng dụng, gắn với tài khoản của bạn, để cải thiện sản phẩm.',
    ),
    _PolicySection(
      number: '05',
      title: 'Bảo mật & lưu trữ',
      body:
          'Dữ liệu truyền qua HTTPS mã hoá. Mật khẩu luôn được mã hoá, không lưu '
          'dạng thuần. Khi bạn xoá tài khoản, dữ liệu được xoá trong 30 ngày '
          '(trừ các nghĩa vụ kế toán, thuế theo luật).',
    ),
    _PolicySection(
      number: '06',
      title: 'Quyền của bạn',
      body:
          'Theo Luật 91/2025/QH15, bạn có quyền truy cập, chỉnh sửa, xoá dữ liệu, '
          'rút lại đồng ý, yêu cầu bản sao dữ liệu, phản đối xử lý và khiếu nại. '
          'Liên hệ vikavn.app@gmail.com để thực hiện các quyền này.',
    ),
    _PolicySection(
      number: '07',
      title: 'Trẻ em',
      body:
          'Vika chỉ dành cho người từ 16 tuổi trở lên. Nếu phát hiện tài khoản '
          'dưới 16 tuổi, tài khoản đó sẽ bị xoá trong vòng 7 ngày.',
    ),
    _PolicySection(
      number: '08',
      title: 'Liên hệ',
      body:
          'Trần Tuấn Kiệt — Đơn vị kiểm soát dữ liệu. Email: support@vikavn.app. '
          'Điện thoại: 0566665536. Khiếu nại có thể gửi tới Cục An ninh mạng và '
          'PCTP công nghệ cao (A05), hotline 1800 4040.',
    ),
  ];

  bool _accepted = false;

  /// The CTA is only enabled once [_accepted] is true, so reaching here means
  /// the user has read and accepted the S06 privacy policy — which explicitly
  /// covers PostHog analytics. That acceptance IS the analytics consent: grant
  /// it (persists the flag + opts PostHog in) before advancing, so the very
  /// next onboarding step is the first thing allowed to be captured.
  Future<void> _acceptAndContinue() async {
    await AnalyticsService.instance.grantConsent();
    if (!mounted) return;
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final r = V5Responsive.of(context);
    final dense = r.isNarrow || r.isVeryShort;
    return V5Page(
      index: 8,
      onBack: widget.onBack,
      cta: V5PillCTA(
        label: 'Đồng ý & tiếp tục',
        disabledLabel: 'Đọc & đồng ý để tiếp tục',
        enabled: _accepted,
        onTap: _acceptAndContinue,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              V5ScreenHeader(
                eyebrow: 'An toàn & riêng tư',
                title: 'Trước khi bật\ncamera.',
                size: dense ? V5HeaderSize.medium : V5HeaderSize.large,
              ),
              SizedBox(height: r.pick(cozy: V5.space10, short: V5.space8)),
              Expanded(
                child: V5FadeIn(
                  delay: const Duration(milliseconds: 160),
                  slideY: 10,
                  child: _PolicyCard(sections: _sections, dense: dense),
                ),
              ),
              SizedBox(height: r.pick(cozy: V5.space10, short: V5.space8)),
              V5FadeIn(
                delay: const Duration(milliseconds: 260),
                slideY: 8,
                child: _AcceptRow(
                  accepted: _accepted,
                  onToggle: () => setState(() => _accepted = !_accepted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Policy card — scrollable, premium editorial feel
// ─────────────────────────────────────────────────────────────

class _PolicyCard extends StatefulWidget {
  const _PolicyCard({required this.sections, this.dense = false});

  final List<_PolicySection> sections;
  final bool dense;

  @override
  State<_PolicyCard> createState() => _PolicyCardState();
}

class _PolicyCardState extends State<_PolicyCard> {
  final _scroll = ScrollController();
  bool _atTop = true;
  bool _atBottom = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleScroll());
  }

  void _handleScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    final top = pos.pixels <= 2;
    final bottom = pos.pixels >= pos.maxScrollExtent - 2;
    if (top != _atTop || bottom != _atBottom) {
      setState(() {
        _atTop = top;
        _atBottom = bottom;
      });
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_handleScroll);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: V5.surface,
        borderRadius: BorderRadius.circular(V5.radiusLg),
        border: Border.all(color: V5.border),
        boxShadow: V5.elevation1,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(V5.radiusLg),
        child: Column(
          children: [
            _PolicyHeader(dense: widget.dense),
            Container(height: 1, color: V5.border),
            Expanded(
              child: Stack(
                children: [
                  ScrollConfiguration(
                    behavior: const _NoGlowBehavior(),
                    child: ListView.separated(
                      controller: _scroll,
                      padding: EdgeInsets.fromLTRB(
                        widget.dense ? 14 : 18,
                        widget.dense ? 14 : 18,
                        widget.dense ? 14 : 18,
                        widget.dense ? 18 : 22,
                      ),
                      itemCount: widget.sections.length,
                      separatorBuilder: (_, __) => SizedBox(
                        height: widget.dense ? V5.space10 : V5.space14,
                      ),
                      itemBuilder: (context, i) =>
                          _PolicySectionTile(section: widget.sections[i]),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 18,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: _atTop ? 0 : 1,
                        duration: const Duration(milliseconds: 180),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                V5.surface,
                                V5.surface.withValues(alpha: 0)
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 22,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: _atBottom ? 0 : 1,
                        duration: const Duration(milliseconds: 180),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                V5.surface,
                                V5.surface.withValues(alpha: 0)
                              ],
                            ),
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
    );
  }
}

class _PolicyHeader extends StatelessWidget {
  const _PolicyHeader({this.dense = false});

  final bool dense;

  @override
  Widget build(BuildContext context) {
    final iconSize = dense ? 32.0 : 38.0;
    return Container(
      padding: EdgeInsets.fromLTRB(
        dense ? 14 : 18,
        dense ? 12 : 14,
        dense ? 14 : 18,
        dense ? 12 : 14,
      ),
      decoration: const BoxDecoration(color: V5.surfaceRaised),
      child: Row(
        children: [
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: V5.yellow.withValues(alpha: 0.16),
              shape: BoxShape.circle,
              border: Border.all(color: V5.yellow.withValues(alpha: 0.38)),
            ),
            child: Icon(
              Icons.verified_user_outlined,
              size: dense ? 16 : 18,
              color: V5.ink,
            ),
          ),
          SizedBox(width: dense ? V5.space8 : V5.space10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Chính sách quyền riêng tư',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (dense ? V5.titleSm(context) : V5.title(context))
                      .copyWith(height: 1.15),
                ),
                const SizedBox(height: 2),
                Text(
                  'Hiệu lực 16 / 05 / 2026 • Vika',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: V5
                      .eyebrow(context, color: V5.inkSoft)
                      .copyWith(letterSpacing: 1.0),
                ),
              ],
            ),
          ),
          if (!dense) ...[
            const SizedBox(width: V5.space8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: V5.ink,
                borderRadius: BorderRadius.circular(V5.radiusFull),
              ),
              child: Text(
                'V1',
                style: V5
                    .eyebrow(context, color: V5.invInk)
                    .copyWith(letterSpacing: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PolicySectionTile extends StatelessWidget {
  const _PolicySectionTile({required this.section});

  final _PolicySection section;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: V5.ink,
            shape: BoxShape.circle,
            boxShadow: V5.elevation1,
          ),
          alignment: Alignment.center,
          child: Text(
            section.number,
            style: V5
                .eyebrow(context, color: V5.invInk)
                .copyWith(letterSpacing: 0.4, fontSize: 10),
          ),
        ),
        const SizedBox(width: V5.space10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                section.title,
                style: V5.titleSm(context).copyWith(height: 1.2),
              ),
              const SizedBox(height: V5.space4),
              Text(
                section.body,
                style: V5
                    .bodySm(context, color: V5.inkSoft)
                    .copyWith(height: 1.45),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AcceptRow extends StatelessWidget {
  const _AcceptRow({required this.accepted, required this.onToggle});

  final bool accepted;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: V5.curveSharp,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: accepted ? V5.yellow.withValues(alpha: 0.12) : V5.surface,
          borderRadius: BorderRadius.circular(V5.radiusMd),
          border: Border.all(
            color: accepted ? V5.yellow.withValues(alpha: 0.46) : V5.border,
          ),
          boxShadow: V5.elevation1,
        ),
        child: Row(
          children: [
            V5CheckCircle(selected: accepted, size: 22),
            const SizedBox(width: V5.space10),
            Expanded(
              child: Text(
                'Tôi đã đọc và đồng ý với toàn bộ chính sách quyền riêng tư trên.',
                style: V5.bodySm(context).copyWith(height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoGlowBehavior extends ScrollBehavior {
  const _NoGlowBehavior();

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

class _PolicySection {
  const _PolicySection({
    required this.number,
    required this.title,
    required this.body,
  });

  final String number;
  final String title;
  final String body;
}
