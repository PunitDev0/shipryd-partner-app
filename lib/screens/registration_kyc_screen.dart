import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/app_store.dart';
import '../data/models.dart';
import '../theme/app_colors.dart';
import '../widgets/kyc_capture_tile.dart';
import '../widgets/onboarding_step_indicator.dart';
import 'registration_licence_screen.dart';

/// Step 5 — Identity Verification (KYC): Aadhaar (front/back) + PAN.
/// OCR/government verification isn't wired to a real vendor — submitting
/// here lands the KYC status in `pending`, same demo-auto-verify pattern
/// used for documents elsewhere in this app.
class RegistrationKycScreen extends StatefulWidget {
  const RegistrationKycScreen({super.key});

  @override
  State<RegistrationKycScreen> createState() => _RegistrationKycScreenState();
}

class _RegistrationKycScreenState extends State<RegistrationKycScreen> {
  final _aadhaarCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _aadhaarCtrl.dispose();
    _panCtrl.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final aadhaar = _aadhaarCtrl.text.trim();
    final pan = _panCtrl.text.trim().toUpperCase();
    if (aadhaar.length != 12) {
      setState(() => _error = 'Enter a valid 12-digit Aadhaar number');
      return;
    }
    if (pan.length != 10) {
      setState(() => _error = 'Enter a valid 10-character PAN number');
      return;
    }
    final store = AppStore.instance;
    if (store.documentFor('aadhaar_front')?.filePath == null || store.documentFor('aadhaar_back')?.filePath == null) {
      setState(() => _error = 'Upload both sides of your Aadhaar card');
      return;
    }
    if (store.documentFor('pan')?.filePath == null) {
      setState(() => _error = 'Upload your PAN card');
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await store.setKycDetails(KycDetails(aadhaarNumber: aadhaar, panNumber: pan));
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => const RegistrationLicenceScreen()));
    } catch (e) {
      setState(() {
        _error = 'Could not save your KYC details. Please try again.';
        _saving = false;
      });
    }
  }

  InputDecoration _decoration(String hint) => InputDecoration(
        filled: true,
        fillColor: AppColors.inputBg,
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textTertiary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppStore.instance,
      builder: (context, _) {
        final store = AppStore.instance;
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            centerTitle: true,
            leading: IconButton(icon: const Icon(Icons.arrow_back, size: 22), onPressed: () => Navigator.maybePop(context)),
            title: Text('Identity Verification', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  const OnboardingStepIndicator(step: 5),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          Text('Aadhaar Card', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _aadhaarCtrl,
                            keyboardType: TextInputType.number,
                            maxLength: 12,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w600),
                            decoration: _decoration('12-digit Aadhaar number').copyWith(counterText: ''),
                          ),
                          const SizedBox(height: 10),
                          KycCaptureTile(
                            label: 'Aadhaar Card (Front)',
                            filePath: store.documentFor('aadhaar_front')?.filePath,
                            status: store.documentFor('aadhaar_front')?.status ?? DocumentStatus.missing,
                            onCaptured: (file) => store.uploadDocumentFile('aadhaar_front', file),
                          ),
                          const SizedBox(height: 10),
                          KycCaptureTile(
                            label: 'Aadhaar Card (Back)',
                            filePath: store.documentFor('aadhaar_back')?.filePath,
                            status: store.documentFor('aadhaar_back')?.status ?? DocumentStatus.missing,
                            onCaptured: (file) => store.uploadDocumentFile('aadhaar_back', file),
                          ),

                          const SizedBox(height: 24),
                          Text('PAN Card', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _panCtrl,
                            textCapitalization: TextCapitalization.characters,
                            maxLength: 10,
                            style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w600),
                            decoration: _decoration('e.g. ABCDE1234F').copyWith(counterText: ''),
                          ),
                          const SizedBox(height: 10),
                          KycCaptureTile(
                            label: 'PAN Card',
                            filePath: store.documentFor('pan')?.filePath,
                            status: store.documentFor('pan')?.status ?? DocumentStatus.missing,
                            onCaptured: (file) => store.uploadDocumentFile('pan', file),
                          ),

                          if (_error != null) ...[
                            const SizedBox(height: 14),
                            Text(_error!, style: GoogleFonts.inter(fontSize: 12.5, color: Colors.red.shade700)),
                          ],
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _continue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.black,
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
      },
    );
  }
}
