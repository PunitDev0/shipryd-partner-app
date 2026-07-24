import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:partner/shared/state/app_store.dart';
import 'package:partner/shared/theme/app_colors.dart';
import 'package:partner/shared/widgets/bottom_nav.dart';
import 'package:partner/shared/utils/formatters.dart';
import 'package:partner/shared/models/models.dart';
import 'package:partner/features/wallet/presentation/earnings_screen.dart';
import 'bank_details_screen.dart';
import 'edit_profile_screen.dart';
import 'vehicle_info_screen.dart';
import 'package:partner/features/onboarding/presentation/registration_documents_screen.dart';
import 'package:partner/features/support/presentation/support_screen.dart';
import 'package:partner/features/notifications/presentation/notifications_screen.dart';
import 'settings_screen.dart';
import 'logout_screen.dart';
import 'package:partner/features/wallet/presentation/ratings_screen.dart';

class ProfileScreen extends StatelessWidget {
  static const route = '/profile';
  const ProfileScreen({super.key});

  void _showLegal(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text(content, style: GoogleFonts.inter(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.inter(color: AppColors.primaryDark, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _getKycStatusText(KycStatus? status) {
    if (status == KycStatus.verified) return 'Verified';
    if (status == KycStatus.pending) return 'Pending';
    if (status == KycStatus.failed) return 'Failed';
    return 'Not Verified';
  }

  Color _getKycStatusColor(KycStatus? status) {
    if (status == KycStatus.verified) return const Color(0xFF2E7D32); // Green
    if (status == KycStatus.pending) return Colors.orange;
    if (status == KycStatus.failed) return Colors.red;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppStore.instance,
      builder: (context, _) {
        final profile = AppStore.instance.profile;
        final kycStatus = AppStore.instance.kyc?.status;

        return Scaffold(
          backgroundColor: AppColors.scaffoldBg,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              'Profile',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: Colors.black, size: 24),
                onPressed: () => Navigator.pushNamed(context, SettingsScreen.route),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero Profile Card
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF9E7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 76,
                                height: 76,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                  image: const DecorationImage(
                                    image: AssetImage('assets/default_profile_icon.png'),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          profile.name,
                                          style: GoogleFonts.inter(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.black,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(
                                          Icons.verified_rounded,
                                          color: Color(0xFFF2C230),
                                          size: 18,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.phone_outlined, size: 14, color: Colors.black54),
                                        const SizedBox(width: 6),
                                        Text(
                                          profile.phone,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            color: Colors.black87,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    GestureDetector(
                                      onTap: () => Navigator.pushNamed(context, RatingsScreen.route),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.star_outline_rounded, size: 14, color: Colors.black54),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${profile.rating.toStringAsFixed(1)} Ratings',
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              color: Colors.black87,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded, color: Colors.black54),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Wallet & KYC Mini-Cards
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => Navigator.pushNamed(context, EarningsScreen.route),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFFEF9E7),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.account_balance_wallet_outlined,
                                            size: 16,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Wallet Balance',
                                                style: GoogleFonts.inter(
                                                  fontSize: 10,
                                                  color: Colors.grey[600],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                formatAmount(AppStore.instance.walletBalance),
                                                style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.chevron_right_rounded, size: 14, color: Colors.black54),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const RegistrationDocumentsScreen(isOnboarding: false),
                                    ),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFFEF9E7),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.gpp_good_outlined,
                                            size: 16,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'KYC Verified',
                                                style: GoogleFonts.inter(
                                                  fontSize: 10,
                                                  color: Colors.grey[600],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _getKycStatusText(kycStatus),
                                                style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w800,
                                                  color: _getKycStatusColor(kycStatus),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.chevron_right_rounded, size: 14, color: Colors.black54),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  Text(
                    'Account',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Account card list
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black.withOpacity(0.04)),
                    ),
                    child: Column(
                      children: [
                        _MenuItem(
                          icon: Icons.person_outline_rounded,
                          label: 'Personal Information',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                          ),
                        ),
                        _divider(),
                        _MenuItem(
                          icon: Icons.account_balance_outlined,
                          label: 'Bank Details',
                          onTap: () => Navigator.pushNamed(context, BankDetailsScreen.route),
                        ),
                        _divider(),
                        _MenuItem(
                          icon: Icons.motorcycle_rounded,
                          label: 'Vehicle Information',
                          onTap: () => Navigator.pushNamed(context, VehicleInfoScreen.route),
                        ),
                        _divider(),
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
                        _divider(),
                        _MenuItem(
                          icon: Icons.lock_outline_rounded,
                          label: 'Change Password',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('OTP-based secure login is enabled. Password is not required.'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  Text(
                    'Support',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Support card list
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black.withOpacity(0.04)),
                    ),
                    child: Column(
                      children: [
                        _MenuItem(
                          icon: Icons.headset_mic_outlined,
                          label: 'Help & Support',
                          onTap: () => Navigator.pushNamed(context, SupportScreen.route),
                        ),
                        _divider(),
                        _MenuItem(
                          icon: Icons.security_outlined,
                          label: 'Privacy Policy',
                          onTap: () => _showLegal(
                            context,
                            'Privacy Policy',
                            'SHIPRYD Partner collects only the delivery, location and KYC '
                                'data required to operate the parcel-handover workflow. '
                                'Your data is never sold to third parties.',
                          ),
                        ),
                        _divider(),
                        _MenuItem(
                          icon: Icons.description_outlined,
                          label: 'Terms & Conditions',
                          onTap: () => _showLegal(
                            context,
                            'Terms & Conditions',
                            'By using SHIPRYD Partner you agree to handle parcels with '
                                'due care, confirm receipt honestly, and keep your KYC '
                                'and bank details up to date.',
                          ),
                        ),
                        _divider(),
                        _MenuItem(
                          icon: Icons.info_outline_rounded,
                          label: 'About ShipRyd Partner',
                          onTap: () => _showLegal(
                            context,
                            'About ShipRyd Partner',
                            'SHIPRYD Partner App v1.0.0. A premium, secure delivery partner management app built for speed, safety, and reliability.',
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Logout button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, LogoutScreen.route),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFEF9E7),
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.logout_rounded, color: Colors.black87, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Logout',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          bottomNavigationBar: const BottomNav(currentIndex: 4),
        );
      },
    );
  }

  Widget _divider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.black.withOpacity(0.04),
      indent: 64,
      endIndent: 16,
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF9E7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: Colors.black38,
            ),
          ],
        ),
      ),
    );
  }
}
