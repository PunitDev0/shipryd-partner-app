import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:partner/features/parcel/presentation/scan_parcel_screen.dart';
import 'package:partner/shared/models/order.dart';
import 'package:partner/shared/navigation/order_navigation.dart';
import 'package:partner/shared/state/order_store.dart';
import 'package:partner/shared/theme/app_colors.dart';
import 'package:partner/shared/utils/formatters.dart';
import 'package:partner/shared/widgets/order_card.dart';

class IncomingParcelsScreen extends StatefulWidget {
  static const route = '/incoming';
  const IncomingParcelsScreen({super.key});

  @override
  State<IncomingParcelsScreen> createState() => _IncomingParcelsScreenState();
}

class _IncomingParcelsScreenState extends State<IncomingParcelsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openOrder(Order order) => OrderNavigation.pushDetails(context, order);

  Widget _orderList(List<Order> orders) {
    if (orders.isEmpty) {
      return Center(
        child: Text(
          'No parcels here yet',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      itemCount: orders.length,
      separatorBuilder: (context, i) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final order = orders[i];
        return OrderCard(
          orderId: order.id,
          location: order.fromAddress,
          time: formatTime(order.createdAt),
          trailing: order.viewed ? OrderCardTrailing.inProgress : OrderCardTrailing.newBadge,
          onTap: () => _openOrder(order),
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
        final newOrders = store.pendingNewOrders;
        final inProgress = store.pendingInProgressOrders;
        final all = store.allPendingOrders;
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, size: 22),
              onPressed: () => Navigator.maybePop(context),
            ),
            title: Text(
              'Incoming Parcels',
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
              tabs: [
                Tab(text: 'New (${newOrders.length})'),
                Tab(text: 'In Progress (${inProgress.length})'),
                Tab(text: 'All (${all.length})'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _orderList(newOrders),
              _orderList(inProgress),
              _orderList(all),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ScanParcelScreen()),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Scan New Parcel',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
