import 'package:partner/shared/data/order_repository.dart';
import 'package:partner/shared/models/order.dart';

/// In-memory [OrderRepository] substitute for widget/unit tests — lets
/// [OrderStore] be exercised without a live backend. Seed orders with
/// [seed], then accept/cancel/etc. behave like a minimal in-memory server.
class FakeOrderRepository implements OrderRepository {
  final Map<String, Order> _byId = {};

  void seed(Order order) => _byId[order.id] = order;

  @override
  Future<List<Order>> getOrders({String? status}) async => _byId.values.toList();

  @override
  Future<Order> accept(String id) async {
    final order = _byId[id]!;
    order.status = OrderStatus.pending;
    return order;
  }

  @override
  Future<Order> cancel(String id) async {
    final order = _byId[id]!;
    order.status = OrderStatus.canceled;
    return order;
  }

  @override
  Future<Order> scanOrCreate(String code) async => _byId[code]!;

  @override
  Future<Order> updateStatus(String id, String status, {String? proofPath, String? otp}) async {
    final order = _byId[id]!;
    order.status = switch (status) {
      'picked_up' => OrderStatus.pickedUp,
      'delivered' => OrderStatus.received,
      _ => order.status,
    };
    return order;
  }

  @override
  Future<Map<String, dynamic>> initiatePayment({required double amount, required String bookingId}) async {
    return {
      'simulated': true,
      'qrString': 'upi://pay?pa=mock-merchant@okaxis&pn=ShipRyd&am=$amount&tr=$bookingId&cu=INR',
    };
  }
}
