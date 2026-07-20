import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:partner/shared/theme/app_colors.dart';

/// Shared "Step X of N" progress header used across every onboarding
/// screen — previously copy-pasted per-file as a private `_StepIndicator`.
class OnboardingStepIndicator extends StatelessWidget {
  final int step;
  final int total;
  const OnboardingStepIndicator({super.key, required this.step, this.total = 10});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Step $step of $total',
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: step / total,
              minHeight: 6,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }
}
