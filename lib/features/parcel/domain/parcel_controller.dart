import 'package:flutter/foundation.dart';

import 'package:partner/shared/models/order.dart';
import 'package:partner/shared/state/app_store.dart';
import 'package:partner/shared/state/order_store.dart';

/// Statically-typed façade over [OrderStore] for the parcel feature.
///
/// Parcel screens/widgets talk to this — never to [OrderStore] directly and
/// never to anything ride-specific — so there is no method anywhere in the
/// parcel feature that could hand it a [RideOrder]. [findById] narrows the
/// generic [OrderStore] lookup and simply returns `null` if the id belongs
/// to a ride, which parcel screens already render as "not found".
class ParcelController {
  const ParcelController._();

  /// Listenable for `AnimatedBuilder`s — parcel screens rebuild off this
  /// instead of importing [OrderStore] directly.
  static Listenable get listenable => OrderStore.instance;

  static ParcelOrder? findById(String parcelId) {
    final order = OrderStore.instance.findById(parcelId);
    return order is ParcelOrder ? order : null;
  }

  static List<ParcelOrder> get history => OrderStore.instance.historyOrders.whereType<ParcelOrder>().toList();

  static Future<void> markViewed(String parcelId) => OrderStore.instance.markViewed(parcelId);

  static Future<void> markPickedUp(String parcelId, {String? otp, String? proofPath}) =>
      OrderStore.instance.markPickedUp(parcelId, otp: otp, proofPath: proofPath);

  static Future<void> completeDelivery(String parcelId, {String? proofPath}) async {
    await OrderStore.instance.completeOrder(parcelId, proofPath: proofPath);
    await AppStore.instance.refreshWalletAndNotifications();
  }

  static Future<void> cancel(String parcelId) => OrderStore.instance.cancelOrder(parcelId);

  /// Scanning a QR/barcode is a parcel-only concept — rides are never
  /// scanned. If the backend ever returned a ride for a scanned code this
  /// throws instead of silently handing ride data to a parcel screen.
  static Future<ParcelOrder> scanOrCreate(String code) async {
    final order = await OrderStore.instance.scanOrCreate(code);
    await AppStore.instance.refreshNotifications();
    if (order is! ParcelOrder) {
      throw StateError('Scanned booking ${order.id} is not a parcel order');
    }
    return order;
  }
}
