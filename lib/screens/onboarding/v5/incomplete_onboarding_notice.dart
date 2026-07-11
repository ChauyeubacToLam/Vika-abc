import 'package:flutter/material.dart';

import 'v5_theme.dart';

const incompleteOnboardingNoticeTitleVi = 'Hoàn tất hồ sơ tập luyện';
const incompleteOnboardingNoticeTitleEn = 'Complete your training profile';
const incompleteOnboardingNoticeBodyVi =
    'Vika tạo kế hoạch tập luyện phù hợp với mục tiêu và thể trạng của bạn. '
    'Tài khoản này cần hoàn tất vài bước còn lại về mục tiêu, hình thức tập luyện, '
    'trình độ và lịch tập hằng tuần.';
const incompleteOnboardingNoticeBodyEn =
    'Vika creates a training plan tailored to your goals and current fitness. '
    'A few setup steps remain for this account: your goal, training style, level, '
    'and weekly schedule.';

const incompleteOnboardingNoticeContinueVi = 'Tiếp tục';
const incompleteOnboardingNoticeContinueEn = 'Continue';

Future<void> showIncompleteOnboardingNotice(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: V5.ink.withValues(alpha: 0.48),
    builder: (_) => const IncompleteOnboardingNoticeDialog(),
  );
}

/// Explains why an authenticated account with an unfinished profile continues
/// through onboarding before the personalized plan can be created.
class IncompleteOnboardingNoticeDialog extends StatelessWidget {
  const IncompleteOnboardingNoticeDialog({super.key});

  static const continueButtonKey = Key('incomplete_onboarding_continue');

  @override
  Widget build(BuildContext context) {
    final maxDialogHeight = MediaQuery.sizeOf(context).height - 48;
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 420,
            maxHeight: maxDialogHeight,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: V5.surfaceRaised,
              borderRadius: BorderRadius.circular(V5.radiusXl),
              border: Border.all(color: V5.borderHi),
              boxShadow: V5.elevation4,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: V5.yellowSoft,
                          borderRadius: BorderRadius.circular(V5.radiusSm),
                          border: Border.all(
                            color: V5.yellow.withValues(alpha: 0.30),
                          ),
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          color: V5.yellowDeep,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: V5.space14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              incompleteOnboardingNoticeTitleVi,
                              style: V5.title(context).copyWith(height: 1.16),
                            ),
                            const SizedBox(height: V5.space4),
                            Text(
                              incompleteOnboardingNoticeTitleEn,
                              style: V5.bodySm(context, color: V5.inkSoft),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: V5.space20),
                  Container(height: 1, color: V5.border),
                  const SizedBox(height: V5.space16),
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            incompleteOnboardingNoticeBodyVi,
                            style: V5
                                .body(context, color: V5.ink)
                                .copyWith(height: 1.5),
                          ),
                          const SizedBox(height: V5.space12),
                          Text(
                            incompleteOnboardingNoticeBodyEn,
                            style: V5
                                .bodySm(context, color: V5.inkSoft)
                                .copyWith(height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: V5.space20),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: FilledButton(
                      key: continueButtonKey,
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: V5.ink,
                        foregroundColor: V5.invInk,
                        disabledBackgroundColor: V5.ink,
                        padding: const EdgeInsets.fromLTRB(22, 8, 8, 8),
                        elevation: 0,
                        shape: const StadiumBorder(),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  incompleteOnboardingNoticeContinueVi,
                                  style: V5.titleSm(
                                    context,
                                    color: V5.invInk,
                                  ),
                                ),
                                Text(
                                  incompleteOnboardingNoticeContinueEn,
                                  style: V5.bodyXs(
                                    context,
                                    color: V5.invInkSoft,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: V5.yellow,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              size: 19,
                              color: V5.yellowInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
