import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class TripStepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalStep;

  const TripStepIndicator({
    super.key,
    required this.currentStep,
    this.totalStep = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalStep, (index) {
        final selected = index < currentStep;

        return Expanded(
          child: Container(
            height: 6,
            margin: EdgeInsets.only(right: index == totalStep - 1 ? 0 : 6),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.border,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}
