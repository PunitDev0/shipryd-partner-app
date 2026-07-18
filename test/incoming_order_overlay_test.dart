import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:partner/core/mock_backend.dart';
import 'package:partner/data/app_store.dart';
import 'package:partner/data/models.dart';
import 'package:partner/widgets/incoming_order_overlay.dart';

Parcel _makeRequest(String id) => Parcel(
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
      status: ParcelStatus.requested,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // flutter_secure_storage has no platform-channel implementation under
  // `flutter test` — stub it out with an in-memory map so AppStore.init()
  // (which reads/writes tokens) doesn't throw MissingPluginException.
  const secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final secureStorageValues = <String, String>{};

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    secureStorageValues.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      secureStorageChannel,
      (MethodCall call) async {
        switch (call.method) {
          case 'read':
            return secureStorageValues[call.arguments['key']];
          case 'write':
            secureStorageValues[call.arguments['key'] as String] = call.arguments['value'] as String;
            return null;
          case 'delete':
            secureStorageValues.remove(call.arguments['key']);
            return null;
          case 'readAll':
            return secureStorageValues;
          default:
            return null;
        }
      },
    );
    await AppStore.instance.init();
    // The mock API requires a real session (bearer token) for every booking
    // action, same as a real backend would. AppStore is a singleton that
    // stays "logged in" across tests in this file, but the mock secure
    // storage above is wiped every test — so always re-login here to get a
    // token that actually matches what's in the (fresh) mock storage.
    // Uses the backend's demo phone number, which bypasses Fast2SMS and
    // always accepts OTP "123456" (see shipryd-backend/src/utils/otp.js).
    const demoPhone = '9999999999';
    await AppStore.instance.sendOtp(demoPhone);
    await AppStore.instance.verifyOtp(phone: demoPhone, otp: '123456', isRegister: false);
  });

  /// The store's `parcels` list is a cache of whatever [MockBackend] holds —
  /// tests that exercise accept/decline (which go through the mock API) need
  /// the parcel to exist on the backend side, not just in AppStore's cache.
  void seedActiveRequest(Parcel parcel) {
    MockBackend.instance.parcels.insert(0, parcel);
    AppStore.instance.parcels = MockBackend.instance.parcels;
    AppStore.instance.activeRequest = parcel;
  }

  testWidgets('Accepting a request moves it to pending and clears the overlay',
      (tester) async {
    final store = AppStore.instance;
    final parcel = _makeRequest('TEST_ACCEPT_1');
    seedActiveRequest(parcel);

    await tester.pumpWidget(
      MaterialApp(home: IncomingOrderOverlay(parcel: parcel)),
    );

    await tester.tap(find.textContaining('Accept'));
    await tester.pump(const Duration(seconds: 2));

    expect(store.findParcelById(parcel.id)!.status, ParcelStatus.pending);
    expect(store.activeRequest, isNull);

    await tester.pumpWidget(const SizedBox());
    MockBackend.instance.parcels.removeWhere((p) => p.id == parcel.id);
  });

  testWidgets('Declining a request removes it from the queue', (tester) async {
    final store = AppStore.instance;
    final parcel = _makeRequest('TEST_DECLINE_1');
    seedActiveRequest(parcel);

    await tester.pumpWidget(
      MaterialApp(home: IncomingOrderOverlay(parcel: parcel)),
    );

    await tester.tap(find.text('Decline'));
    await tester.pump(const Duration(seconds: 2));

    expect(store.findParcelById(parcel.id), isNull);
    expect(store.activeRequest, isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Countdown ring starts at 15 seconds', (tester) async {
    final parcel = _makeRequest('TEST_COUNTDOWN_1');
    seedActiveRequest(parcel);

    await tester.pumpWidget(
      MaterialApp(home: IncomingOrderOverlay(parcel: parcel)),
    );

    expect(find.text('Accept (15 s)'), findsOneWidget);

    await tester.tap(find.text('Decline'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox());
  });
}
