import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:partner/features/orders/presentation/dashboard_screen.dart';
import 'package:partner/features/orders/presentation/incoming_parcels_screen.dart';
import 'package:partner/features/profile/presentation/profile_screen.dart';
import 'package:partner/features/wallet/presentation/earnings_screen.dart';
import 'package:partner/features/notifications/presentation/notifications_screen.dart';
import 'package:partner/shared/theme/app_colors.dart';

class BottomNav extends StatelessWidget {
  final int currentIndex;
  const BottomNav({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    Widget item(
      BuildContext context,
      IconData icon,
      IconData selectedIcon,
      String label,
      int index,
      String route,
    ) {
      final selected = index == currentIndex;
      return Expanded(
        child: InkWell(
          onTap: selected
              ? null
              : () {
                  // Replace current route to avoid stacking multiple tab screens
                  Navigator.pushReplacementNamed(context, route);
                },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? selectedIcon : icon,
                size: 22,
                color: selected ? AppColors.primary : AppColors.textTertiary,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.primary : AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return BottomAppBar(
      color: AppColors.background,
      elevation: 12,
      height: 68,
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          item(
            context,
            Icons.home_outlined,
            Icons.home_rounded,
            'Home',
            0,
            DashboardScreen.route,
          ),
          item(
            context,
            Icons.account_balance_wallet_outlined,
            Icons.account_balance_wallet_rounded,
            'Earnings',
            1,
            EarningsScreen.route,
          ),
          item(
            context,
            Icons.motorcycle_outlined,
            Icons.motorcycle_rounded,
            'Trips',
            2,
            IncomingParcelsScreen.route,
          ),
          item(
            context,
            Icons.notifications_none_outlined,
            Icons.notifications_rounded,
            'Notifications',
            3,
            NotificationsScreen.route,
          ),
          item(
            context,
            Icons.person_outline_rounded,
            Icons.person_rounded,
            'Profile',
            4,
            ProfileScreen.route,
          ),
        ],
      ),
    );
  }
}
