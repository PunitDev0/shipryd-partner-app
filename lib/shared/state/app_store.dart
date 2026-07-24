import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:partner/core/api_client.dart';
import 'package:partner/core/app_exception.dart';
import 'package:partner/core/push_notifications.dart';
import 'package:partner/core/secure_storage.dart';
import 'package:partner/shared/data/auth_service.dart';
import 'package:partner/shared/data/notification_service.dart';
import 'package:partner/shared/data/order_repository.dart';
import 'package:partner/shared/data/partner_service.dart';
import 'package:partner/shared/data/ticket_service.dart';
import 'package:partner/shared/data/wallet_service.dart';
import 'package:partner/shared/models/models.dart';
import 'package:partner/shared/models/rated_trip.dart';
import 'package:partner/shared/state/order_store.dart';

/// App-wide state for the partner app, excluding order data (see
/// [OrderStore] for `List<Order>`/incoming-offer state) — this owns
/// auth/onboarding, wallet, tickets, notifications, and settings. Every
/// read/write delegates to service classes that go through a real Dio
/// client (auth headers, silent token refresh, error mapping) against
/// shipryd-backend. Screens keep using `AppStore.instance` exactly as
/// before: the fields below are now a *cache* of the last server response,
/// refreshed after every mutation.
class AppStore extends ChangeNotifier {
  AppStore._();
  static final AppStore instance = AppStore._();

  static const _prefsKey = 'partner_app_prefs_v2';

  late final Dio _dio;
  late final AuthService _authService;
  late final PartnerService _partnerService;
  late final WalletService _walletService;
  late final TicketService _ticketService;
  late final NotificationService _notificationService;

  bool _initialized = false;
  bool get initialized => _initialized;

  bool isLoggedIn = false;
  bool isRegistered = false;
  ApprovalStatus approvalStatus = ApprovalStatus.pending;
  String? lastAuthError;

  late PartnerProfile profile;
  VehicleInfo? vehicle;
  List<BankAccount> bankAccounts = [];
  List<DocumentItem> documents = [];
  List<Transaction> transactions = [];
  List<NotificationItem> notifications = [];
  List<SupportTicket> tickets = [];
  List<WithdrawalRequest> withdrawals = [];
  TodayIncentives? todayIncentives;
  double codSettlementDue = 0;
  double averageRating = 5.0;
  int totalRatings = 0;
  List<RatedTrip> recentRatedTrips = [];

  bool darkMode = false;
  bool notificationsEnabled = true;
  String language = 'English';

  // ---- registration draft (used while onboarding, before submit) ----
  String draftName = '';
  String draftEmail = '';
  String draftPhone = '';
  PersonalDetails? personalDetails;
  KycDetails? kyc;
  DrivingLicence? drivingLicence;
  BackgroundCheckStatus backgroundCheckStatus = BackgroundCheckStatus.notRequested;
  DateTime? termsAcceptedAt;

  // ---- online/offline (Porter-style toggle), fed to OrderStore for the
  // order:request socket wiring. ----
  bool isOnline = false;

  // ---- location broadcasting: real periodic `location:update` pings to
  // the server while online. ----
  double? currentLat;
  double? currentLng;
  Timer? _locationTimer;
  bool get isBroadcastingLocation => _locationTimer != null;

  Future<void> init() async {
    if (_initialized) return;

    _dio = ApiClient.create(onSessionExpired: _forceLogout);
    _authService = AuthService(_dio);
    _partnerService = PartnerService(_dio);
    _walletService = WalletService(_dio);
    _ticketService = TicketService(_dio);
    _notificationService = NotificationService(_dio);
    OrderStore.instance.configure(OrderRepository(_dio));

    await _loadLocalPrefs();

    if (await _authService.hasSession()) {
      try {
        await _refreshAll();
        isLoggedIn = true;
        await _connectSocket();
      } on AppException {
        isLoggedIn = false;
      }
    }

    _initialized = true;
    notifyListeners();
  }

  Future<void> _loadLocalPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      darkMode = json['darkMode'] as bool? ?? false;
      notificationsEnabled = json['notificationsEnabled'] as bool? ?? true;
      language = json['language'] as String? ?? 'English';
    } catch (_) {
      // ignore corrupt local prefs — device-level settings only
    }
  }

  Future<void> _persistLocalPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode({
      'darkMode': darkMode,
      'notificationsEnabled': notificationsEnabled,
      'language': language,
    }));
  }

  void _touch() {
    notifyListeners();
    _persistLocalPrefs();
  }

  Future<void> refresh() async {
    await _refreshAll();
    _touch();
  }

  /// Re-fetches every server-owned collection in parallel — called after
  /// login/registration and whenever we need a full resync.
  Future<void> _refreshAll() async {
    final results = await Future.wait([
      _authService.getMe(),
      _partnerService.getDocuments(),
      _partnerService.getApprovalStatus(),
      _partnerService.getVehicle(),
      _partnerService.getBank(),
      OrderStore.instance.refresh().then((_) => null),
      _refreshWallet(),
      _refreshRatings(),
      refreshNotifications(),
      _ticketService.list(),
    ]);

    profile = results[0] as PartnerProfile;
    documents = results[1] as List<DocumentItem>;
    approvalStatus = results[2] as ApprovalStatus;
    vehicle = results[3] as VehicleInfo?;
    final bank = results[4] as BankAccount?;
    bankAccounts = bank != null ? [bank] : [];
    isRegistered = vehicle != null && bankAccounts.isNotEmpty && allDocumentsProvided;
    tickets = results[9] as List<SupportTicket>;
  }

  Future<void> _refreshWallet() async {
    final results = await Future.wait([
      _walletService.getWallet(),
      _walletService.getWithdrawals(),
      _walletService.getTodayIncentives(),
    ]);

    final wallet = results[0] as WalletSnapshot;
    transactions = wallet.transactions;
    codSettlementDue = wallet.codSettlementDue;
    withdrawals = results[1] as List<WithdrawalRequest>;
    todayIncentives = results[2] as TodayIncentives?;
  }

  Future<void> _refreshRatings() async {
    final ratings = await _walletService.getRatings();
    averageRating = ratings.average;
    totalRatings = ratings.total;
    recentRatedTrips = ratings.recent;
  }

  Future<void> refreshNotifications() async {
    notifications = await _notificationService.list();
  }

  /// Used by [ParcelController]/[RideController] after a delivery/ride
  /// completes — a delivered order settles an earning transaction and
  /// creates a notification server-side, so both caches need refreshing.
  Future<void> refreshWalletAndNotifications() async {
    await _refreshWallet();
    await refreshNotifications();
    _touch();
  }

  // ---------------- Auth / onboarding ----------------

  Future<bool> sendOtp(String phone) async {
    lastAuthError = null;
    try {
      await _authService.sendOtp(phone);
      return true;
    } on AppException catch (e) {
      lastAuthError = e.message;
      return false;
    }
  }

  /// Verifies the OTP and starts a session. For a brand-new phone number
  /// this also creates the Partner account (using [draftName]/[draftEmail]
  /// collected on the register screen) and leaves [isRegistered] false so
  /// the caller continues onboarding (vehicle/bank/documents); for a
  /// returning, already-onboarded partner it does a full resync straight
  /// into the dashboard. Driven by the backend's `isNewUser` rather than
  /// [isRegister] so a "Login" tap on a never-registered number still
  /// resolves correctly instead of landing in a broken dashboard state.
  Future<bool> verifyOtp({required String phone, required String otp, required bool isRegister}) async {
    lastAuthError = null;
    try {
      final result = await _authService.verifyOtp(
        phone,
        otp,
        name: isRegister ? draftName : null,
        email: isRegister ? draftEmail : null,
      );
      profile = result.profile;
      approvalStatus = result.approvalStatus;
      isLoggedIn = true;
      if (!result.isNewUser) {
        await _refreshAll();
      }
      await _connectSocket();
      _touch();
      return true;
    } on AppException catch (e) {
      lastAuthError = e.message;
      return false;
    }
  }

  /// Resets onboarding-scoped state so a brand new partner starts from a
  /// clean slate (rather than inheriting whatever the currently logged-in
  /// demo/seed partner has already set up).
  void beginNewRegistration() {
    draftName = '';
    draftEmail = '';
    draftPhone = '';
    vehicle = null;
    bankAccounts = [];
    documents = [
      DocumentItem(key: 'license', label: 'Driving License'),
      DocumentItem(key: 'rc', label: 'Vehicle RC'),
      DocumentItem(key: 'id_proof', label: 'Aadhaar / ID Proof'),
      DocumentItem(key: 'photo', label: 'Profile Photo'),
      DocumentItem(key: 'aadhaar_front', label: 'Aadhaar Card (Front)'),
      DocumentItem(key: 'aadhaar_back', label: 'Aadhaar Card (Back)'),
      DocumentItem(key: 'pan', label: 'PAN Card'),
      DocumentItem(key: 'dl_front', label: 'Driving Licence (Front)'),
      DocumentItem(key: 'dl_back', label: 'Driving Licence (Back)'),
      DocumentItem(key: 'rc_doc', label: 'Registration Certificate'),
      DocumentItem(key: 'insurance', label: 'Insurance Certificate'),
      DocumentItem(key: 'pollution', label: 'Pollution Certificate'),
    ];
    personalDetails = null;
    kyc = null;
    drivingLicence = null;
    backgroundCheckStatus = BackgroundCheckStatus.notRequested;
    termsAcceptedAt = null;
  }

  void startRegistration({required String name, required String email, required String phone}) {
    draftName = name;
    draftEmail = email;
    draftPhone = phone;
  }

  Future<void> setVehicle(VehicleInfo v) async {
    if (!isLoggedIn) {
      vehicle = v; // still onboarding, no session/token yet
      notifyListeners();
      return;
    }
    vehicle = await _partnerService.setVehicle(v);
    _touch();
  }

  Future<void> upsertBankAccount(BankAccount b) async {
    if (!isLoggedIn) {
      bankAccounts = [b];
      notifyListeners();
      return;
    }
    final saved = await _partnerService.setBank(b);
    bankAccounts = [saved];
    _touch();
  }

  Future<void> setDocument(String key, String filePath) async {
    if (!isLoggedIn) {
      final doc = documents.firstWhere((d) => d.key == key);
      doc.filePath = filePath;
      doc.status = DocumentStatus.pending;
      notifyListeners();
      return;
    }
    final updated = await _partnerService.uploadDocument(key, filePath);
    final idx = documents.indexWhere((d) => d.key == key);
    if (idx != -1) documents[idx] = updated;
    _touch();

    // The server auto-verifies ~5s after upload (demo mode) and approves
    // KYC once every document is verified — poll briefly so the UI reflects
    // that without the user pulling to refresh.
    Timer(const Duration(seconds: 6), () async {
      if (isLoggedIn) {
        documents = await _partnerService.getDocuments();
        approvalStatus = await _partnerService.getApprovalStatus();
        await refreshNotifications();
        _touch();
      }
    });
  }

  /// Real upload used by the new onboarding steps (photo/KYC/licence/
  /// vehicle docs): sends actual file bytes to S3 via a presigned URL,
  /// then records the resulting public URL — unlike [setDocument], which
  /// only ever POSTed a bare local device path.
  Future<void> uploadDocumentFile(String key, File file) async {
    final updated = await _partnerService.uploadDocumentFile(key, file);
    final idx = documents.indexWhere((d) => d.key == key);
    if (idx != -1) {
      documents[idx] = updated;
    } else {
      documents.add(updated);
    }
    _touch();

    Timer(const Duration(seconds: 6), () async {
      if (isLoggedIn) {
        documents = await _partnerService.getDocuments();
        approvalStatus = await _partnerService.getApprovalStatus();
        await refreshNotifications();
        _touch();
      }
    });
  }

  DocumentItem? documentFor(String key) {
    for (final d in documents) {
      if (d.key == key) return d;
    }
    return null;
  }

  bool get allDocumentsProvided => documents.every((d) => d.status != DocumentStatus.missing);

  // ---------------- Onboarding Steps 2-10 ----------------

  Future<void> setVehicleType(String type, {String number = ''}) async {
    final v = VehicleInfo(type: type, number: number.isNotEmpty ? number : (vehicle?.number ?? ''));
    await setVehicle(v);
  }

  Future<void> setVehicleDetails({
    required String number,
    required String brand,
    required String model,
    required String fuelType,
    int? year,
  }) async {
    final type = vehicle?.type ?? '';
    final v = VehicleInfo(type: type, number: number, brand: brand, model: model, fuelType: fuelType, year: year);
    if (!isLoggedIn) {
      vehicle = v;
      notifyListeners();
      return;
    }
    vehicle = await _partnerService.setVehicleDetails(v);
    _touch();
  }

  Future<void> setPersonalDetails(PersonalDetails details) async {
    if (!isLoggedIn) {
      personalDetails = details;
      notifyListeners();
      return;
    }
    personalDetails = await _partnerService.setPersonalDetails(details);
    _touch();
  }

  Future<void> setKycDetails(KycDetails details) async {
    if (!isLoggedIn) {
      kyc = details;
      notifyListeners();
      return;
    }
    kyc = await _partnerService.setKyc(details);
    _touch();

    Timer(const Duration(seconds: 6), () async {
      if (isLoggedIn) {
        kyc = await _partnerService.getKyc();
        _touch();
      }
    });
  }

  /// Throws [AppException] if the licence has already expired — the
  /// backend rejects it outright so onboarding can't proceed with an
  /// expired licence (surfaced by the screen as an inline error).
  Future<void> setDrivingLicenceDetails(DrivingLicence licence) async {
    if (!isLoggedIn) {
      drivingLicence = licence;
      notifyListeners();
      return;
    }
    drivingLicence = await _partnerService.setDrivingLicence(licence);
    _touch();

    Timer(const Duration(seconds: 6), () async {
      if (isLoggedIn) {
        drivingLicence = await _partnerService.getDrivingLicence();
        _touch();
      }
    });
  }

  Future<void> triggerBankVerification() async {
    if (!isLoggedIn || bankAccounts.isEmpty) return;
    final updated = await _partnerService.verifyBank();
    bankAccounts = [updated];
    _touch();

    Timer(const Duration(seconds: 6), () async {
      if (isLoggedIn) {
        final bank = await _partnerService.getBank();
        bankAccounts = bank != null ? [bank] : [];
        _touch();
      }
    });
  }

  Future<void> requestBackgroundCheck({required bool consented}) async {
    if (!isLoggedIn) {
      backgroundCheckStatus = consented ? BackgroundCheckStatus.pending : BackgroundCheckStatus.notRequested;
      notifyListeners();
      return;
    }
    backgroundCheckStatus = await _partnerService.requestBackgroundCheck(consented: consented);
    _touch();

    if (consented) {
      Timer(const Duration(seconds: 7), () async {
        if (isLoggedIn) {
          backgroundCheckStatus = await _partnerService.getBackgroundCheck();
          _touch();
        }
      });
    }
  }

  Future<void> acceptTermsAndConditions() async {
    termsAcceptedAt = DateTime.now();
    if (isLoggedIn) {
      await _partnerService.acceptTerms();
    }
    _touch();
  }

  /// Called at the end of the vehicle/bank/documents onboarding steps.
  /// The Partner account and session already exist from OTP verify, and
  /// each step already persisted to the server as it was filled in (see
  /// the `isLoggedIn` branches in [setVehicle]/[upsertBankAccount]/
  /// [setDocument]) — this just does a final confirm-from-server and
  /// flips [isRegistered].
  Future<void> submitRegistration() async {
    documents = await _partnerService.getDocuments();
    approvalStatus = await _partnerService.getApprovalStatus();

    OrderStore.instance.reset();
    transactions = [];
    await refreshNotifications();
    isRegistered = true;
    isLoggedIn = true;
    await _connectSocket();
    _touch();

    Timer(const Duration(seconds: 6), () async {
      if (isLoggedIn) {
        documents = await _partnerService.getDocuments();
        approvalStatus = await _partnerService.getApprovalStatus();
        await refreshNotifications();
        _touch();
      }
    });
  }

  Future<void> logout() async {
    await _authService.logout();
    _forceLogout();
  }

  void _forceLogout() {
    isLoggedIn = false;
    isOnline = false;
    _stopLocationBroadcast();
    OrderStore.instance.disconnect();
    _touch();
  }

  // ---------------- Online/offline + location broadcasting ----------------

  /// Connects the shared Socket.io session (order offers are wired up by
  /// [OrderStore.connect]) and registers this device for push.
  Future<void> _connectSocket() async {
    final token = await SecureStorage.instance.accessToken;
    if (token == null) return;
    OrderStore.instance.connect(token);

    // Best-effort — a real push notification alongside the socket popup,
    // so an offer still reaches this partner while backgrounded.
    unawaited(PushNotifications.init(_partnerService));
  }

  /// Toggles the partner's availability to receive new order requests, just
  /// like the Online/Offline switch on Porter/Rapido partner apps. Going
  /// online also starts periodic location broadcasting (`location:update`).
  Future<void> setOnline(bool value) async {
    try {
      final confirmed = await _partnerService.setOnlineStatus(value);
      isOnline = confirmed;
      if (!confirmed) OrderStore.instance.clearPendingOffers();
      if (confirmed) {
        _startLocationBroadcast();
      } else {
        _stopLocationBroadcast();
      }
      _touch();
    } on AppException catch (e) {
      notifications.insert(0, NotificationItem(title: 'Could not go online', subtitle: e.message, time: DateTime.now()));
      _touch();
    }
  }

  /// Pushes this device's real GPS position (falls back silently and skips
  /// this tick if permission/GPS isn't available — the next tick will just
  /// retry).
  Future<void> _pushRealLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
      if (!await Geolocator.isLocationServiceEnabled()) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      currentLat = position.latitude;
      currentLng = position.longitude;
      await _partnerService.updateLocation(currentLat!, currentLng!);
      notifyListeners();
    } catch (_) {
      // Best-effort — a single failed GPS/network read shouldn't stop future ticks.
    }
  }

  void _startLocationBroadcast() {
    _locationTimer?.cancel();
    _pushRealLocation(); // seed immediately instead of waiting a full 10s
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) => _pushRealLocation());
  }

  void _stopLocationBroadcast() {
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  double get walletBalance => transactions.fold(0.0, (s, t) => s + t.amount);

  double _sumEarnings(bool Function(DateTime) predicate) =>
      transactions.where((t) => t.type == TransactionType.earning && predicate(t.date)).fold(0.0, (s, t) => s + t.amount);

  bool _isThisWeek(DateTime d) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    return d.isAfter(start.subtract(const Duration(seconds: 1)));
  }

  bool _isThisMonth(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month;
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  double get todayEarnings => _sumEarnings(_isToday);
  double get weekEarnings => _sumEarnings(_isThisWeek);
  double get monthEarnings => _sumEarnings(_isThisMonth);

  Future<void> withdraw(double amount) async {
    try {
      await _walletService.requestWithdrawal(amount);
      await _refreshWallet();
      await refreshNotifications();
      _touch();

      // The server auto-approves ~8s after request (demo mode) — refresh
      // once so the UI updates without a manual pull.
      Timer(const Duration(seconds: 8), () async {
        if (isLoggedIn) {
          await _refreshWallet();
          await refreshNotifications();
          _touch();
        }
      });
    } on AppException catch (e) {
      notifications.insert(0, NotificationItem(title: 'Withdrawal Failed', subtitle: e.message, time: DateTime.now()));
      _touch();
    }
  }

  // ---------------- Profile / settings ----------------

  Future<void> updateProfile({required String name, required String email}) async {
    profile = await _authService.updateProfile(name: name, email: email);
    _touch();
  }

  void setDarkMode(bool value) {
    darkMode = value;
    _touch();
  }

  void setNotificationsEnabled(bool value) {
    notificationsEnabled = value;
    _touch();
  }

  void setLanguage(String value) {
    language = value;
    _touch();
  }

  void markAllNotificationsRead() {
    for (final n in notifications) {
      n.read = true;
    }
    _touch();
  }

  void markNotificationRead(NotificationItem item) {
    item.read = true;
    _touch();
  }

  Future<void> raiseTicket(String subject, String description) async {
    final ticket = await _ticketService.raise(subject, description);
    tickets.insert(0, ticket);
    _touch();
  }
}
