import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:partner/core/app_exception.dart';
import 'package:partner/shared/state/app_store.dart';
import 'package:partner/shared/models/models.dart';
import 'package:partner/shared/theme/app_colors.dart';
import '../widgets/kyc_capture_tile.dart';
import '../widgets/onboarding_step_indicator.dart';
import 'registration_vehicle_details_screen.dart';

/// Step 6 — Driving Licence. An expired licence blocks onboarding outright
/// (both here and re-validated server-side in `setDrivingLicence`).
class RegistrationLicenceScreen extends StatefulWidget {
  const RegistrationLicenceScreen({super.key});

  @override
  State<RegistrationLicenceScreen> createState() => _RegistrationLicenceScreenState();
}

class _RegistrationLicenceScreenState extends State<RegistrationLicenceScreen> {
  final _numberCtrl = TextEditingController();
  DateTime? _expiry;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _numberCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 20),
      lastDate: DateTime(now.year + 20),
      helpText: 'Licence Expiry Date',
    );
    if (picked != null) setState(() => _expiry = picked);
  }

  Future<void> _continue() async {
    final number = _numberCtrl.text.trim();
    if (number.length < 4) {
      setState(() => _error = 'Enter a valid driving licence number');
      return;
    }
    if (_expiry == null) {
      setState(() => _error = 'Select the licence expiry date');
      return;
    }
    if (_expiry!.isBefore(DateTime.now())) {
      setState(() => _error = 'This licence has expired — onboarding cannot proceed with an expired licence');
      return;
    }
    final store = AppStore.instance;
    if (store.documentFor('dl_front')?.filePath == null || store.documentFor('dl_back')?.filePath == null) {
      setState(() => _error = 'Upload both sides of your driving licence');
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await store.setDrivingLicenceDetails(DrivingLicence(number: number, expiryDate: _expiry!));
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => const RegistrationVehicleDetailsScreen()));
    } on AppException catch (e) {
      setState(() {
        _error = e.message;
        _saving = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not save your licence details. Please try again.';
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
        final expired = _expiry != null && _expiry!.isBefore(DateTime.now());
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            centerTitle: true,
            leading: IconButton(icon: const Icon(Icons.arrow_back, size: 22), onPressed: () => Navigator.maybePop(context)),
            title: Text('Driving Licence', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  const OnboardingStepIndicator(step: 6),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          Text('Licence Number', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _numberCtrl,
                            textCapitalization: TextCapitalization.characters,
                            style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w600),
                            decoration: _decoration('e.g. DL-1420110012345'),
                          ),
                          const SizedBox(height: 16),
                          Text('Expiry Date', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _pickExpiry,
                            borderRadius: BorderRadius.circular(14),
                            child: InputDecorator(
                              decoration: _decoration('Select expiry date'),
                              child: Text(
                                _expiry != null ? DateFormat('d MMM, yyyy').format(_expiry!) : 'Select expiry date',
                                style: GoogleFonts.inter(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: expired ? Colors.red.shade700 : (_expiry != null ? AppColors.textPrimary : AppColors.textTertiary),
                                ),
                              ),
                            ),
                          ),
                          if (expired) ...[
                            const SizedBox(height: 6),
                            Text(
                              'This licence has expired',
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.w600),
                            ),
                          ],

                          const SizedBox(height: 20),
                          KycCaptureTile(
                            label: 'Driving Licence (Front)',
                            filePath: store.documentFor('dl_front')?.filePath,
                            status: store.documentFor('dl_front')?.status ?? DocumentStatus.missing,
                            onCaptured: (file) => store.uploadDocumentFile('dl_front', file),
                          ),
                          const SizedBox(height: 10),
                          KycCaptureTile(
                            label: 'Driving Licence (Back)',
                            filePath: store.documentFor('dl_back')?.filePath,
                            status: store.documentFor('dl_back')?.status ?? DocumentStatus.missing,
                            onCaptured: (file) => store.uploadDocumentFile('dl_back', file),
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
                      onPressed: (_saving || expired) ? null : _continue,
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
      },
    );
  }
}
