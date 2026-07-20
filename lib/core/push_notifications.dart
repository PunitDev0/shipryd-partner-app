import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:partner/shared/data/partner_service.dart';

/// Runs in a separate isolate when a push arrives while the app is
/// backgrounded/killed — Firebase must be re-initialized here even though
/// `main()` already did it in the foreground isolate.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

/// Registers this device for FCM so the dispatch worker's push (sent
/// alongside every `order:request` socket offer — see `AppStore._connectSocket`)
/// reaches the partner even when the app isn't foregrounded. The existing
/// socket-driven `IncomingOrderOverlay` already covers the foreground case,
/// so this deliberately does no foreground-message handling of its own.
class PushNotifications {
  PushNotifications._();

  static bool _listeningForRefresh = false;

  static Future<void> init(PartnerService partnerService) async {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    final token = await messaging.getToken();
    if (token != null) await _register(partnerService, token);

    if (!_listeningForRefresh) {
      _listeningForRefresh = true;
      messaging.onTokenRefresh.listen((refreshed) => _register(partnerService, refreshed));
    }
  }

  static Future<void> _register(PartnerService partnerService, String token) async {
    try {
      await partnerService.registerFcmToken(token);
    } catch (_) {
      // Best-effort — this device just misses push until the next
      // successful registration (next app open, token refresh, etc.).
    }
  }
}
