import 'package:flutter/foundation.dart';

import 'package:partner/core/socket_client.dart';
import 'package:partner/shared/data/order_repository.dart';
import 'package:partner/shared/models/order.dart';

/// Sole owner of order data (both Parcel and Ride) — the live `parcels`
/// cache, the incoming-offer queue, and the `order:request`/
/// `order:request:expired` socket wiring live here and nowhere else.
///
/// This stays one shared store rather than being split per domain because
/// an incoming offer's type isn't known until its socket payload arrives —
/// splitting the listener across two controllers would either duplicate it
/// or force them to coordinate, reintroducing the cross-domain coupling
/// this refactor removes. Domain separation instead happens one layer up,
/// via `ParcelController`/`RideController`, which are statically typed to
/// their own [Order] subtype and are the only thing parcel/ride screens
/// are allowed to import.
class OrderStore extends ChangeNotifier {
  OrderStore._();
  static final OrderStore instance = OrderStore._();

  OrderRepository? _repository;

  /// Must be called once (see `AppStore.init`) before any other method.
  /// Also the seam tests use to inject a fake repository instead of
  /// hitting the network.
  void configure(OrderRepository repository) {
    _repository = repository;
  }

  OrderRepository get _repo {
    final repository = _repository;
    if (repository == null) {
      throw StateError('OrderStore.configure() must be called before use');
    }
    return repository;
  }

  List<Order> orders = [];
  List<Map<String, dynamic>> demandSectors = [];

  /// Offers currently awaiting an accept/decline decision, oldest first.
  /// [activeOffer] — the one shown in the overlay — is always the front of
  /// this queue; resolving it (accept/decline/expire) automatically
  /// promotes the next one. Previously only a single nullable
  /// `activeRequest` existed, so a second offer arriving while one was
  /// already showing was silently dropped — never shown, never actionable.
  final List<Order> _pendingOffers = [];

  Order? get activeOffer => _pendingOffers.isEmpty ? null : _pendingOffers.first;
  List<Order> get pendingOffers => List.unmodifiable(_pendingOffers);

  Future<void> refresh() async {
    orders = await _repo.getOrders();
    await fetchDemandHeatmap();
    notifyListeners();
  }

  Future<void> fetchDemandHeatmap() async {
    try {
      demandSectors = await _repo.getDemandHeatmap();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to fetch demand heatmap: $e');
    }
  }

  /// Public wrapper for [notifyListeners] — allows external callers (e.g., UI
  /// widgets handling test orders) to trigger a rebuild without accessing the
  /// protected [notifyListeners] method directly.
  void notify() => notifyListeners();

  void reset() {
    orders = [];
    _pendingOffers.clear();
  }

  void clearPendingOffers() {
    _pendingOffers.clear();
  }

  // ---------------- Socket wiring ----------------

  void connect(String accessToken) {
    SocketClient.instance.connect(accessToken);
    final socket = SocketClient.instance.socket;

    socket?.on('order:request', (data) {
      receiveOffer(Order.fromJson(Map<String, dynamic>.from(data as Map)));
    });

    socket?.on('order:request:expired', (data) {
      expireOffer((data as Map)['bookingId'] as String?);
    });
  }

  /// Enqueues a newly-offered order. Unconditional — every offer is
  /// queued, never dropped, which is what fixes the historical bug where a
  /// second offer arriving while one was already showing silently
  /// vanished (previously `activeRequest ??= parcel` only ever kept the
  /// first). Also the seam tests use to simulate an `order:request` event
  /// without a real socket.
  void receiveOffer(Order order) {
    orders.insert(0, order);
    _pendingOffers.add(order);
    notifyListeners();
  }

  /// An offer expired server-side (18s window ran out with nobody
  /// accepting) or was taken by another partner.
  void expireOffer(String? bookingId) {
    _pendingOffers.removeWhere((o) => o.id == bookingId);
    orders.removeWhere((o) => o.id == bookingId && o.status == OrderStatus.requested);
    notifyListeners();
  }

  void disconnect() {
    SocketClient.instance.disconnect();
    reset();
  }

  // ---------------- Lookup ----------------

  Order? findById(String id) {
    for (final order in orders) {
      if (order.id == id) return order;
    }
    return null;
  }

  Future<void> markViewed(String id) async {
    final order = findById(id);
    if (order == null || order.viewed) return;
    order.viewed = true;
    notifyListeners();
  }

  // ---------------- Offer lifecycle (Porter-style accept/reject) ----------------

  Future<void> acceptOffer(String id) async {
    if (id.startsWith('test_')) {
      final offer = _pendingOffers.where((o) => o.id == id).firstOrNull;
      if (offer != null) {
        offer.status = OrderStatus.pending;
        if (!orders.any((o) => o.id == id)) orders.insert(0, offer);
      }
      _pendingOffers.removeWhere((o) => o.id == id);
      notifyListeners();
      return;
    }
    await _repo.accept(id);
    await refresh();
    _pendingOffers.removeWhere((o) => o.id == id);
    notifyListeners();
  }

  Future<void> declineOffer(String id, {bool timedOut = false}) async {
    if (id.startsWith('test_')) {
      orders.removeWhere((o) => o.id == id);
      _pendingOffers.removeWhere((o) => o.id == id);
      notifyListeners();
      return;
    }
    await _repo.cancel(id);
    orders.removeWhere((o) => o.id == id);
    _pendingOffers.removeWhere((o) => o.id == id);
    notifyListeners();
  }

  // ---------------- Order lifecycle (post-accept) ----------------

  Future<Order> scanOrCreate(String code) async {
    final order = await _repo.scanOrCreate(code);
    await refresh();
    return order;
  }

  Future<void> updateStatus(String id, String status, {String? otp, String? proofPath}) async {
    if (id.startsWith('test_')) {
      final order = findById(id);
      if (order != null) {
        order.rawStatus = status;
        if (status == 'picked_up') {
          order.status = OrderStatus.pickedUp;
        } else if (status == 'delivered') {
          order.status = OrderStatus.received;
        }
      }
      notifyListeners();
      return;
    }
    await _repo.updateStatus(id, status, otp: otp, proofPath: proofPath);
    await refresh();
  }

  Future<void> markPickedUp(String id, {String? otp, String? proofPath}) async {
    if (id.startsWith('test_')) {
      final order = findById(id);
      if (order != null) {
        order.status = OrderStatus.pickedUp;
        order.rawStatus = 'picked';
        order.proofPhotoPath = proofPath;
      }
      notifyListeners();
      return;
    }
    await _repo.updateStatus(id, 'picked_up', otp: otp, proofPath: proofPath);
    await refresh();
  }

  Future<void> completeOrder(String id, {String? proofPath}) async {
    if (id.startsWith('test_')) {
      final order = findById(id);
      if (order != null) {
        order.status = OrderStatus.received;
        order.receivedAt = DateTime.now();
        order.proofPhotoPath = proofPath;
      }
      notifyListeners();
      return;
    }
    await _repo.updateStatus(id, 'delivered', proofPath: proofPath);
    await refresh();
  }

  Future<void> cancelOrder(String id) async {
    if (id.startsWith('test_')) {
      final order = findById(id);
      if (order != null) order.status = OrderStatus.canceled;
      notifyListeners();
      return;
    }
    await _repo.cancel(id);
    await refresh();
  }



  // ---------------- Status-filter getters (mixed-feed screens) ----------------

  List<Order> get pendingNewOrders => orders.where((o) => o.status == OrderStatus.pending && !o.viewed).toList();
  List<Order> get pendingInProgressOrders =>
      orders.where((o) => (o.status == OrderStatus.pending && o.viewed) || o.status == OrderStatus.pickedUp).toList();
  List<Order> get allPendingOrders =>
      orders.where((o) => o.status == OrderStatus.pending || o.status == OrderStatus.pickedUp).toList();
  List<Order> get receivedOrders => orders.where((o) => o.status == OrderStatus.received).toList();
  List<Order> get canceledOrders => orders.where((o) => o.status == OrderStatus.canceled).toList();
  List<Order> get historyOrders => orders
      .where((o) => o.status == OrderStatus.received || o.status == OrderStatus.canceled)
      .toList()
    ..sort((a, b) => (b.receivedAt ?? b.createdAt).compareTo(a.receivedAt ?? a.createdAt));

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  int get todayReceivedCount => receivedOrders.where((o) => _isToday(o.receivedAt!)).length;

  Future<Map<String, dynamic>> initiatePayment({required double amount, required String bookingId}) async {
    return _repo.initiatePayment(amount: amount, bookingId: bookingId);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
