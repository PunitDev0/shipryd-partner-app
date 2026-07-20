import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:partner/shared/models/order.dart';
import 'package:partner/shared/state/order_store.dart';
import 'package:partner/shared/theme/app_colors.dart';

enum OrderCardTrailing { inProgress, newBadge, none }

/// List-item card used by the mixed ride+parcel feed screens (dashboard,
/// incoming list, history). Looks up the live [Order] by id so it reflects
/// state changes reactively, same as the detail screens.
class OrderCard extends StatelessWidget {
  final String orderId;
  final String location;
  final String time;
  final OrderCardTrailing trailing;
  final VoidCallback? onTap;

  const OrderCard({
    super.key,
    required this.orderId,
    required this.location,
    required this.time,
    this.trailing = OrderCardTrailing.none,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final order = OrderStore.instance.findById(orderId);
    final isRide = order is RideOrder;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1.2),
        ),
        child: Row(
          children: [
            // Parcel/ride icon
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isRide ? Icons.directions_car_rounded : Icons.inventory_2_rounded,
                color: AppColors.primaryDark,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    orderId,
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    location,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    time,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),

            // Trailing
            if (trailing == OrderCardTrailing.inProgress)
              Text(
                'In Progress',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              )
            else if (trailing == OrderCardTrailing.newBadge)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    time,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'New',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.black,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
