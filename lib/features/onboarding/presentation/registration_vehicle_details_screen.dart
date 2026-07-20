import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:partner/shared/state/app_store.dart';
import 'package:partner/shared/models/models.dart';
import 'package:partner/shared/theme/app_colors.dart';
import '../widgets/kyc_capture_tile.dart';
import '../widgets/onboarding_step_indicator.dart';
import 'registration_bank_screen.dart';

const _fuelTypes = ['Petrol', 'Diesel', 'CNG', 'Electric'];

/// Step 7 — Vehicle Details. Type carries over read-only from Step 2;
/// this captures the rest (brand/model/number/fuel/year) plus RC/
/// insurance/pollution documents. Pollution certificate is skippable for
/// EV vehicles (nothing to certify).
class RegistrationVehicleDetailsScreen extends StatefulWidget {
  const RegistrationVehicleDetailsScreen({super.key});

  @override
  State<RegistrationVehicleDetailsScreen> createState() => _RegistrationVehicleDetailsScreenState();
}

class _RegistrationVehicleDetailsScreenState extends State<RegistrationVehicleDetailsScreen> {
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _numberCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  String _fuelType = _fuelTypes.first;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final v = AppStore.instance.vehicle;
    if (v != null) {
      _brandCtrl.text = v.brand ?? '';
      _modelCtrl.text = v.model ?? '';
      _numberCtrl.text = v.number;
      _yearCtrl.text = v.year?.toString() ?? '';
      if (v.fuelType != null && _fuelTypes.contains(v.fuelType)) _fuelType = v.fuelType!;
    }
  }

  @override
  void dispose() {
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _numberCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  bool get _isEv => (AppStore.instance.vehicle?.type ?? '').toLowerCase().contains('ev') || _fuelType == 'Electric';

  Future<void> _continue() async {
    final number = _numberCtrl.text.trim();
    if (number.length < 6) {
      setState(() => _error = 'Enter a valid vehicle number');
      return;
    }
    if (_brandCtrl.text.trim().isEmpty || _modelCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter the vehicle brand and model');
      return;
    }
    final store = AppStore.instance;
    if (store.documentFor('rc_doc')?.filePath == null) {
      setState(() => _error = 'Upload your vehicle RC');
      return;
    }
    if (store.documentFor('insurance')?.filePath == null) {
      setState(() => _error = 'Upload your insurance certificate');
      return;
    }
    if (!_isEv && store.documentFor('pollution')?.filePath == null) {
      setState(() => _error = 'Upload your pollution certificate');
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await store.setVehicleDetails(
        number: number,
        brand: _brandCtrl.text.trim(),
        model: _modelCtrl.text.trim(),
        fuelType: _fuelType,
        year: int.tryParse(_yearCtrl.text.trim()),
      );
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => const RegistrationBankScreen()));
    } catch (e) {
      setState(() {
        _error = 'Could not save your vehicle details. Please try again.';
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

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 16),
        child: Text(text, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600)),
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppStore.instance,
      builder: (context, _) {
        final store = AppStore.instance;
        final type = store.vehicle?.type ?? '—';
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            centerTitle: true,
            leading: IconButton(icon: const Icon(Icons.arrow_back, size: 22), onPressed: () => Navigator.maybePop(context)),
            title: Text('Vehicle Details', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  const OnboardingStepIndicator(step: 7),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Vehicle Type', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(color: AppColors.inputBg, borderRadius: BorderRadius.circular(14)),
                            child: Text(type, style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                          ),

                          _label('Vehicle Brand'),
                          TextField(controller: _brandCtrl, style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w600), decoration: _decoration('e.g. Honda')),

                          _label('Vehicle Model'),
                          TextField(controller: _modelCtrl, style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w600), decoration: _decoration('e.g. Activa 6G')),

                          _label('Vehicle Number'),
                          TextField(
                            controller: _numberCtrl,
                            textCapitalization: TextCapitalization.characters,
                            style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w600),
                            decoration: _decoration('e.g. DL 08 AB 1234'),
                          ),

                          _label('Fuel Type'),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(color: AppColors.inputBg, borderRadius: BorderRadius.circular(14)),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _fuelType,
                                isExpanded: true,
                                style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                items: _fuelTypes.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                                onChanged: (v) => setState(() => _fuelType = v!),
                              ),
                            ),
                          ),

                          _label('Year of Manufacture (Optional)'),
                          TextField(
                            controller: _yearCtrl,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w600),
                            decoration: _decoration('e.g. 2022').copyWith(counterText: ''),
                          ),

                          const SizedBox(height: 12),
                          KycCaptureTile(
                            label: 'Registration Certificate (RC)',
                            filePath: store.documentFor('rc_doc')?.filePath,
                            status: store.documentFor('rc_doc')?.status ?? DocumentStatus.missing,
                            onCaptured: (file) => store.uploadDocumentFile('rc_doc', file),
                          ),
                          const SizedBox(height: 10),
                          KycCaptureTile(
                            label: 'Insurance Certificate',
                            filePath: store.documentFor('insurance')?.filePath,
                            status: store.documentFor('insurance')?.status ?? DocumentStatus.missing,
                            onCaptured: (file) => store.uploadDocumentFile('insurance', file),
                          ),
                          const SizedBox(height: 10),
                          KycCaptureTile(
                            label: _isEv ? 'Pollution Certificate (not required for EVs)' : 'Pollution Certificate',
                            filePath: store.documentFor('pollution')?.filePath,
                            status: store.documentFor('pollution')?.status ?? DocumentStatus.missing,
                            onCaptured: (file) => store.uploadDocumentFile('pollution', file),
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
