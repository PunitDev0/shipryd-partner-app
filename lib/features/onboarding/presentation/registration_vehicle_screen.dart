import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:partner/shared/state/app_store.dart';
import 'package:partner/shared/models/models.dart';
import 'package:partner/shared/theme/app_colors.dart';
import 'registration_bank_screen.dart';

/// Vehicle details form. Used both as a registration step (onboarding new
/// partners) and as the "Change Vehicle" edit screen from the profile tab.
class RegistrationVehicleScreen extends StatefulWidget {
  static const route = '/registration-vehicle';
  final bool isOnboarding;
  const RegistrationVehicleScreen({super.key, this.isOnboarding = true});

  @override
  State<RegistrationVehicleScreen> createState() =>
      _RegistrationVehicleScreenState();
}

class _RegistrationVehicleScreenState extends State<RegistrationVehicleScreen> {
  static const _types = ['Bike', 'Scooter', 'Van', 'Truck'];
  String _type = _types.first;
  final _numberController = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = AppStore.instance.vehicle;
    if (existing != null) {
      _type = existing.type;
      _numberController.text = existing.number;
    }
  }

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final number = _numberController.text.trim();
    if (number.length < 6) {
      setState(() => _error = 'Enter a valid vehicle number');
      return;
    }
    await AppStore.instance.setVehicle(VehicleInfo(type: _type, number: number));
    if (!mounted) return;
    if (widget.isOnboarding) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const RegistrationBankScreen(),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vehicle details updated')),
      );
      Navigator.pop(context);
    }
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
          widget.isOnboarding ? 'Vehicle Details' : 'Change Vehicle',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.isOnboarding) ...[
                const SizedBox(height: 4),
                _StepIndicator(step: 1, total: 4),
                const SizedBox(height: 20),
              ] else
                const SizedBox(height: 8),

              Text('Vehicle Type', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.inputBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _type,
                    isExpanded: true,
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    items: _types
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setState(() => _type = v!),
                  ),
                ),
              ),

              const SizedBox(height: 18),
              Text('Vehicle Number', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _numberController,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [UpperCaseTextFormatter()],
                style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.inputBg,
                  hintText: 'e.g. DL 08 AB 1234',
                  hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textTertiary),
                  errorText: _error,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),

              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _continue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    widget.isOnboarding ? 'Continue' : 'Save',
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
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

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int step;
  final int total;
  const _StepIndicator({required this.step, required this.total});

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
