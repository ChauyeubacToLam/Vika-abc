import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../onboarding/v5/v5_theme.dart';

/// How long the Apple tile must be held (a silent press-and-hold, no visible
/// hint) before the reviewer-access gate opens. Shared by every sign-in surface
/// — the S13 onboarding sign-in and the standalone LoginScreen — so the hidden
/// hold is identical everywhere.
const Duration reviewerHoldDuration = Duration(seconds: 5);

/// Shared reviewer-demo gate. Lets an App Review reviewer reach the seeded,
/// read-only demo WITHOUT finishing onboarding or having real credentials.
///
/// The full flow lives here so every sign-in surface runs identical logic:
///   1. Show the "Reviewer access" code dialog ([ReviewerCodeDialog]).
///   2. Exchange the code via the `demo-session` edge function → {email, otp}.
///   3. Sign in with the returned OTP (magiclink).
///   4. Replace the route with the read-only `/reviewer-demo` screen.
///
/// [onStart] fires the instant a non-empty code is submitted and the exchange
/// begins — callers use it to claim auth ownership and/or show a busy state.
/// [onError] fires on any failure with a reviewer-facing (English) message.
/// Returns early (doing nothing) if the dialog is cancelled or dismissed.
Future<void> showReviewerDemoGate(
  BuildContext context, {
  VoidCallback? onStart,
  void Function(String message)? onError,
}) async {
  // The dialog OWNS its TextEditingController (see [ReviewerCodeDialog]) and
  // disposes it in its own State.dispose — which only fires after the route is
  // fully gone, so the field never references a disposed controller mid dismiss.
  final code = await showDialog<String>(
    context: context,
    barrierColor: V5.ink.withValues(alpha: 0.42),
    builder: (_) => const ReviewerCodeDialog(),
  );

  if (code == null || code.isEmpty || !context.mounted) return;

  onStart?.call();
  try {
    final res = await Supabase.instance.client.functions.invoke(
      'demo-session',
      body: {'code': code},
    );
    final data = res.data;
    final email = data is Map ? data['email']?.toString() : null;
    final otp = data is Map ? data['otp']?.toString() : null;
    if (email == null || email.isEmpty || otp == null || otp.isEmpty) {
      throw const FormatException('Invalid demo session response');
    }

    await Supabase.instance.client.auth.verifyOTP(
      email: email,
      token: otp,
      type: OtpType.magiclink,
    );

    if (!context.mounted) return;
    // Reviewer sees a read-only plan reveal before entering the seeded home.
    Navigator.of(context).pushReplacementNamed('/reviewer-demo');
  } catch (_) {
    // Reviewer-only chrome → English (audience is the Apple reviewer).
    onError?.call('Unable to open reviewer mode. Check the code and try again.');
  }
}

/// Reviewer access-code prompt, styled to the Premium Ivory design system.
///
/// Owns its [TextEditingController] and disposes it in its OWN [State.dispose],
/// which fires only after the dialog route is fully gone — so the field never
/// references a disposed controller mid dismiss-animation.
///
/// This is reviewer-only chrome, so the copy is ENGLISH (audience: the Apple
/// reviewer). Returns the trimmed code via [Navigator.pop], or null on cancel.
class ReviewerCodeDialog extends StatefulWidget {
  const ReviewerCodeDialog({super.key});

  @override
  State<ReviewerCodeDialog> createState() => _ReviewerCodeDialogState();
}

class _ReviewerCodeDialogState extends State<ReviewerCodeDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text.trim());
  void _cancel() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        decoration: BoxDecoration(
          color: V5.surface,
          borderRadius: BorderRadius.circular(V5.radiusLg),
          border: Border.all(color: V5.border),
          boxShadow: V5.elevation4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: V5.yellowSoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    size: 16,
                    color: V5.yellowDeep,
                  ),
                ),
                const SizedBox(width: 10),
                Text('Reviewer access', style: V5.title(context, color: V5.ink)),
              ],
            ),
            const SizedBox(height: V5.space8),
            Text(
              'Enter the access code to open a read-only demo of the app.',
              style: V5.bodySm(context, color: V5.inkSoft),
            ),
            const SizedBox(height: V5.space16),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: V5.bgSoft,
                border: Border.all(color: V5.border),
                borderRadius: BorderRadius.circular(V5.radiusMd),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ACCESS CODE',
                    style: V5.eyebrow(context, color: V5.inkFaint),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    cursorColor: V5.yellow,
                    style: V5.text(
                      context,
                      size: 15,
                      weight: FontWeight.w600,
                      color: V5.ink,
                      letterSpacing: 2,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: '••••••',
                      hintStyle: V5.text(
                        context,
                        size: 15,
                        weight: FontWeight.w600,
                        color: V5.inkFaint,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: V5.space16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _cancel,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(V5.radiusFull),
                        border: Border.all(color: V5.borderHi, width: 1.4),
                      ),
                      child: Text(
                        'Cancel',
                        style: V5.text(
                          context,
                          size: 14,
                          weight: FontWeight.w700,
                          color: V5.inkSoft,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: _submit,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
                      decoration: BoxDecoration(
                        color: V5.ink,
                        borderRadius: BorderRadius.circular(V5.radiusFull),
                        boxShadow: V5.elevation2,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Continue',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: V5.text(
                                context,
                                size: 14,
                                weight: FontWeight.w700,
                                color: V5.invInk,
                              ),
                            ),
                          ),
                          Container(
                            width: 34,
                            height: 34,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: V5.yellow,
                            ),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                              color: V5.yellowInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
