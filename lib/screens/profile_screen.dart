import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/app_store.dart';
import '../theme/app_colors.dart';
import 'bank_details_screen.dart';
import 'edit_profile_screen.dart';
import 'vehicle_info_screen.dart';
import 'registration_documents_screen.dart';
import 'support_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';
import 'logout_screen.dart';
import 'ratings_screen.dart';

class ProfileScreen extends StatelessWidget {
  static const route = '/profile';
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppStore.instance,
      builder: (context, _) {
        final profile = AppStore.instance.profile;
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Text(
              'Profile',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 12),

                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 3),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      size: 48,
                      color: AppColors.primaryDark,
                    ),
                  ),

                  const SizedBox(height: 16),
                  Text(
                    profile.name,
                    style: GoogleFonts.inter(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile.phone,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 12),

                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, RatingsScreen.route),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          profile.rating.toStringAsFixed(1),
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Text(
                          '${profile.totalDeliveries}+ Deliveries',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textSecondary),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  _MenuItem(
                    icon: Icons.person_outline_rounded,
                    label: 'Personal Info',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                    ),
                  ),
                  _MenuItem(
                    icon: Icons.account_balance_outlined,
                    label: 'Bank Details',
                    onTap: () =>
                        Navigator.pushNamed(context, BankDetailsScreen.route),
                  ),
                  _MenuItem(
                    icon: Icons.local_shipping_outlined,
                    label: 'Vehicle Info',
                    onTap: () =>
                        Navigator.pushNamed(context, VehicleInfoScreen.route),
                  ),
                  _MenuItem(
                    icon: Icons.description_outlined,
                    label: 'Documents',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RegistrationDocumentsScreen(isOnboarding: false),
                      ),
                    ),
                  ),
                  _MenuItem(
                    icon: Icons.notifications_none_rounded,
                    label: 'Notifications',
                    onTap: () =>
                        Navigator.pushNamed(context, NotificationsScreen.route),
                  ),
                  _MenuItem(
                    icon: Icons.headset_mic_outlined,
                    label: 'Support',
                    onTap: () =>
                        Navigator.pushNamed(context, SupportScreen.route),
                  ),
                  _MenuItem(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    onTap: () =>
                        Navigator.pushNamed(context, SettingsScreen.route),
                  ),
                  _MenuItem(
                    icon: Icons.logout_rounded,
                    label: 'Logout',
                    isDestructive: true,
                    onTap: () =>
                        Navigator.pushNamed(context, LogoutScreen.route),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDestructive;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? const Color(0xFFE53935) : AppColors.textPrimary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 21, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: isDestructive
                  ? const Color(0xFFE53935)
                  : AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
