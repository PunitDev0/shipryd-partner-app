import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:partner/features/orders/presentation/incoming_parcels_screen.dart';
import 'package:partner/features/orders/presentation/parcel_history_screen.dart';
import 'package:partner/features/parcel/presentation/scan_parcel_screen.dart';
import 'package:partner/features/profile/presentation/profile_screen.dart';
import 'package:partner/features/wallet/presentation/earnings_screen.dart';
import 'package:partner/shared/models/models.dart';
import 'package:partner/shared/navigation/order_navigation.dart';
import 'package:partner/shared/state/app_store.dart';
import 'package:partner/shared/state/order_store.dart';
import 'package:partner/shared/theme/app_colors.dart';
import 'package:partner/shared/utils/formatters.dart';
import 'package:partner/shared/widgets/order_card.dart';

class DashboardScreen extends StatelessWidget {
  static const route = '/dashboard';
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([AppStore.instance, OrderStore.instance]),
      builder: (context, _) {
        final store = AppStore.instance;
        final orderStore = OrderStore.instance;
        final preview = orderStore.allPendingOrders.take(2).toList();
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                try {
                  await store.refresh();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to refresh: $e')),
                    );
                  }
                }
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Good Morning, ${store.profile.name.split(' ').first} 👋',
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Here's your overview",
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _OnlineToggle(
                        online: store.isOnline,
                        enabled: store.approvalStatus == ApprovalStatus.approved,
                        onChanged: store.setOnline,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (store.approvalStatus != ApprovalStatus.approved)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.hourglass_top_rounded, size: 18, color: AppColors.primaryDark),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              store.approvalStatus == ApprovalStatus.rejected
                                  ? 'Your KYC was rejected. Please re-upload your documents.'
                                  : "Your KYC is under review. We'll notify you once you're approved to go online.",
                              style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (!store.isOnline)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.inputBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.wifi_off_rounded, size: 18, color: AppColors.textSecondary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "You're offline. Go online to start receiving order requests.",
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (store.isBroadcastingLocation)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_rounded, size: 18, color: AppColors.success),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Broadcasting your live location so nearby orders can reach you',
                              style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Stat cards
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: "Today's Received",
                          value: '${orderStore.todayReceivedCount}',
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _StatCard(
                          label: "Today's Earnings",
                          value: formatAmount(store.todayEarnings),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Quick actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _QuickAction(
                        icon: Icons.qr_code_scanner_rounded,
                        label: 'Scan Parcel',
                        highlighted: true,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ScanParcelScreen()),
                        ),
                      ),
                      _QuickAction(
                        icon: Icons.move_to_inbox_rounded,
                        label: 'Incoming',
                        onTap: () => Navigator.pushNamed(
                            context, IncomingParcelsScreen.route),
                      ),
                      _QuickAction(
                        icon: Icons.receipt_long_rounded,
                        label: 'History',
                        onTap: () => Navigator.pushNamed(
                            context, ParcelHistoryScreen.route),
                      ),
                      _QuickAction(
                        icon: Icons.account_balance_wallet_rounded,
                        label: 'Earnings',
                        onTap: () =>
                            Navigator.pushNamed(context, EarningsScreen.route),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // Incoming Parcels header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Incoming Parcels',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(
                            context, IncomingParcelsScreen.route),
                        child: Text(
                          'View All',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (preview.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No incoming parcels right now',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    )
                  else
                    ...preview.map(
                      (order) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: OrderCard(
                          orderId: order.id,
                          location: order.fromAddress,
                          time: formatTime(order.createdAt),
                          trailing: order.viewed
                              ? OrderCardTrailing.inProgress
                              : OrderCardTrailing.newBadge,
                          onTap: () => OrderNavigation.pushDetails(context, order),
                        ),
                      ),
                    ),
                  const SizedBox(height: 90),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: const _BottomNav(currentIndex: 0),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          floatingActionButton: SizedBox(
            width: 58,
            height: 58,
            child: FloatingActionButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ScanParcelScreen()),
              ),
              backgroundColor: AppColors.primary,
              elevation: 3,
              shape: const CircleBorder(),
              child: const Icon(
                Icons.qr_code_scanner_rounded,
                color: AppColors.black,
                size: 26,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OnlineToggle extends StatelessWidget {
  final bool online;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  const _OnlineToggle({required this.online, required this.onChanged, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? () => onChanged(!online) : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: online ? AppColors.primaryLight : AppColors.inputBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: online ? AppColors.primary : AppColors.border,
              width: 1.2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: online ? AppColors.success : AppColors.textTertiary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                online ? 'Online' : 'Offline',
                style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700),
              ),
              Transform.scale(
                scale: 0.7,
                child: Switch(
                  value: online,
                  onChanged: enabled ? onChanged : null,
                  activeThumbColor: AppColors.primaryDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlighted;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: highlighted
                  ? AppColors.primaryLight
                  : const Color(0xFFF6F6F8),
              borderRadius: BorderRadius.circular(16),
              border: highlighted
                  ? Border.all(color: AppColors.primary, width: 1.4)
                  : null,
            ),
            child: Icon(
              icon,
              size: 24,
              color: highlighted
                  ? AppColors.primaryDark
                  : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  const _BottomNav({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    Widget item(
      BuildContext context,
      IconData icon,
      String label,
      int index, {
      String? route,
    }) {
      final selected = index == currentIndex;
      return Expanded(
        child: InkWell(
          onTap: route == null || selected
              ? null
              : () => Navigator.pushNamed(context, route),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? AppColors.black : AppColors.textTertiary,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.black : AppColors.textTertiary,
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
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: Row(
        children: [
          item(context, Icons.home_rounded, 'Dashboard', 0),
          item(context, Icons.move_to_inbox_outlined, 'Incoming', 1,
              route: IncomingParcelsScreen.route),
          const Expanded(child: SizedBox()), // notch space for FAB
          item(context, Icons.receipt_long_outlined, 'History', 2,
              route: ParcelHistoryScreen.route),
          item(context, Icons.person_outline_rounded, 'Profile', 3,
              route: ProfileScreen.route),
        ],
      ),
    );
  }
}
