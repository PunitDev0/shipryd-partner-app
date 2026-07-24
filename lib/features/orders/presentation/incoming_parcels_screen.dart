import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:partner/shared/models/order.dart';
import 'package:partner/shared/navigation/order_navigation.dart';
import 'package:partner/shared/state/order_store.dart';
import 'package:partner/shared/theme/app_colors.dart';
import 'package:partner/shared/utils/formatters.dart';
import 'package:partner/shared/widgets/bottom_nav.dart';

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

  Widget _orderList(List<Order> orders, String category) {
    if (orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF9E7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_shipping_outlined,
                  size: 48,
                  color: Color(0xFFF2C230),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No $category Orders Yet',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Stay online to receive real-time parcel delivery & ride requests near you.',
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
      itemCount: orders.length,
      separatorBuilder: (context, i) => const SizedBox(height: 14),
      itemBuilder: (context, i) {
        final order = orders[i];
        final isRide = order is RideOrder;
        final amount = order.earning > 0 ? order.earning : (order.codAmount > 0 ? order.codAmount : 150.0);

        return InkWell(
          onTap: () => _openOrder(order),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: order.viewed ? AppColors.border : const Color(0xFFF2C230),
                width: order.viewed ? 1 : 1.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row (Type Badge + ID + Time)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isRide ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isRide ? Icons.directions_bike_rounded : Icons.inventory_2_rounded,
                            size: 14,
                            color: isRide ? Colors.green[700] : Colors.orange[800],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isRide ? 'RIDE REQUEST' : 'PARCEL DELIVERY',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: isRide ? Colors.green[800] : Colors.orange[900],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatTime(order.createdAt),
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Pickup & Drop Locations
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        const Icon(Icons.circle, size: 10, color: Colors.green),
                        Container(
                          width: 1.5,
                          height: 24,
                          color: Colors.grey[300],
                        ),
                        const Icon(Icons.location_on_rounded, size: 14, color: Colors.red),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.fromAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            order.toAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 10),

                // Bottom Fare & View Details Action
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formatAmount(amount),
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          'View Details',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFD4A017),
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: Color(0xFFD4A017),
                        ),
                      ],
                    ),
                  ],
                ),
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
            automaticallyImplyLeading: true,
            elevation: 0,
            backgroundColor: AppColors.background,
            title: Text(
              'Incoming Orders & Rides',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
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
                Tab(text: 'New (${newOrders.length})'),
                Tab(text: 'In Progress (${inProgress.length})'),
                Tab(text: 'All (${all.length})'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _orderList(newOrders, 'New'),
              _orderList(inProgress, 'In Progress'),
              _orderList(all, 'Active'),
            ],
          ),
          bottomNavigationBar: const BottomNav(currentIndex: 2),
        );
      },
    );
  }
}
