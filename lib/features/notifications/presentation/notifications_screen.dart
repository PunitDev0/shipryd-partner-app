import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:partner/shared/models/models.dart';
import 'package:partner/shared/state/app_store.dart';
import 'package:partner/shared/theme/app_colors.dart';
import 'package:partner/shared/utils/formatters.dart';
import 'package:partner/shared/widgets/bottom_nav.dart';

class NotificationsScreen extends StatefulWidget {
  static const route = '/notifications';
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  IconData _getNotificationIcon(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('earning') || lower.contains('payout') || lower.contains('wallet') || lower.contains('credited')) {
      return Icons.account_balance_wallet_rounded;
    } else if (lower.contains('order') || lower.contains('parcel') || lower.contains('trip') || lower.contains('booking')) {
      return Icons.local_shipping_rounded;
    } else if (lower.contains('bonus') || lower.contains('incentive') || lower.contains('reward')) {
      return Icons.card_giftcard_rounded;
    }
    return Icons.notifications_rounded;
  }

  Color _getNotificationColor(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('earning') || lower.contains('payout') || lower.contains('wallet') || lower.contains('credited')) {
      return const Color(0xFF2E7D32);
    } else if (lower.contains('order') || lower.contains('parcel') || lower.contains('trip') || lower.contains('booking')) {
      return const Color(0xFF1976D2);
    } else if (lower.contains('bonus') || lower.contains('incentive') || lower.contains('reward')) {
      return const Color(0xFFD4A017);
    }
    return AppColors.primary;
  }

  Widget _notificationList(List<NotificationItem> items, String filterType) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF9E7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_off_outlined,
                  size: 48,
                  color: Color(0xFFF2C230),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No $filterType Notifications',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'You\'re all caught up! Order alerts, earnings updates and announcements will appear here.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: items.length,
      separatorBuilder: (context, i) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final n = items[i];
        final iconColor = _getNotificationColor(n.title);

        return InkWell(
          onTap: () {
            if (!n.read) {
              AppStore.instance.markNotificationRead(n);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: n.read ? Colors.white : const Color(0xFFFFFDF5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: n.read ? AppColors.border : const Color(0xFFF2C230).withValues(alpha: 0.5),
                width: n.read ? 1 : 1.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Notification Category Icon
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getNotificationIcon(n.title),
                    size: 20,
                    color: iconColor,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              n.title,
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: n.read ? FontWeight.w700 : FontWeight.w900,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (!n.read) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE53935),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        n.subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        formatDateTime(n.time),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (n.trailingAmount != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    n.trailingAmount!,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppColors.success,
                    ),
                  ),
                ] else if (n.showChevron) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.textTertiary,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppStore.instance,
      builder: (context, _) {
        final all = AppStore.instance.notifications;
        final unread = all.where((n) => !n.read).toList();

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            centerTitle: true,
            automaticallyImplyLeading: true,
            elevation: 0,
            backgroundColor: AppColors.background,
            title: Text(
              'Notifications',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            actions: [
              if (unread.isNotEmpty)
                TextButton.icon(
                  onPressed: AppStore.instance.markAllNotificationsRead,
                  icon: const Icon(Icons.done_all_rounded, size: 16, color: Color(0xFFD4A017)),
                  label: Text(
                    'Mark Read',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFD4A017),
                    ),
                  ),
                ),
            ],
            bottom: TabBar(
              controller: _tabController,
              labelColor: AppColors.textPrimary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: const Color(0xFFF2C230),
              indicatorWeight: 3,
              labelStyle: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
              unselectedLabelStyle: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              tabs: [
                Tab(text: 'All (${all.length})'),
                Tab(text: 'Unread (${unread.length})'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _notificationList(all, 'All'),
              _notificationList(unread, 'Unread'),
            ],
          ),
          bottomNavigationBar: const BottomNav(currentIndex: 3),
        );
      },
    );
  }
}
