import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/app_store.dart';
import '../theme/app_colors.dart';
import '../widgets/onboarding_step_indicator.dart';
import 'registration_terms_screen.dart';

const _checks = [
  'Criminal Record',
  'Blacklist Check',
  'Internal Fraud Database',
  'Previous Partner History',
];

/// Step 9 — Background Verification (Optional). No real vendor is wired
/// up (would need a background-check provider) — consenting lands the
/// status in `pending` server-side, same honest pending-verification
/// pattern used everywhere else in this flow.
class RegistrationBackgroundCheckScreen extends StatefulWidget {
  const RegistrationBackgroundCheckScreen({super.key});

  @override
  State<RegistrationBackgroundCheckScreen> createState() => _RegistrationBackgroundCheckScreenState();
}

class _RegistrationBackgroundCheckScreenState extends State<RegistrationBackgroundCheckScreen> {
  bool _consented = false;
  bool _submitting = false;

  Future<void> _proceed({required bool consented}) async {
    setState(() => _submitting = true);
    try {
      await AppStore.instance.requestBackgroundCheck(consented: consented);
    } catch (_) {
      // Non-blocking — background check is optional either way.
    }
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => const RegistrationTermsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back, size: 22), onPressed: () => Navigator.maybePop(context)),
        title: Text('Background Check', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              const OnboardingStepIndicator(step: 9),
              const SizedBox(height: 20),
              Text(
                'Optional background verification',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'With your consent, we may review the following before final approval. This step is optional and can be skipped.',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              ..._checks.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.shield_outlined, size: 18, color: AppColors.primaryDark),
                        const SizedBox(width: 10),
                        Text(c, style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.textPrimary)),
                      ],
                    ),
                  )),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => setState(() => _consented = !_consented),
                child: Row(
                  children: [
                    Checkbox(value: _consented, activeColor: AppColors.primary, onChanged: (v) => setState(() => _consented = v ?? false)),
                    Expanded(
                      child: Text(
                        'I consent to a background verification check',
                        style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: (_submitting || !_consented) ? null : () => _proceed(consented: true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.black,
                    disabledBackgroundColor: AppColors.border,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _submitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.black))
                      : Text('Run Background Check', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: _submitting ? null : () => _proceed(consented: false),
                  child: Text('Skip for now', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
