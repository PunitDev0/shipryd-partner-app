import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:partner/shared/state/app_store.dart';
import 'package:partner/shared/models/models.dart';
import 'package:partner/shared/theme/app_colors.dart';
import 'registration_success_screen.dart';

class RegistrationReviewScreen extends StatefulWidget {
  static const route = '/registration-review';
  const RegistrationReviewScreen({super.key});

  @override
  State<RegistrationReviewScreen> createState() => _RegistrationReviewScreenState();
}

class _RegistrationReviewScreenState extends State<RegistrationReviewScreen> {
  bool _submitting = false;

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await AppStore.instance.submitRegistration();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RegistrationSuccessScreen()),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not submit your application. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final vehicle = store.vehicle;
    final bank = store.bankAccounts.isNotEmpty ? store.bankAccounts.first : null;
    final personal = store.personalDetails;
    final kyc = store.kyc;
    final licence = store.drivingLicence;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 22),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text('Review & Submit', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Section(title: 'Personal Details', rows: {
                        'Name': store.draftName,
                        'Email': store.draftEmail,
                        'Phone': store.draftPhone,
                        'Date of Birth': personal?.dob != null ? DateFormat('d MMM, yyyy').format(personal!.dob!) : '-',
                        'Gender': personal?.gender ?? '-',
                        'Emergency Contact': personal?.emergencyContact ?? '-',
                        'Address': personal?.address ?? '-',
                        'City / State': '${personal?.city ?? '-'} / ${personal?.state ?? '-'}',
                        'PIN Code': personal?.pincode ?? '-',
                        'Preferred Language': personal?.preferredLanguage ?? '-',
                      }),
                      const SizedBox(height: 16),
                      _Section(title: 'Identity Verification (KYC)', rows: {
                        'Aadhaar Number': kyc?.aadhaarNumber ?? '-',
                        'PAN Number': kyc?.panNumber ?? '-',
                        'Status': _kycStatusLabel(kyc?.status),
                      }),
                      const SizedBox(height: 16),
                      _Section(title: 'Driving Licence', rows: {
                        'Number': licence?.number ?? '-',
                        'Expiry': licence?.expiryDate != null ? DateFormat('d MMM, yyyy').format(licence!.expiryDate) : '-',
                        'Verified': licence?.verified == true ? 'Yes' : 'Pending',
                      }),
                      const SizedBox(height: 16),
                      _Section(title: 'Vehicle', rows: {
                        'Type': vehicle?.type ?? '-',
                        'Brand / Model': '${vehicle?.brand ?? '-'} / ${vehicle?.model ?? '-'}',
                        'Number': vehicle?.number ?? '-',
                        'Fuel Type': vehicle?.fuelType ?? '-',
                        'Year': vehicle?.year?.toString() ?? '-',
                      }),
                      const SizedBox(height: 16),
                      _Section(title: 'Bank Account', rows: {
                        'Bank': bank?.bankName ?? '-',
                        'Account No.': bank?.accountNumber ?? '-',
                        'IFSC': bank?.ifsc ?? '-',
                        'Verification': _bankStatusLabel(bank?.verificationStatus),
                      }),
                      const SizedBox(height: 16),
                      _Section(title: 'Background Check', rows: {
                        'Status': _backgroundStatusLabel(store.backgroundCheckStatus),
                      }),
                      const SizedBox(height: 16),
                      _Section(title: 'Terms & Conditions', rows: {
                        'Accepted': store.termsAcceptedAt != null
                            ? DateFormat('d MMM, yyyy · h:mm a').format(store.termsAcceptedAt!)
                            : 'Not accepted',
                      }),
                      const SizedBox(height: 16),
                      _Section(title: 'Documents', rows: {
                        for (final d in store.documents) d.label: d.filePath != null ? 'Uploaded' : 'Missing',
                      }),
                    ],
                  ),
                ),
              ),
              Text(
                'By submitting, you agree to SHIPRYD Partner Terms & Conditions.',
                style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textTertiary),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.black),
                        )
                      : Text('Submit Application', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _kycStatusLabel(KycStatus? s) => switch (s) {
        KycStatus.pending => 'Pending Verification',
        KycStatus.verified => 'Verified',
        KycStatus.failed => 'Failed',
        _ => 'Not Submitted',
      };

  String _bankStatusLabel(BankVerificationStatus? s) => switch (s) {
        BankVerificationStatus.pending => 'Pending (Penny-Drop)',
        BankVerificationStatus.verified => 'Verified',
        BankVerificationStatus.failed => 'Failed',
        _ => 'Unverified',
      };

  String _backgroundStatusLabel(BackgroundCheckStatus s) => switch (s) {
        BackgroundCheckStatus.pending => 'Pending',
        BackgroundCheckStatus.clear => 'Clear',
        BackgroundCheckStatus.flagged => 'Flagged',
        BackgroundCheckStatus.notRequested => 'Skipped',
      };
}

class _Section extends StatelessWidget {
  final String title;
  final Map<String, String> rows;
  const _Section({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          for (final entry in rows.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(entry.key, style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary)),
                  Flexible(
                    child: Text(
                      entry.value,
                      textAlign: TextAlign.right,
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
