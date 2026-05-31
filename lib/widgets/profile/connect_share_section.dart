// ConnectShareSection — peer-level section with two concerns that
// used to be buried in settings:
//   1. The referral / invite-a-friend moment (big editorial card)
//   2. Service integrations (Apple Health, Google Fit, Strava)
//
// Both reward sharing — they belong above the settings list, not
// inside it.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/profile_mock.dart';
import '../../theme/app_colors.dart';
import '../../theme/vf_theme.dart';

class ReferralCard extends StatefulWidget {
  const ReferralCard({
    super.key,
    required this.count,
    required this.subtitle,
    this.onInvite,
  });

  final int count;
  final String subtitle;
  final VoidCallback? onInvite;

  @override
  State<ReferralCard> createState() => _ReferralCardState();
}

class _ReferralCardState extends State<ReferralCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onInvite?.call();
      },
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.99 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: c.bgRaised,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: c.border),
            boxShadow: [
              BoxShadow(
                color: c.ink.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Yellow wash top-right.
              Positioned(
                top: -50,
                right: -50,
                child: IgnorePointer(
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          c.yellow.withValues(alpha: 0.22),
                          c.yellow.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: c.yellow,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: c.yellow, blurRadius: 4),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'MỜI BẠN DÙNG VIKA',
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.8,
                          color: c.inkSoft,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${widget.count} NGƯỜI',
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                          color: c.yellow,
                          fontFeatures: VikaIvoryMain.tabularFigures,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Big italic count.
                      Text(
                        widget.count.toString().padLeft(2, '0'),
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 52,
                          fontWeight: FontWeight.w800,
                          fontStyle: FontStyle.italic,
                          letterSpacing: -2.6,
                          height: 0.9,
                          color: c.ink,
                          fontFeatures: VikaIvoryMain.tabularFigures,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Người bạn',
                              style: TextStyle(
                                fontFamily: 'BeVietnamPro',
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                fontStyle: FontStyle.italic,
                                letterSpacing: -0.2,
                                color: c.ink,
                              ),
                            ),
                            Text(
                              'đã tham gia',
                              style: TextStyle(
                                fontFamily: 'BeVietnamPro',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                fontStyle: FontStyle.italic,
                                color: c.inkSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    widget.subtitle,
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                      color: c.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Yellow share pill (CTA).
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 0, 6, 0),
                      height: 44,
                      decoration: BoxDecoration(
                        color: c.yellow,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: c.yellow.withValues(alpha: 0.4),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Gửi lời mời',
                            style: TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                              color: c.yellowInk,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: c.ink,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.ios_share_rounded,
                              size: 14,
                              color: c.yellow,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ConnectionsList extends StatelessWidget {
  const ConnectionsList({
    super.key,
    required this.services,
    this.onConnect,
  });

  final List<ConnectedService> services;
  final ValueChanged<ConnectedService>? onConnect;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.bgRaised,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            for (var i = 0; i < services.length; i++) ...[
              _ConnectionRow(
                service: services[i],
                onTap: onConnect == null ? null : () => onConnect!(services[i]),
              ),
              if (i < services.length - 1)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: c.border,
                  indent: 64,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConnectionRow extends StatelessWidget {
  const _ConnectionRow({required this.service, this.onTap});
  final ConnectedService service;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap?.call();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.border),
                ),
                alignment: Alignment.center,
                child: Icon(
                  service.icon,
                  size: 17,
                  color: c.inkSoft,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      service.name,
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      service.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                        color: c.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
              // Connect pill / connected check.
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: service.connected ? c.yellow : c.ink,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (service.connected) ...[
                      Icon(Icons.check_rounded, size: 13, color: c.yellowInk),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      service.connected ? 'Đã nối' : 'Kết nối',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.1,
                        color: service.connected ? c.yellowInk : c.invInk,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
