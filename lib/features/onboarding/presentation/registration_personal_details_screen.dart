import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:partner/shared/state/app_store.dart';
import 'package:partner/shared/models/models.dart';
import 'package:partner/shared/theme/app_colors.dart';
import '../widgets/onboarding_step_indicator.dart';
import 'registration_photo_screen.dart';

const _genders = ['Male', 'Female', 'Other', 'Prefer not to say'];
const _languages = ['English', 'Hindi', 'Marathi', 'Tamil', 'Telugu', 'Kannada', 'Bengali', 'Gujarati'];

/// Step 3 — Personal Details.
class RegistrationPersonalDetailsScreen extends StatefulWidget {
  const RegistrationPersonalDetailsScreen({super.key});

  @override
  State<RegistrationPersonalDetailsScreen> createState() => _RegistrationPersonalDetailsScreenState();
}

class _RegistrationPersonalDetailsScreenState extends State<RegistrationPersonalDetailsScreen> {
  late final _nameCtrl = TextEditingController(text: AppStore.instance.draftName);
  late final _emailCtrl = TextEditingController(text: AppStore.instance.draftEmail);
  final _emergencyCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();

  DateTime? _dob;
  String? _gender;
  String _language = 'English';
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _emergencyCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pincodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 21, now.month, now.day),
      firstDate: DateTime(now.year - 80),
      lastDate: DateTime(now.year - 18, now.month, now.day),
      helpText: 'Date of Birth',
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _continue() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter your full name');
      return;
    }
    if (_dob == null) {
      setState(() => _error = 'Select your date of birth');
      return;
    }
    if (_emergencyCtrl.text.trim().length < 6) {
      setState(() => _error = 'Enter a valid emergency contact number');
      return;
    }
    if (_addressCtrl.text.trim().isEmpty || _cityCtrl.text.trim().isEmpty || _stateCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Fill in your current address, city and state');
      return;
    }
    if (_pincodeCtrl.text.trim().length < 4) {
      setState(() => _error = 'Enter a valid PIN code');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await AppStore.instance.setPersonalDetails(PersonalDetails(
        dob: _dob,
        gender: _gender,
        emergencyContact: _emergencyCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        state: _stateCtrl.text.trim(),
        pincode: _pincodeCtrl.text.trim(),
        preferredLanguage: _language,
      ));
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => const RegistrationPhotoScreen()));
    } catch (e) {
      setState(() {
        _error = 'Could not save your details. Please try again.';
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back, size: 22), onPressed: () => Navigator.maybePop(context)),
        title: Text('Personal Details', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              const OnboardingStepIndicator(step: 3),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Full Name'),
                      TextField(controller: _nameCtrl, style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w600), decoration: _decoration('Your full name')),

                      _label('Date of Birth'),
                      InkWell(
                        onTap: _pickDob,
                        borderRadius: BorderRadius.circular(14),
                        child: InputDecorator(
                          decoration: _decoration('Select date of birth'),
                          child: Text(
                            _dob != null ? DateFormat('d MMM, yyyy').format(_dob!) : 'Select date of birth',
                            style: GoogleFonts.inter(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: _dob != null ? AppColors.textPrimary : AppColors.textTertiary,
                            ),
                          ),
                        ),
                      ),

                      _label('Gender (Optional)'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _genders.map((g) {
                          final sel = _gender == g;
                          return ChoiceChip(
                            label: Text(g, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600)),
                            selected: sel,
                            onSelected: (_) => setState(() => _gender = sel ? null : g),
                            selectedColor: AppColors.primaryLight,
                            backgroundColor: AppColors.inputBg,
                            side: BorderSide(color: sel ? AppColors.primary : Colors.transparent),
                          );
                        }).toList(),
                      ),

                      _label('Email Address (Optional)'),
                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w600),
                        decoration: _decoration('you@example.com'),
                      ),

                      _label('Emergency Contact Number'),
                      TextField(
                        controller: _emergencyCtrl,
                        keyboardType: TextInputType.phone,
                        style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w600),
                        decoration: _decoration('10-digit mobile number'),
                      ),

                      _label('Current Address'),
                      TextField(
                        controller: _addressCtrl,
                        maxLines: 2,
                        style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w600),
                        decoration: _decoration('House/street/area'),
                      ),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('City'),
                                TextField(controller: _cityCtrl, style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w600), decoration: _decoration('City')),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('State'),
                                TextField(controller: _stateCtrl, style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w600), decoration: _decoration('State')),
                              ],
                            ),
                          ),
                        ],
                      ),

                      _label('PIN Code'),
                      TextField(
                        controller: _pincodeCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w600),
                        decoration: _decoration('e.g. 110001').copyWith(counterText: ''),
                      ),

                      _label('Preferred Language'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(color: AppColors.inputBg, borderRadius: BorderRadius.circular(14)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _language,
                            isExpanded: true,
                            style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            items: _languages.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                            onChanged: (v) => setState(() => _language = v!),
                          ),
                        ),
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 12),
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
  }
}
