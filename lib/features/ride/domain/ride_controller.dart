import 'package:flutter/foundation.dart';

import 'package:partner/shared/models/order.dart';
import 'package:partner/shared/state/app_store.dart';
import 'package:partner/shared/state/order_store.dart';

/// Statically-typed façade over [OrderStore] for the ride feature — the
/// ride-side mirror of `ParcelController`. Ride screens/widgets talk to
/// this and never see a [ParcelOrder].
class RideController {
  const RideController._();

  /// Listenable for `AnimatedBuilder`s — ride screens rebuild off this
  /// instead of importing [OrderStore] directly.
  static Listenable get listenable => OrderStore.instance;

  static RideOrder? findById(String rideId) {
    final order = OrderStore.instance.findById(rideId);
    return order is RideOrder ? order : null;
  }

  static Future<void> markViewed(String rideId) => OrderStore.instance.markViewed(rideId);

  static Future<void> startTrip(String rideId, {required String otp}) =>
      OrderStore.instance.markPickedUp(rideId, otp: otp);

  static Future<void> completeRide(String rideId) async {
    await OrderStore.instance.completeOrder(rideId);
    await AppStore.instance.refreshWalletAndNotifications();
  }

  static Future<void> cancel(String rideId) => OrderStore.instance.cancelOrder(rideId);
}
