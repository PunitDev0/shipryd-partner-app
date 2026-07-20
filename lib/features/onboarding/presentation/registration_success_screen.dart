import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:partner/shared/theme/app_colors.dart';
import 'package:partner/features/orders/presentation/dashboard_screen.dart';

class RegistrationSuccessScreen extends StatelessWidget {
  static const route = '/registration-success';
  const RegistrationSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 110,
                height: 110,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.celebration_rounded, color: Colors.white, size: 56),
              ),
              const SizedBox(height: 28),
              Text(
                'Application Submitted!',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 21, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Text(
                'Your documents and details are under review.\nWe\'ll notify you as soon as your account is approved.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.textSecondary, height: 1.5),
              ),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    DashboardScreen.route,
                    (route) => false,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Go to Dashboard', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
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
