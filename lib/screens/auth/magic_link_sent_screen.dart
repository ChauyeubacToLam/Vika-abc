import 'package:flutter/material.dart';

import '../onboarding/v5/v5_primitives.dart';
import '../onboarding/v5/v5_theme.dart';

class MagicLinkSentScreen extends StatelessWidget {
  const MagicLinkSentScreen({super.key, required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final r = V5Responsive.of(context);
    final bottomInset = r.viewPadding.bottom;

    return Scaffold(
      backgroundColor: V5.bg,
      appBar: AppBar(
        backgroundColor: V5.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: V5.ink,
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Quay lại',
        ),
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  V5.gutter,
                  r.pick(cozy: 72.0, short: 36.0),
                  V5.gutter,
                  bottomInset + 112,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: V5.yellowSoft,
                            borderRadius: BorderRadius.circular(V5.radiusMd),
                          ),
                          child: const Icon(
                            Icons.mark_email_read_outlined,
                            color: V5.yellowDeep,
                            size: 26,
                          ),
                        ),
                        const SizedBox(height: V5.space24),
                        Text(
                          'Kiểm tra email',
                          textAlign: TextAlign.center,
                          style: V5.displaySm(context, color: V5.ink),
                        ),
                        const SizedBox(height: V5.space12),
                        Text(
                          'Link đăng nhập đã được gửi đến $email.',
                          textAlign: TextAlign.center,
                          style: V5.body(context, color: V5.inkSoft),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            V5PillCTA(
              label: 'Đã hiểu',
              onTap: () => Navigator.of(context).maybePop(),
              bottom: 32 + bottomInset,
            ),
          ],
        ),
      ),
    );
  }
}
