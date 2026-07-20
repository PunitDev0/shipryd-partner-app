import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:partner/shared/models/order.dart';
import 'package:partner/shared/state/order_store.dart';
import 'package:partner/shared/widgets/incoming_order_overlay.dart';

import 'fakes/fake_order_repository.dart';

ParcelOrder _makeRequest(String id) => ParcelOrder(
      id: id,
      orderId: 'ORD$id',
      fromName: 'Test Courier',
      fromAddress: 'Test Pickup Address',
      toAddress: 'Test Drop Address',
      itemType: 'Documents',
      weightKg: 1.0,
      paymentMode: 'Prepaid',
      codAmount: 0,
      earning: 40,
      status: OrderStatus.requested,
      rawStatus: 'searching',
      pickupLat: 28.6273,
      pickupLng: 77.3725,
      dropLat: 28.6300,
      dropLng: 77.3750,
    );

RideOrder _makeRideRequest(String id) => RideOrder(
      id: id,
      orderId: 'ORD$id',
      fromName: 'Test Passenger',
      fromAddress: 'Test Pickup Address',
      toAddress: 'Test Drop Address',
      paymentMode: 'Prepaid',
      codAmount: 0,
      earning: 60,
      status: OrderStatus.requested,
      rawStatus: 'searching',
      pickupLat: 28.6273,
      pickupLng: 77.3725,
      dropLat: 28.6300,
      dropLng: 77.3750,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeOrderRepository fakeRepo;

  setUp(() {
    // Note: the overlay's accept flow also does a best-effort
    // `AppStore.instance.refreshNotifications()` after accepting (see
    // `incoming_order_overlay.dart`) — deliberately not initialized here,
    // since these tests exercise the offer queue in isolation and that
    // call is wrapped in `.catchError` precisely so a not-yet-initialized
    // AppStore (or a real network hiccup) can never affect the accept
    // outcome these tests assert on.
    fakeRepo = FakeOrderRepository();
    OrderStore.instance.configure(fakeRepo);
    OrderStore.instance.reset();
  });

  /// Seeds an offer directly into the store via the same [OrderStore.receiveOffer]
  /// path a real `order:request` socket event drives — no network involved.
  void seedOffer(Order order) {
    fakeRepo.seed(order);
    OrderStore.instance.receiveOffer(order);
  }

  testWidgets('Accepting a request moves it to pending and clears the overlay',
      (tester) async {
    final store = OrderStore.instance;
    final order = _makeRequest('TEST_ACCEPT_1');
    seedOffer(order);

    await tester.pumpWidget(
      MaterialApp(home: IncomingOrderOverlay(order: order)),
    );

    await tester.tap(find.textContaining('Accept'));
    await tester.pump(const Duration(seconds: 2));

    expect(store.findById(order.id)!.status, OrderStatus.pending);
    expect(store.activeOffer, isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Declining a request removes it from the queue', (tester) async {
    final store = OrderStore.instance;
    final order = _makeRequest('TEST_DECLINE_1');
    seedOffer(order);

    await tester.pumpWidget(
      MaterialApp(home: IncomingOrderOverlay(order: order)),
    );

    await tester.tap(find.text('Decline'));
    await tester.pump(const Duration(seconds: 2));

    expect(store.findById(order.id), isNull);
    expect(store.activeOffer, isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Countdown ring starts at 15 seconds', (tester) async {
    final order = _makeRequest('TEST_COUNTDOWN_1');
    seedOffer(order);

    await tester.pumpWidget(
      MaterialApp(home: IncomingOrderOverlay(order: order)),
    );

    expect(find.text('Accept (15 s)'), findsOneWidget);

    await tester.tap(find.text('Decline'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox());
  });

  test(
      'A second offer arriving while one is active is promoted after the '
      'first is resolved (regression test for the dropped-offer bug)',
      () async {
    final store = OrderStore.instance;
    final first = _makeRequest('TEST_QUEUE_1');
    final second = _makeRideRequest('TEST_QUEUE_2');
    seedOffer(first);
    seedOffer(second);

    expect(store.activeOffer!.id, first.id, reason: 'first offer shown first');
    expect(store.pendingOffers.length, 2, reason: 'second offer must not be dropped');

    await store.declineOffer(first.id);

    expect(store.activeOffer!.id, second.id, reason: 'second offer promoted after first resolves');
  });
}
