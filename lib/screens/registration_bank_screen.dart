import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/app_store.dart';
import '../data/models.dart';
import '../theme/app_colors.dart';
import '../widgets/onboarding_step_indicator.dart';
import 'registration_background_check_screen.dart';
import 'registration_vehicle_screen.dart' show UpperCaseTextFormatter;

/// Bank account form. Used both as a registration step (Step 8, with
/// penny-drop verification) and as the "Add New Bank Account" edit screen
/// from Bank Details in the profile tab.
class RegistrationBankScreen extends StatefulWidget {
  static const route = '/registration-bank';
  final bool isOnboarding;
  const RegistrationBankScreen({super.key, this.isOnboarding = true});

  @override
  State<RegistrationBankScreen> createState() => _RegistrationBankScreenState();
}

class _RegistrationBankScreenState extends State<RegistrationBankScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bankController = TextEditingController();
  final _accountController = TextEditingController();
  final _ifscController = TextEditingController();
  final _holderController = TextEditingController();

  bool _saved = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _holderController.text = AppStore.instance.profile.name;
  }

  @override
  void dispose() {
    _bankController.dispose();
    _accountController.dispose();
    _ifscController.dispose();
    _holderController.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String hint) => InputDecoration(
        filled: true,
        fillColor: AppColors.inputBg,
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textTertiary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await AppStore.instance.upsertBankAccount(
      BankAccount(
        bankName: _bankController.text.trim(),
        accountNumber: _accountController.text.trim(),
        ifsc: _ifscController.text.trim().toUpperCase(),
        holderName: _holderController.text.trim(),
      ),
    );
    if (!mounted) return;
    if (!widget.isOnboarding) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bank account added')),
      );
      Navigator.pop(context);
      return;
    }
    // Step 8: kick off penny-drop verification and show its status below
    // instead of navigating away immediately.
    await AppStore.instance.triggerBankVerification();
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saved = true;
    });
  }

  void _continueToBackgroundCheck() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const RegistrationBackgroundCheckScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 22),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          widget.isOnboarding ? 'Bank Details' : 'Add Bank Account',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.isOnboarding) ...[
                  const SizedBox(height: 4),
                  const OnboardingStepIndicator(step: 8),
                  const SizedBox(height: 20),
                ] else
                  const SizedBox(height: 8),

                Text('Bank Name', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _bankController,
                  enabled: !_saved,
                  style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w600),
                  decoration: _decoration('e.g. HDFC Bank'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                Text('Account Number', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _accountController,
                  enabled: !_saved,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w600),
                  decoration: _decoration('Enter account number'),
                  validator: (v) => (v == null || v.trim().length < 6) ? 'Enter a valid account number' : null,
                ),
                const SizedBox(height: 16),

                Text('IFSC Code', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _ifscController,
                  enabled: !_saved,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [UpperCaseTextFormatter()],
                  style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w600),
                  decoration: _decoration('e.g. HDFC0001234'),
                  validator: (v) => (v == null || v.trim().length < 8) ? 'Enter a valid IFSC code' : null,
                ),
                const SizedBox(height: 16),

                Text('Account Holder Name', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _holderController,
                  enabled: !_saved,
                  style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w600),
                  decoration: _decoration('As per bank records'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),

                if (widget.isOnboarding && _saved) ...[
                  const SizedBox(height: 20),
                  AnimatedBuilder(
                    animation: AppStore.instance,
                    builder: (context, _) {
                      final status = AppStore.instance.bankAccounts.isNotEmpty
                          ? AppStore.instance.bankAccounts.first.verificationStatus
                          : BankVerificationStatus.pending;
                      final verified = status == BankVerificationStatus.verified;
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: verified ? AppColors.primaryLight : AppColors.inputBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            if (verified)
                              const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20)
                            else
                              const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2.2)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                verified ? 'Account verified via penny-drop' : 'Verifying account (penny-drop)…',
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],

                const SizedBox(height: 32),
                if (!widget.isOnboarding || !_saved)
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _saving
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.black))
                          : Text(
                              widget.isOnboarding ? 'Continue' : 'Save',
                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                    ),
                  )
                else
                  AnimatedBuilder(
                    animation: AppStore.instance,
                    builder: (context, _) {
                      final verified = AppStore.instance.bankAccounts.isNotEmpty &&
                          AppStore.instance.bankAccounts.first.verificationStatus == BankVerificationStatus.verified;
                      return SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: verified ? _continueToBackgroundCheck : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.black,
                            disabledBackgroundColor: AppColors.border,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text('Continue', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
