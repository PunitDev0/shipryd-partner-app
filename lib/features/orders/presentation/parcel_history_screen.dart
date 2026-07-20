import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:partner/shared/models/order.dart';
import 'package:partner/shared/navigation/order_navigation.dart';
import 'package:partner/shared/state/order_store.dart';
import 'package:partner/shared/theme/app_colors.dart';
import 'package:partner/shared/utils/formatters.dart';

class ParcelHistoryScreen extends StatefulWidget {
  static const route = '/history';
  const ParcelHistoryScreen({super.key});

  @override
  State<ParcelHistoryScreen> createState() => _ParcelHistoryScreenState();
}

class _ParcelHistoryScreenState extends State<ParcelHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _historyList(List<Order> items) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'Nothing here yet',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: items.length,
      separatorBuilder: (context, i) => Divider(
        color: AppColors.border,
        height: 24,
      ),
      itemBuilder: (context, i) {
        final order = items[i];
        final canceled = order.status == OrderStatus.canceled;
        final isRide = order is RideOrder;
        return InkWell(
          onTap: () => OrderNavigation.pushDetails(context, order),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: canceled
                      ? const Color(0xFFFDECEA)
                      : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  canceled
                      ? Icons.cancel_rounded
                      : (isRide ? Icons.directions_car_rounded : Icons.inventory_2_rounded),
                  color: canceled ? const Color(0xFFE53935) : AppColors.primaryDark,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.id,
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      order.fromAddress,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      formatDateTime(order.receivedAt ?? order.createdAt),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                canceled ? 'Canceled' : '+${formatAmount(order.earning)}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: canceled ? const Color(0xFFE53935) : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: OrderStore.instance,
      builder: (context, _) {
        final store = OrderStore.instance;
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, size: 22),
              onPressed: () => Navigator.maybePop(context),
            ),
            title: Text(
              'Parcel History',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              labelColor: AppColors.textPrimary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelStyle: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Received'),
                Tab(text: 'Canceled'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _historyList(store.historyOrders),
              _historyList(store.receivedOrders),
              _historyList(store.canceledOrders),
            ],
          ),
        );
      },
    );
  }
}
