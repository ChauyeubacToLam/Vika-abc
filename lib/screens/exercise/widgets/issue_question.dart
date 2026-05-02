import 'package:flutter/material.dart';

import '../../../theme/vf_theme.dart';

class IssueQuestion extends StatelessWidget {
  const IssueQuestion({
    super.key,
    required this.observation,
    required this.question,
    required this.value,
    required this.onChanged,
  });

  final String observation;
  final String question;
  final String? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VFTheme.amber.withValues(alpha: 0.06),
        border: Border.all(color: VFTheme.amber.withValues(alpha: 0.10)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: VFTheme.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.tips_and_updates_outlined,
              size: 14,
              color: VFTheme.amber,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  observation,
                  style: VFTheme.textStyle(
                    context,
                    size: 12,
                    weight: FontWeight.w600,
                    color: VFTheme.amber,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  question,
                  style: VFTheme.textStyle(
                    context,
                    size: 13,
                    weight: FontWeight.w700,
                    color: VFTheme.text.withValues(alpha: 0.88),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: ['Có', 'Không'].map((option) {
                    final selected = value == option;
                    return GestureDetector(
                      onTap: () => onChanged(option),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? VFTheme.amber.withValues(alpha: 0.16)
                              : VFTheme.textMuted.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected
                                ? VFTheme.amber.withValues(alpha: 0.26)
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          option,
                          style: VFTheme.textStyle(
                            context,
                            size: 13,
                            weight: FontWeight.w700,
                            color: selected ? VFTheme.amber : VFTheme.textMuted,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
