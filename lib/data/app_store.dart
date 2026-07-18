import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/app_exception.dart';
import '../core/push_notifications.dart';
import '../core/secure_storage.dart';
import '../core/socket_client.dart';
import '../services/auth_service.dart';
import '../services/booking_service.dart';
import '../services/notification_service.dart';
import '../services/partner_service.dart';
import '../services/ticket_service.dart';
import '../services/wallet_service.dart';
import 'models.dart';

String formatTime(DateTime d) => DateFormat('hh:mm a').format(d);
String formatDate(DateTime d) => DateFormat('d MMM, yyyy').format(d);
String formatDateTime(DateTime d) => '${formatTime(d)} · ${formatDate(d)}';
String formatAmount(double v) =>
    '${v < 0 ? '-' : ''}₹${v.abs().toStringAsFixed(v.abs() % 1 == 0 ? 0 : 2)}';

/// App-wide state for the partner app. Every read/write delegates to service
/// classes that go through a real Dio client (auth headers, silent token
/// refresh, error mapping) against shipryd-backend. Screens keep using
/// `AppStore.instance` exactly as before: the fields below are now a *cache*
/// of the last server response, refreshed after every mutation.
class AppStore extends ChangeNotifier {
  AppStore._();
  static final AppStore instance = AppStore._();

  static const _prefsKey = 'partner_app_prefs_v2';

  late final Dio _dio;
  late final AuthService _authService;
  late final PartnerService _partnerService;
  late final BookingService _bookingService;
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
  List<Parcel> parcels = [];
  List<Transaction> transactions = [];
  List<NotificationItem> notifications = [];
  List<SupportTicket> tickets = [];
  List<WithdrawalRequest> withdrawals = [];
  TodayIncentives? todayIncentives;
  double codSettlementDue = 0;
  double averageRating = 5.0;
  int totalRatings = 0;
  List<Parcel> recentRatedParcels = [];

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

  // ---- live order requests (Porter-style accept/reject), fed by the real
  // Socket.io `order:request` / `order:request:expired` events. ----
  bool isOnline = false;
  Parcel? activeRequest;

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
    _bookingService = BookingService(_dio);
    _walletService = WalletService(_dio);
    _ticketService = TicketService(_dio);
    _notificationService = NotificationService(_dio);

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

  /// Re-fetches every server-owned collection in one go — called after
  /// login/registration and whenever we need a full resync.
  Future<void> _refreshAll() async {
    profile = await _authService.getMe();
    documents = await _partnerService.getDocuments();
    approvalStatus = await _partnerService.getApprovalStatus();
    vehicle = await _partnerService.getVehicle();
    final bank = await _partnerService.getBank();
    bankAccounts = bank != null ? [bank] : [];
    isRegistered = vehicle != null && bankAccounts.isNotEmpty && allDocumentsProvided;

    await _refreshBookings();
    await _refreshWallet();
    await _refreshRatings();
    await _refreshNotifications();
    tickets = await _ticketService.list();
  }

  Future<void> _refreshBookings() async {
    parcels = await _bookingService.getBookings();
  }

  Future<void> _refreshWallet() async {
    final wallet = await _walletService.getWallet();
    transactions = wallet.transactions;
    codSettlementDue = wallet.codSettlementDue;
    withdrawals = await _walletService.getWithdrawals();
    todayIncentives = await _walletService.getTodayIncentives();
  }

  Future<void> _refreshRatings() async {
    final ratings = await _walletService.getRatings();
    averageRating = ratings.average;
    totalRatings = ratings.total;
    recentRatedParcels = ratings.recent;
  }

  Future<void> _refreshNotifications() async {
    notifications = await _notificationService.list();
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
        await _refreshNotifications();
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
        await _refreshNotifications();
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

    parcels = [];
    transactions = [];
    await _refreshNotifications();
    isRegistered = true;
    isLoggedIn = true;
    await _connectSocket();
    _touch();

    Timer(const Duration(seconds: 6), () async {
      if (isLoggedIn) {
        documents = await _partnerService.getDocuments();
        approvalStatus = await _partnerService.getApprovalStatus();
        await _refreshNotifications();
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
    activeRequest = null;
    _stopLocationBroadcast();
    SocketClient.instance.disconnect();
    _touch();
  }

  // ---------------- Live order requests (Porter-style) ----------------

  /// Connects the shared Socket.io session and wires the two events that
  /// drive the incoming-order overlay — `order:request` (a new offer this
  /// partner was matched to) and `order:request:expired` (someone else took
  /// it, or the 18s offer window ran out).
  Future<void> _connectSocket() async {
    final token = await SecureStorage.instance.accessToken;
    if (token == null) return;
    SocketClient.instance.connect(token);
    final socket = SocketClient.instance.socket;

    // Best-effort — a real push notification alongside the socket popup
    // below, so an offer still reaches this partner while backgrounded.
    unawaited(PushNotifications.init(_partnerService));

    socket?.on('order:request', (data) {
      final parcel = Parcel.fromJson(Map<String, dynamic>.from(data as Map));
      parcels.insert(0, parcel);
      activeRequest ??= parcel;
      _touch();
    });

    socket?.on('order:request:expired', (data) {
      final bookingId = (data as Map)['bookingId'] as String?;
      if (activeRequest?.id == bookingId) activeRequest = null;
      parcels.removeWhere((p) => p.id == bookingId && p.status == ParcelStatus.requested);
      _touch();
    });
  }

  /// Toggles the partner's availability to receive new order requests, just
  /// like the Online/Offline switch on Porter/Rapido partner apps. Going
  /// online also starts periodic location broadcasting (`location:update`).
  Future<void> setOnline(bool value) async {
    try {
      final confirmed = await _partnerService.setOnlineStatus(value);
      isOnline = confirmed;
      if (!confirmed) activeRequest = null;
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

  void triggerTestOrderRequest() {
    activeRequest = Parcel(
      id: 'test_parcel_999',
      orderId: 'ORD-999-XYZ',
      fromName: 'Apna Bazar Pickups',
      fromAddress: '12, M.G. Road, Near Central Mall, Bengaluru',
      toAddress: 'Flat 402, Sunshine Heights, Koramangala, Bengaluru',
      itemType: 'Documents & Keys',
      weightKg: 1.5,
      paymentMode: 'Online',
      codAmount: 0.0,
      earning: 102.0,
      distanceKm: 5.4,
      etaMinutes: 18,
      status: ParcelStatus.requested,
      viewed: false,
    );
    _touch();
  }

  /// Partner accepted the incoming request (`POST /bookings/:id/accept`) —
  /// it now enters the normal pickup/deliver flow.
  Future<void> acceptOrderRequest(String parcelId) async {
    if (parcelId.startsWith('test_')) {
      if (activeRequest?.id == parcelId) {
        final mockParcel = activeRequest!;
        mockParcel.status = ParcelStatus.pending;
        parcels.insert(0, mockParcel);
        activeRequest = null;
      }
      _touch();
      return;
    }
    await _bookingService.accept(parcelId);
    await _refreshBookings();
    await _refreshNotifications();
    if (activeRequest?.id == parcelId) activeRequest = null;
    _touch();
  }

  /// Partner declined (or the countdown ran out) — the request disappears
  /// from this partner's queue; the server immediately re-offers it to the
  /// next nearby partner.
  Future<void> declineOrderRequest(String parcelId, {bool timedOut = false}) async {
    if (parcelId.startsWith('test_')) {
      parcels.removeWhere((e) => e.id == parcelId);
      if (activeRequest?.id == parcelId) activeRequest = null;
      _touch();
      return;
    }
    await _bookingService.cancel(parcelId);
    parcels.removeWhere((e) => e.id == parcelId);
    if (activeRequest?.id == parcelId) activeRequest = null;
    _touch();
  }

  // ---------------- Parcels / booking lifecycle ----------------

  Parcel? findParcelById(String id) {
    for (final p in parcels) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Looks up a pending parcel matching [code] (as scanned from a QR/barcode).
  /// If none exists yet, a fresh one is created — the scan itself is treated
  /// as the `arrived_pickup` + `picked_up` lifecycle actions in one step.
  Future<Parcel> scanOrCreateParcel(String code) async {
    final parcel = await _bookingService.scanOrCreate(code);
    await _refreshBookings();
    await _refreshNotifications();
    _touch();
    return parcel;
  }

  /// Fired when the partner taps "Confirm Receive" at pickup — the
  /// `picked_up` lifecycle action (parcel is now physically with the
  /// partner, in transit to the drop address).
  Future<void> markPickedUp(String parcelId, {String? otp, String? proofPath}) async {
    if (parcelId.startsWith('test_')) {
      final p = findParcelById(parcelId);
      if (p != null) {
        p.status = ParcelStatus.pickedUp;
        p.proofPhotoPath = proofPath;
      }
      _touch();
      return;
    }
    await _bookingService.updateStatus(parcelId, 'picked_up', otp: otp, proofPath: proofPath);
    await _refreshBookings();
    _touch();
  }

  Future<void> markViewed(String parcelId) async {
    final p = findParcelById(parcelId);
    if (p == null || p.viewed) return;
    p.viewed = true;
    _touch();
  }

  Future<void> completeParcel(String parcelId, {String? proofPath}) async {
    if (parcelId.startsWith('test_')) {
      final p = findParcelById(parcelId);
      if (p != null) {
        p.status = ParcelStatus.received;
        p.receivedAt = DateTime.now();
        p.proofPhotoPath = proofPath;
      }
      _touch();
      return;
    }
    await _bookingService.updateStatus(parcelId, 'delivered', proofPath: proofPath);
    await _refreshBookings();
    await _refreshWallet();
    await _refreshNotifications();
    _touch();
  }

  Future<void> cancelParcel(String parcelId) async {
    if (parcelId.startsWith('test_')) {
      final p = findParcelById(parcelId);
      if (p != null) p.status = ParcelStatus.canceled;
      _touch();
      return;
    }
    await _bookingService.cancel(parcelId);
    await _refreshBookings();
    _touch();
  }

  List<Parcel> get pendingNewParcels => parcels.where((p) => p.status == ParcelStatus.pending && !p.viewed).toList();
  List<Parcel> get pendingInProgressParcels =>
      parcels.where((p) => (p.status == ParcelStatus.pending && p.viewed) || p.status == ParcelStatus.pickedUp).toList();
  List<Parcel> get allPendingParcels =>
      parcels.where((p) => p.status == ParcelStatus.pending || p.status == ParcelStatus.pickedUp).toList();
  List<Parcel> get receivedParcels => parcels.where((p) => p.status == ParcelStatus.received).toList();
  List<Parcel> get canceledParcels => parcels.where((p) => p.status == ParcelStatus.canceled).toList();
  List<Parcel> get historyParcels => parcels
      .where((p) => p.status == ParcelStatus.received || p.status == ParcelStatus.canceled)
      .toList()
    ..sort((a, b) => (b.receivedAt ?? b.createdAt).compareTo(a.receivedAt ?? a.createdAt));

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  int get todayReceivedCount => receivedParcels.where((p) => _isToday(p.receivedAt!)).length;

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

  double get todayEarnings => _sumEarnings(_isToday);
  double get weekEarnings => _sumEarnings(_isThisWeek);
  double get monthEarnings => _sumEarnings(_isThisMonth);

  double get walletBalance => transactions.fold(0.0, (s, t) => s + t.amount);

  Future<void> withdraw(double amount) async {
    try {
      await _walletService.requestWithdrawal(amount);
      await _refreshWallet();
      await _refreshNotifications();
      _touch();

      // The server auto-approves ~8s after request (demo mode) — refresh
      // once so the UI updates without a manual pull.
      Timer(const Duration(seconds: 8), () async {
        if (isLoggedIn) {
          await _refreshWallet();
          await _refreshNotifications();
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

  Future<void> raiseTicket(String subject, String description) async {
    final ticket = await _ticketService.raise(subject, description);
    tickets.insert(0, ticket);
    _touch();
  }
}
