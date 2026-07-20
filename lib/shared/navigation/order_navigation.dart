import 'package:flutter/material.dart';

import 'package:partner/features/parcel/presentation/parcel_details_screen.dart';
import 'package:partner/features/ride/presentation/ride_details_screen.dart';
import 'package:partner/features/orders/presentation/pickup_tracking_screen.dart';
import 'package:partner/shared/models/order.dart';
import 'package:partner/shared/state/order_store.dart';

/// The single place in the app that turns an [Order] into "which details
/// screen do I open." Every call site that used to re-derive
/// `orderType == OrderType.ride` by hand now goes through here instead —
/// since [Order] is `sealed`, this `switch` is exhaustive and the compiler
/// rejects the build if a third order type is ever added without updating
/// it, which is what actually prevents ride/parcel misrouting from
/// silently regressing.
class OrderNavigation {
  const OrderNavigation._();

  static Widget detailsScreenFor(Order order) {
    final freshOrder = OrderStore.instance.findById(order.id) ?? order;
    if (freshOrder.status == OrderStatus.pending || freshOrder.status == OrderStatus.pickedUp) {
      return PickupTrackingScreen(orderId: freshOrder.id);
    }
    return switch (freshOrder) {
      ParcelOrder() => ParcelDetailsScreen(parcelId: freshOrder.id),
      RideOrder() => RideDetailsScreen(rideId: freshOrder.id),
    };
  }

  static Future<T?> pushDetails<T>(BuildContext context, Order order) {
    return Navigator.push<T>(
      context,
      MaterialPageRoute(builder: (_) => detailsScreenFor(order)),
    );
  }

  static Future<T?> pushReplacementDetails<T, TO>(BuildContext context, Order order) {
    return Navigator.pushReplacement<T, TO>(
      context,
      MaterialPageRoute(builder: (_) => detailsScreenFor(order)),
    );
  }

  static Future<T?> pushDetailsViaNavigatorState<T>(NavigatorState navigator, Order order) {
    return navigator.push<T>(MaterialPageRoute(builder: (_) => detailsScreenFor(order)));
  }
}
