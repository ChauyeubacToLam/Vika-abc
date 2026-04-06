import 'dart:ui';

import 'package:flutter/material.dart';

enum SystemBannerMode { scan, warn, info, pause }

class SystemBanner extends StatefulWidget {
  const SystemBanner({
    super.key,
    required this.message,
    required this.mode,
  });

  final String message;
  final SystemBannerMode mode;

  @override
  State<SystemBanner> createState() => _SystemBannerState();
}

class _SystemBannerState extends State<SystemBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant SystemBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (widget.mode == SystemBannerMode.scan) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(widget.mode);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return Opacity(
                    opacity: widget.mode == SystemBannerMode.scan
                        ? 0.45 + (_controller.value * 0.55)
                        : 1,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colors.dot,
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.message,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _BannerColors _colorsFor(SystemBannerMode mode) {
    switch (mode) {
      case SystemBannerMode.scan:
        return const _BannerColors(
          background: Color(0x14FFFFFF),
          border: Color(0x18FFFFFF),
          text: Color(0xB2FFFFFF),
          dot: Color(0x80FFFFFF),
        );
      case SystemBannerMode.warn:
        return const _BannerColors(
          background: Color(0x26B84435),
          border: Color(0x40B84435),
          text: Color(0xFFFFD2CB),
          dot: Color(0xFFB84435),
        );
      case SystemBannerMode.pause:
        return const _BannerColors(
          background: Color(0x16FFFFFF),
          border: Color(0x1AFFFFFF),
          text: Color(0xCCFFFFFF),
          dot: Color(0x99FFFFFF),
        );
      case SystemBannerMode.info:
        return const _BannerColors(
          background: Color(0x195CEAA8),
          border: Color(0x265CEAA8),
          text: Color(0xFFBDF8DA),
          dot: Color(0xFF5CEAA8),
        );
    }
  }
}

class _BannerColors {
  const _BannerColors({
    required this.background,
    required this.border,
    required this.text,
    required this.dot,
  });

  final Color background;
  final Color border;
  final Color text;
  final Color dot;
}
