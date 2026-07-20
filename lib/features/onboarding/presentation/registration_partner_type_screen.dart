import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:partner/shared/state/app_store.dart';
import 'package:partner/shared/theme/app_colors.dart';
import '../widgets/onboarding_step_indicator.dart';
import 'registration_personal_details_screen.dart';

class _PartnerTypeDef {
  final String label;
  final IconData icon;
  const _PartnerTypeDef(this.label, this.icon);
}

const _partnerTypes = [
  _PartnerTypeDef('Bike', Icons.two_wheeler_rounded),
  _PartnerTypeDef('Scooter', Icons.electric_moped_rounded),
  _PartnerTypeDef('EV Bike', Icons.electric_bike_rounded),
  _PartnerTypeDef('Auto', Icons.electric_rickshaw_rounded),
  _PartnerTypeDef('Mini Truck', Icons.local_shipping_outlined),
  _PartnerTypeDef('Pickup Truck', Icons.fire_truck_outlined),
  _PartnerTypeDef('Tata Ace', Icons.airport_shuttle_rounded),
  _PartnerTypeDef('3 Wheeler', Icons.electric_rickshaw_outlined),
];

/// Step 2 — Select Partner Type. Determines which future orders this
/// partner can be matched to; full vehicle details (brand/model/number/
/// fuel/RC etc.) are collected later at Step 7.
class RegistrationPartnerTypeScreen extends StatefulWidget {
  static const route = '/registration-partner-type';
  const RegistrationPartnerTypeScreen({super.key});

  @override
  State<RegistrationPartnerTypeScreen> createState() => _RegistrationPartnerTypeScreenState();
}

class _RegistrationPartnerTypeScreenState extends State<RegistrationPartnerTypeScreen> {
  String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = AppStore.instance.vehicle?.type;
  }

  Future<void> _continue() async {
    if (_selected == null) return;
    await AppStore.instance.setVehicleType(_selected!);
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => const RegistrationPersonalDetailsScreen()));
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
        title: Text('Partner Type', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              const OnboardingStepIndicator(step: 2),
              const SizedBox(height: 20),
              Text(
                'What do you deliver on?',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'This decides which orders you get matched to.',
                style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  itemCount: _partnerTypes.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.5,
                  ),
                  itemBuilder: (_, i) {
                    final t = _partnerTypes[i];
                    final selected = _selected == t.label;
                    return _TypeCard(
                      def: t,
                      selected: selected,
                      onTap: () => setState(() => _selected = t.label),
                    );
                  },
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _selected == null ? null : _continue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.black,
                    disabledBackgroundColor: AppColors.border,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Continue', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
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

class _TypeCard extends StatelessWidget {
  final _PartnerTypeDef def;
  final bool selected;
  final VoidCallback onTap;

  const _TypeCard({required this.def, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.6 : 1.2),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Icon(def.icon, color: selected ? AppColors.primaryDark : AppColors.textSecondary, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                def.label,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
