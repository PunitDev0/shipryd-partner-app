import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/app_store.dart';
import '../theme/app_colors.dart';
import '../widgets/onboarding_step_indicator.dart';
import 'registration_review_screen.dart';

class _TermDef {
  final String title;
  final String body;
  const _TermDef(this.title, this.body);
}

// Placeholder legal copy — final wording is a legal/content task, not code.
const _terms = [
  _TermDef(
    'Partner Agreement',
    'This agreement governs your relationship with SHIPRYD as a delivery partner, including your obligations, '
        'service standards, and the terms under which you may accept and fulfil delivery orders.',
  ),
  _TermDef(
    'Privacy Policy',
    'We collect and process your personal, KYC, and location data solely to operate the SHIPRYD partner platform, '
        'verify your identity, process payouts, and improve service quality.',
  ),
  _TermDef(
    'Earnings Policy',
    'Describes how trip earnings, incentives, and surge payouts are calculated, when they are credited to your '
        'wallet, and the process for requesting withdrawals.',
  ),
  _TermDef(
    'Cancellation Policy',
    'Outlines acceptable reasons for cancelling an accepted order, any penalties for repeated or unjustified '
        'cancellations, and how disputes are resolved.',
  ),
];

/// Step 10 — Terms & Conditions. All four must be accepted before
/// onboarding can be submitted for review.
class RegistrationTermsScreen extends StatefulWidget {
  const RegistrationTermsScreen({super.key});

  @override
  State<RegistrationTermsScreen> createState() => _RegistrationTermsScreenState();
}

class _RegistrationTermsScreenState extends State<RegistrationTermsScreen> {
  final List<bool> _accepted = List.filled(_terms.length, false);
  bool _saving = false;

  bool get _allAccepted => _accepted.every((a) => a);

  void _showTerm(_TermDef term) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollCtrl) => Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            controller: scrollCtrl,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(term.title, style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Text(term.body, style: GoogleFonts.inter(fontSize: 13.5, height: 1.6, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_allAccepted) return;
    setState(() => _saving = true);
    try {
      await AppStore.instance.acceptTermsAndConditions();
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => const RegistrationReviewScreen()));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back, size: 22), onPressed: () => Navigator.maybePop(context)),
        title: Text('Terms & Conditions', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              const OnboardingStepIndicator(step: 10),
              const SizedBox(height: 20),
              Text(
                'Please review and accept',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'All four must be accepted to complete onboarding.',
                style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: _terms.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final t = _terms[i];
                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border, width: 1.2),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _accepted[i],
                            activeColor: AppColors.primary,
                            onChanged: (v) => setState(() => _accepted[i] = v ?? false),
                          ),
                          Expanded(
                            child: Text(t.title, style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700)),
                          ),
                          TextButton(
                            onPressed: () => _showTerm(t),
                            child: Text('Read', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    );
                  },
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: (_allAccepted && !_saving) ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.black,
                    disabledBackgroundColor: AppColors.border,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _saving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.black))
                      : Text('Continue', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
