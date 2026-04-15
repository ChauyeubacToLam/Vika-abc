import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vika/widgets/vf_primitives.dart';

import '../onboarding_primitives.dart';
import '../vf_theme.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({
    super.key,
    required this.onStart,
  });

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final s = VF.scale(context);
    final media = MediaQuery.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              VF.surfaceDark,
              VF.jadeDark,
              Color(0xFF0A2E22),
            ],
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: VFGrainOverlay(opacity: 0.035)),
            Positioned(
              top: -30 * s,
              right: -40 * s,
              child: const VFDecorativeRing(size: 160),
            ),
            Positioned(
              top: media.size.height * 0.30,
              left: 56 * s,
              right: 56 * s,
              child: Container(
                width: 280 * s,
                height: 280 * s,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: VF.jadeGlow.withValues(alpha: 0.04),
                      blurRadius: 90 * s,
                      spreadRadius: 32 * s,
                    ),
                  ],
                ),
              ),
            ),
            Column(
              children: [
                Expanded(
                  child: Padding(
                    padding:
                        EdgeInsets.fromLTRB(28 * s, media.padding.top + 20 * s, 28 * s, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VIKA',
                          style: VF.textStyle(
                            context,
                            size: 11,
                            weight: FontWeight.w700,
                            letterSpacing: 3.5,
                            color: VF.jadeGlow.withValues(alpha: 0.40),
                          ),
                        ),
                        SizedBox(height: 14 * s),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: 300 * s),
                          child: Text(
                            'T\u1EADp \u1EDF nh\u00E0 kh\u00F4ng ai s\u1EEDa form. Thu\u00EA PT th\u00EC 300-500k m\u1ED7i bu\u1ED5i. B\u1EA1n \u0111\u00E1ng \u0111\u01B0\u1EE3c t\u1EADp \u0111\u00FAng m\u00E0 kh\u00F4ng c\u1EA7n tr\u1EA3 gi\u00E1 \u0111\u00F3.',
                            style: VF.textStyle(
                              context,
                              size: 14,
                              weight: FontWeight.w500,
                              height: 1.65,
                              color: Colors.white.withValues(alpha: 0.28),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 16 * s),
                              child: Container(
                                width: double.infinity,
                                constraints:
                                    BoxConstraints(maxHeight: 250 * s),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24 * s),
                                  color: Colors.white.withValues(alpha: 0.03),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.06),
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    Positioned(
                                      top: 12 * s,
                                      left: 14 * s,
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 10 * s,
                                          vertical: 4 * s,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(7 * s),
                                          color: VF.jadeGlow
                                              .withValues(alpha: 0.12),
                                          border: Border.all(
                                            color: VF.jadeGlow
                                                .withValues(alpha: 0.08),
                                          ),
                                        ),
                                        child: Text(
                                          'REAL-TIME AI',
                                          style: VF.textStyle(
                                            context,
                                            size: 9,
                                            weight: FontWeight.w700,
                                            letterSpacing: 0.3,
                                            color: VF.jadeGlow
                                                .withValues(alpha: 0.55),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.videocam_outlined,
                                            size: 44 * s,
                                            color: Colors.white
                                                .withValues(alpha: 0.12),
                                          ),
                                          SizedBox(height: 8 * s),
                                          Text(
                                            '\u1EA2nh: AI ph\u00E2n t\u00EDch form t\u1EADp',
                                            style: VF.textStyle(
                                              context,
                                              size: 10,
                                              weight: FontWeight.w600,
                                              color: Colors.white
                                                  .withValues(alpha: 0.08),
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
                        Padding(
                          padding: EdgeInsets.only(bottom: 8 * s),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    fontSize: VF.sp(context, 30),
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1.5 * s,
                                    height: 1.1,
                                    color: Colors.white,
                                  ),
                                  children: [
                                    const TextSpan(text: 'PT trong t\u00FAi. '),
                                    TextSpan(
                                      text: 'Mi\u1EC5n ph\u00ED.',
                                      style: TextStyle(
                                        color:
                                            VF.jadeGlow.withValues(alpha: 0.85),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 12 * s),
                              ConstrainedBox(
                                constraints:
                                    BoxConstraints(maxWidth: 304 * s),
                                child: Text(
                                  'S\u1EEDa form b\u1EB1ng AI. L\u1ED9 tr\u00ECnh c\u00E1 nh\u00E2n. Th\u1EED th\u00E1ch c\u00F9ng b\u1EA1n b\u00E8.',
                                  style: VF.textStyle(
                                    context,
                                    size: 13,
                                    weight: FontWeight.w500,
                                    height: 1.55,
                                    color: Colors.white.withValues(alpha: 0.25),
                                  ),
                                ),
                              ),
                              SizedBox(height: 16 * s),
                              Row(
                                children: [
                                  Expanded(
                                    child: _WelcomeStat(
                                      value: 'AI',
                                      label: 's\u1EEDa form realtime',
                                    ),
                                  ),
                                  Expanded(
                                    child: _WelcomeStat(
                                      value: '0\u0111',
                                      label: 'thay PT',
                                      showDivider: true,
                                    ),
                                  ),
                                  Expanded(
                                    child: _WelcomeStat(
                                      value: '24/7',
                                      label: 't\u1EADp m\u1ECDi l\u00FAc',
                                      showDivider: true,
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
                VFOnboardingButton(
                  label: 'B\u1EAFt \u0111\u1EA7u',
                  onTap: onStart,
                  tone: VFButtonTone.jade,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeStat extends StatelessWidget {
  const _WelcomeStat({
    required this.value,
    required this.label,
    this.showDivider = false,
  });

  final String value;
  final String label;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final s = VF.scale(context);
    return Container(
      padding: EdgeInsets.only(left: showDivider ? 14 * s : 0),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                left: BorderSide(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: VF.textStyle(
              context,
              size: 17,
              weight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 2 * s),
          Text(
            label,
            style: VF.textStyle(
              context,
              size: 9,
              weight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }
}
