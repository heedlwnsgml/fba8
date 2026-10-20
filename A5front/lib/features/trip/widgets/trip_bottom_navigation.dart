import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class TripBottomNavigation extends StatelessWidget {
  final String? previousText;
  final String nextText;
  final VoidCallback? onPrevious;
  final VoidCallback onNext;

  const TripBottomNavigation({
    super.key,
    this.previousText = '이전',
    this.nextText = '다음',
    this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final hasPrevious = onPrevious != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: hasPrevious
          ? Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: OutlinedButton(
                      onPressed: onPrevious,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(
                        previousText ?? '이전',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(onPressed: onNext, child: Text(nextText)),
                ),
              ],
            )
          : FilledButton(onPressed: onNext, child: Text(nextText)),
    );
  }
}
