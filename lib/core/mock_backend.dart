import 'dart:math';

import '../data/models.dart';

/// Thrown by [MockBackend] handlers; the Dio mock interceptor catches this
/// and turns it into a real [DioException] with a response, so the rest of
/// the app (interceptors, services, error mapping) behaves exactly as it
/// would against a real HTTP API.
class MockApiError implements Exception {
  final int statusCode;
  final String message;
  const MockApiError(this.statusCode, this.message);
}

class _AccessSession {
  final DateTime issuedAt;
  _AccessSession(this.issuedAt);
}

/// Stands in for ShipRyd's real backend while the partner app is built out
/// against a defined REST contract (see `2.x` spec: registration, KYC
/// approval, live dispatch, earnings, wallet/withdrawals, ratings, tickets).
/// Every documented endpoint is implemented here as an in-memory
/// "database" + handler; swapping to a real backend later means deleting
/// the mock interceptor and pointing `ApiClient`'s base URL at the real
/// host — no service or screen changes.
class MockBackend {
  MockBackend._();
  static final MockBackend instance = MockBackend._();

  final _rnd = Random();

  // ---- sessions ----
  static const accessTokenTtl = Duration(seconds: 60);
  final Map<String, _AccessSession> _accessSessions = {};
  final Map<String, bool> _refreshSessions = {}; // refreshToken -> valid

  // ---- partner data (single demo partner) ----
  bool _registered = false;
  late PartnerProfile profile;
  VehicleInfo? vehicle;
  List<BankAccount> bankAccounts = [];
  List<DocumentItem> documents = [];
  ApprovalStatus approvalStatus = ApprovalStatus.pending;
  bool isOnline = false;
  double? currentLat;
  double? currentLng;

  List<Parcel> parcels = [];
  List<Transaction> transactions = [];
  List<NotificationItem> notifications = [];
  List<SupportTicket> tickets = [];
  List<WithdrawalRequest> withdrawals = [];
  final Set<String> _expiryNotified = {};

  static const _mockAreas = [
    'Connaught Place, Delhi',
    'Sector 15, Noida',
    'Sector 62, Noida',
    'Cyber City, Gurugram',
    'Andheri East, Mumbai',
    'Koramangala, Bengaluru',
  ];
  static const _mockItems = ['Electronics', 'Documents', 'Apparel', 'Groceries', 'Books'];
  static const _mockCouriers = ['Rahul Courier', 'Speedex Logistics', 'QuickShip Hub', 'City Express'];

  String _genId(String prefix) => '$prefix${DateTime.now().millisecondsSinceEpoch}${_rnd.nextInt(900) + 100}';

  // ================= Auth / Registration =================

  Map<String, dynamic> register(Map<String, dynamic> body) {
    profile = PartnerProfile(
      name: body['name'] as String,
      email: body['email'] as String,
      phone: body['phone'] as String,
      rating: 5.0,
      totalDeliveries: 0,
    );
    vehicle = null;
    bankAccounts = [];
    documents = [
      DocumentItem(key: 'license', label: 'Driving License', expiryDate: DateTime.now().add(const Duration(days: 10))),
      DocumentItem(key: 'rc', label: 'Vehicle RC'),
      DocumentItem(key: 'id_proof', label: 'Aadhaar / ID Proof'),
      DocumentItem(key: 'photo', label: 'Profile Photo'),
    ];
    approvalStatus = ApprovalStatus.pending;
    parcels = [];
    transactions = [];
    withdrawals = [];
    notifications = [
      NotificationItem(title: 'Welcome to ShipRyd Partner', subtitle: 'Complete your KYC to start receiving orders', time: DateTime.now()),
    ];
    _registered = true;
    return {..._issueTokens(), 'approvalStatus': approvalStatus.name};
  }

  /// A real backend would be `POST /partners/login` (phone + OTP) for a
  /// *returning* partner — distinct from [register], which onboards a
  /// brand-new one. Keeps all existing history intact (unlike re-registering).
  Map<String, dynamic> login(String phone) {
    if (!_registered) {
      throw const MockApiError(404, 'No partner account found for this number — please register first');
    }
    if (phone.isNotEmpty) profile.phone = phone;
    return {..._issueTokens(), 'approvalStatus': approvalStatus.name};
  }

  Map<String, dynamic> refresh(String refreshToken) {
    if (_refreshSessions[refreshToken] != true) {
      throw const MockApiError(401, 'Session expired. Please log in again.');
    }
    return _issueTokens();
  }

  void logout(String accessToken) {
    _accessSessions.remove(accessToken);
  }

  Map<String, dynamic> _issueTokens() {
    final access = 'at_${_genId('')}';
    final refresh = 'rt_${_genId('')}';
    _accessSessions[access] = _AccessSession(DateTime.now());
    _refreshSessions[refresh] = true;
    return {'accessToken': access, 'refreshToken': refresh};
  }

  void _validate(String accessToken) {
    final session = _accessSessions[accessToken];
    if (session == null) throw const MockApiError(401, 'Unauthorized');
    if (DateTime.now().difference(session.issuedAt) > accessTokenTtl) {
      throw const MockApiError(401, 'Access token expired');
    }
    if (!_registered) throw const MockApiError(404, 'Partner not registered');
  }

  // ================= Profile =================

  Map<String, dynamic> getMe(String accessToken) {
    _validate(accessToken);
    return {...profile.toJson(), 'approvalStatus': approvalStatus.name, 'isOnline': isOnline};
  }

  Map<String, dynamic> updateMe(String accessToken, {String? name, String? email}) {
    _validate(accessToken);
    if (name != null) profile.name = name;
    if (email != null) profile.email = email;
    return profile.toJson();
  }

  Map<String, dynamic> setVehicle(String accessToken, Map<String, dynamic> body) {
    _validate(accessToken);
    vehicle = VehicleInfo(type: body['type'] as String, number: body['number'] as String);
    return vehicle!.toJson();
  }

  Map<String, dynamic> setBank(String accessToken, Map<String, dynamic> body) {
    _validate(accessToken);
    final bank = BankAccount(
      bankName: body['bankName'] as String,
      accountNumber: body['accountNumber'] as String,
      ifsc: body['ifsc'] as String,
      holderName: body['holderName'] as String,
    );
    bankAccounts
      ..clear()
      ..add(bank);
    return bank.toJson();
  }

  // ================= Documents / KYC approval =================

  Map<String, dynamic> uploadDocument(String accessToken, String key, String filePath) {
    _validate(accessToken);
    final doc = documents.firstWhere((d) => d.key == key, orElse: () => throw const MockApiError(404, 'Unknown document'));
    doc.filePath = filePath;
    doc.status = DocumentStatus.pending;

    // Simulates admin review: auto-verifies shortly after upload, and once
    // every document is verified the partner's KYC is approved — mirrors
    // "admin approval status poll/socket" without a real reviewer.
    Future.delayed(const Duration(seconds: 5), () {
      doc.status = DocumentStatus.verified;
      notifications.insert(0, NotificationItem(title: 'Document Verified', subtitle: '${doc.label} has been verified', time: DateTime.now()));
      if (documents.every((d) => d.status == DocumentStatus.verified) && approvalStatus != ApprovalStatus.approved) {
        approvalStatus = ApprovalStatus.approved;
        notifications.insert(0, NotificationItem(title: 'KYC Approved 🎉', subtitle: "You're all set to start receiving orders", time: DateTime.now(), showChevron: true));
      }
    });

    return doc.toJson();
  }

  List<Map<String, dynamic>> getDocuments(String accessToken) {
    _validate(accessToken);
    return documents.map((d) => d.toJson()).toList();
  }

  Map<String, dynamic> getApprovalStatus(String accessToken) {
    _validate(accessToken);
    return {'approvalStatus': approvalStatus.name};
  }

  /// Mirrors a BullMQ repeatable cron checking document expiry and pushing
  /// FCM alerts 15 days out — run locally (called from AppStore on launch
  /// and periodically) since there's no real scheduler here. This isn't a
  /// client-invoked endpoint, so unlike everything else in this file it
  /// isn't gated behind a bearer token.
  List<NotificationItem> checkDocumentExpiry() {
    if (!_registered) return const [];
    final fresh = <NotificationItem>[];
    for (final doc in documents) {
      if (doc.expiryDate == null) continue;
      final daysLeft = doc.expiryDate!.difference(DateTime.now()).inDays;
      if (daysLeft <= 15 && daysLeft >= 0 && !_expiryNotified.contains(doc.key)) {
        _expiryNotified.add(doc.key);
        final n = NotificationItem(
          title: '${doc.label} Expiring Soon',
          subtitle: 'Expires in $daysLeft day${daysLeft == 1 ? '' : 's'} — please renew',
          time: DateTime.now(),
          showChevron: true,
        );
        notifications.insert(0, n);
        fresh.add(n);
      }
    }
    return fresh;
  }

  // ================= Online status / location =================

  Map<String, dynamic> setOnlineStatus(String accessToken, bool online) {
    _validate(accessToken);
    if (online && approvalStatus != ApprovalStatus.approved) {
      throw const MockApiError(403, 'Your KYC is still under review — you can go online once approved');
    }
    isOnline = online;
    return {'isOnline': isOnline};
  }

  Map<String, dynamic> updateLocation(String accessToken, double lat, double lng) {
    _validate(accessToken);
    currentLat = lat;
    currentLng = lng;
    return {'ok': true};
  }

  // ================= Bookings (parcels) =================

  Parcel? findParcelById(String id) {
    for (final p in parcels) {
      if (p.id == id) return p;
    }
    return null;
  }

  Parcel spawnOrderRequest() {
    final distance = ((_rnd.nextInt(80) + 15) / 10);
    final parcel = Parcel(
      id: 'PRC${DateTime.now().millisecondsSinceEpoch}${_rnd.nextInt(900) + 100}',
      orderId: 'ORD${_rnd.nextInt(900000) + 100000}',
      fromName: _mockCouriers[_rnd.nextInt(_mockCouriers.length)],
      fromAddress: _mockAreas[_rnd.nextInt(_mockAreas.length)],
      toAddress: _mockAreas[_rnd.nextInt(_mockAreas.length)],
      itemType: _mockItems[_rnd.nextInt(_mockItems.length)],
      weightKg: (_rnd.nextInt(45) + 5) / 10,
      paymentMode: _rnd.nextBool() ? 'Prepaid' : 'COD',
      codAmount: (_rnd.nextInt(40) + 5) * 10,
      earning: (_rnd.nextInt(6) + 3) * 10,
      distanceKm: distance,
      etaMinutes: (distance * 3.2).round() + 2,
      status: ParcelStatus.requested,
    );
    parcels.insert(0, parcel);
    return parcel;
  }

  List<Map<String, dynamic>> getBookings(String accessToken, {String? status}) {
    _validate(accessToken);
    var results = parcels.toList();
    if (status != null && status.isNotEmpty) {
      results = results.where((p) => p.status.name == status).toList();
    }
    return results.map((p) => p.toJson()).toList();
  }

  Map<String, dynamic> acceptBooking(String accessToken, String id) {
    _validate(accessToken);
    final p = findParcelById(id) ?? (throw const MockApiError(404, 'Booking not found'));
    p.status = ParcelStatus.pending;
    p.viewed = false;
    notifications.insert(0, NotificationItem(title: 'Order Accepted', subtitle: '${p.id} · head to ${p.fromAddress}', time: DateTime.now(), showChevron: true));
    return p.toJson();
  }

  Map<String, dynamic> cancelBooking(String accessToken, String id) {
    _validate(accessToken);
    final p = findParcelById(id) ?? (throw const MockApiError(404, 'Booking not found'));
    p.status = ParcelStatus.canceled;
    return p.toJson();
  }

  /// Resolving a scanned QR/barcode is the `arrived_pickup` signal — it just
  /// surfaces the parcel (creating one if this code is unseen); the
  /// `picked_up` transition happens explicitly when the partner taps
  /// "Confirm Receive", not at scan time.
  Map<String, dynamic> scanOrCreateBooking(String accessToken, String code) {
    _validate(accessToken);
    var p = findParcelById(code);
    if (p == null) {
      p = Parcel(
        id: code,
        orderId: 'ORD${_rnd.nextInt(900000) + 100000}',
        fromName: _mockCouriers[_rnd.nextInt(_mockCouriers.length)],
        fromAddress: _mockAreas[_rnd.nextInt(_mockAreas.length)],
        toAddress: _mockAreas[_rnd.nextInt(_mockAreas.length)],
        itemType: _mockItems[_rnd.nextInt(_mockItems.length)],
        weightKg: (_rnd.nextInt(45) + 5) / 10,
        paymentMode: _rnd.nextBool() ? 'Prepaid' : 'COD',
        codAmount: (_rnd.nextInt(40) + 5) * 10,
        earning: (_rnd.nextInt(6) + 3) * 10,
      );
      parcels.insert(0, p);
      notifications.insert(0, NotificationItem(title: 'New Parcel Assigned', subtitle: p.id, time: DateTime.now(), showChevron: true));
    }
    return p.toJson();
  }

  /// Order lifecycle actions: `arrived_pickup` / `arrived_drop` are
  /// transient (acknowledged, don't change the coarse [ParcelStatus]);
  /// `picked_up` and `delivered` are the two persisted milestones.
  Map<String, dynamic> updateBookingStatus(String accessToken, String id, String status, {String? proofPath}) {
    _validate(accessToken);
    final p = findParcelById(id) ?? (throw const MockApiError(404, 'Booking not found'));

    switch (status) {
      case 'arrived_pickup':
      case 'arrived_drop':
        break;
      case 'picked_up':
        p.status = ParcelStatus.pickedUp;
        break;
      case 'delivered':
        p.status = ParcelStatus.received;
        p.receivedAt = DateTime.now();
        p.proofPhotoPath = proofPath;
        profile.totalDeliveries += 1;

        transactions.insert(0, Transaction(id: _genId('TXN'), type: TransactionType.earning, title: 'Parcel Received', subtitle: p.id, amount: p.earning, date: p.receivedAt!));
        if (p.paymentMode == 'COD' && p.codSettlementDue > 0) {
          transactions.insert(
            0,
            Transaction(
              id: _genId('TXN'),
              type: TransactionType.codSettlement,
              title: 'COD Collected',
              subtitle: '${p.id} · to settle with company',
              amount: -p.codSettlementDue,
              date: p.receivedAt!,
            ),
          );
        }
        notifications.insert(0, NotificationItem(title: 'Parcel Delivered', subtitle: p.id, time: p.receivedAt!, trailingAmount: '+${p.earning.toStringAsFixed(0)}'));
        break;
      default:
        throw MockApiError(400, 'Unknown status: $status');
    }
    return p.toJson();
  }

  // ================= Earnings =================

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

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

  Map<String, dynamic> getEarnings(String accessToken, {required String period}) {
    _validate(accessToken);
    bool Function(DateTime) predicate;
    switch (period) {
      case 'week':
        predicate = _isThisWeek;
        break;
      case 'month':
        predicate = _isThisMonth;
        break;
      default:
        predicate = _isToday;
    }
    final earningTxns = transactions.where((t) => t.type == TransactionType.earning && predicate(t.date)).toList();
    final total = earningTxns.fold(0.0, (s, t) => s + t.amount);
    final trips = parcels.where((p) => p.status == ParcelStatus.received && p.receivedAt != null && predicate(p.receivedAt!)).toList();
    return {
      'period': period,
      'totalEarning': total,
      'tripCount': trips.length,
      'incentives': 0.0,
      'breakdown': trips
          .map((p) => {'parcelId': p.id, 'earning': p.earning, 'date': p.receivedAt!.toIso8601String(), 'itemType': p.itemType})
          .toList(),
    };
  }

  // ================= Wallet / Withdrawals =================

  double get _walletBalance => transactions.fold(0.0, (s, t) => s + t.amount);
  double get _codSettlementDue => parcels
      .where((p) => p.status == ParcelStatus.received && p.paymentMode == 'COD')
      .fold(0.0, (s, p) => s + p.codSettlementDue) -
      transactions.where((t) => t.type == TransactionType.codSettlement && t.title == 'COD Settled').fold(0.0, (s, t) => s + t.amount.abs());

  Map<String, dynamic> getWallet(String accessToken) {
    _validate(accessToken);
    return {'balance': _walletBalance, 'codSettlementDue': _codSettlementDue, 'transactions': transactions.map((t) => t.toJson()).toList()};
  }

  Map<String, dynamic> requestWithdrawal(String accessToken, double amount) {
    _validate(accessToken);
    if (amount > _walletBalance) throw const MockApiError(400, 'Withdrawal amount exceeds wallet balance');
    final req = WithdrawalRequest(id: _genId('WD'), amount: amount);
    withdrawals.insert(0, req);
    transactions.insert(0, Transaction(id: _genId('TXN'), type: TransactionType.withdrawal, title: 'Withdrawal to Bank', subtitle: 'Pending approval', amount: -amount, date: DateTime.now()));
    notifications.insert(0, NotificationItem(title: 'Withdrawal Requested', subtitle: '${amount.toStringAsFixed(0)} · pending admin approval', time: DateTime.now()));

    // Simulates admin approval + manual/PayU payout after review.
    Future.delayed(const Duration(seconds: 8), () {
      req.status = WithdrawalStatus.approved;
      req.processedAt = DateTime.now();
      notifications.insert(0, NotificationItem(title: 'Withdrawal Approved', subtitle: '${amount.toStringAsFixed(0)} will reach your bank in 24-48 hrs', time: DateTime.now()));
    });

    return req.toJson();
  }

  List<Map<String, dynamic>> getWithdrawals(String accessToken) {
    _validate(accessToken);
    return withdrawals.map((w) => w.toJson()).toList();
  }

  // ================= Ratings =================

  Map<String, dynamic> getRatings(String accessToken) {
    _validate(accessToken);
    final rated = parcels.where((p) => p.rating != null).toList()
      ..sort((a, b) => (b.receivedAt ?? b.createdAt).compareTo(a.receivedAt ?? a.createdAt));
    return {
      'averageRating': profile.rating,
      'totalRatings': rated.length,
      'recent': rated
          .map((p) => {'parcelId': p.id, 'rating': p.rating, 'comment': p.ratingComment, 'date': (p.receivedAt ?? p.createdAt).toIso8601String()})
          .toList(),
    };
  }

  // ================= Support =================

  Map<String, dynamic> raiseTicket(String accessToken, String subject, String description) {
    _validate(accessToken);
    final ticket = SupportTicket(id: _genId('TCK'), subject: subject, description: description, createdAt: DateTime.now());
    tickets.insert(0, ticket);
    return ticket.toJson();
  }

  // ================= Seed (first-run demo data) =================

  void seedDemoData() {
    profile = PartnerProfile(name: 'Rahul Sharma', email: 'rahul.sharma@example.com', phone: '+91 98765 43210', rating: 4.8, totalDeliveries: 120);
    vehicle = VehicleInfo(type: 'Bike', number: 'DL 08 AB 1234');
    bankAccounts = [BankAccount(bankName: 'HDFC Bank', accountNumber: '50100123454567', ifsc: 'HDFC0001234', holderName: 'Rahul Sharma')];
    documents = [
      DocumentItem(key: 'license', label: 'Driving License', status: DocumentStatus.verified, expiryDate: DateTime.now().add(const Duration(days: 10))),
      DocumentItem(key: 'rc', label: 'Vehicle RC', status: DocumentStatus.verified, expiryDate: DateTime.now().add(const Duration(days: 200))),
      DocumentItem(key: 'id_proof', label: 'Aadhaar / ID Proof', status: DocumentStatus.verified),
      DocumentItem(key: 'photo', label: 'Profile Photo', status: DocumentStatus.verified),
    ];
    approvalStatus = ApprovalStatus.approved;

    final now = DateTime.now();
    Parcel received(String id, String from, String to, String item, double earn, DateTime when, {int? rating, String? comment, String paymentMode = 'Prepaid', double codAmount = 0}) {
      return Parcel(
        id: id,
        orderId: 'ORD${id.substring(3)}',
        fromName: 'Rahul Courier',
        fromAddress: from,
        toAddress: to,
        itemType: item,
        weightKg: 2.5,
        paymentMode: paymentMode,
        codAmount: codAmount,
        earning: earn,
        status: ParcelStatus.received,
        viewed: true,
        createdAt: when.subtract(const Duration(minutes: 20)),
        receivedAt: when,
        rating: rating,
        ratingComment: comment,
      );
    }

    parcels = [
      Parcel(
        id: 'PRC1234567890',
        orderId: 'ORD987654',
        fromName: 'Rahul Courier',
        fromAddress: 'Connaught Place, Delhi',
        toAddress: 'Sector 15, Noida',
        itemType: 'Electronics',
        weightKg: 2.5,
        paymentMode: 'Prepaid',
        codAmount: 320,
        earning: 45,
        createdAt: now.subtract(const Duration(minutes: 30)),
      ),
      Parcel(
        id: 'PRC9876546210',
        orderId: 'ORD654321',
        fromName: 'Speedex Logistics',
        fromAddress: 'Sector 15, Noida',
        toAddress: 'Sector 62, Noida',
        itemType: 'Apparel',
        weightKg: 1.2,
        paymentMode: 'COD',
        codAmount: 899,
        earning: 40,
        createdAt: now.subtract(const Duration(minutes: 5)),
      ),
      Parcel(
        id: 'PRC5647382910',
        orderId: 'ORD135790',
        fromName: 'QuickShip Hub',
        fromAddress: 'Sector 16, Noida',
        toAddress: 'Cyber City, Gurugram',
        itemType: 'Documents',
        weightKg: 0.5,
        paymentMode: 'Prepaid',
        codAmount: 0,
        earning: 35,
        viewed: true,
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
      received('PRC1123334455', 'Noida Sector 62', 'Connaught Place, Delhi', 'Groceries', 50, now.subtract(const Duration(days: 1, hours: 2)), rating: 5, comment: 'Very polite and quick!'),
      received('PRC1123334001', 'Sector 18, Noida', 'Cyber City, Gurugram', 'Apparel', 60, now.subtract(const Duration(days: 2)), rating: 4, comment: 'Good service', paymentMode: 'COD', codAmount: 750),
      received('PRC1123333998', 'Koramangala, Bengaluru', 'Andheri East, Mumbai', 'Electronics', 90, now.subtract(const Duration(days: 4)), rating: 5),
    ];

    transactions = [
      Transaction(id: _genId('TXN'), type: TransactionType.credit, title: 'Welcome Bonus', subtitle: 'Signup bonus credited', amount: 1000, date: now.subtract(const Duration(days: 3))),
      Transaction(id: _genId('TXN'), type: TransactionType.earning, title: 'Parcel Received', subtitle: 'PRC1123334455', amount: 50, date: now.subtract(const Duration(days: 1, hours: 2))),
      Transaction(id: _genId('TXN'), type: TransactionType.earning, title: 'Parcel Received', subtitle: 'PRC1123334001', amount: 60, date: now.subtract(const Duration(days: 2))),
      Transaction(id: _genId('TXN'), type: TransactionType.codSettlement, title: 'COD Collected', subtitle: 'PRC1123334001 · to settle with company', amount: -690, date: now.subtract(const Duration(days: 2))),
      Transaction(id: _genId('TXN'), type: TransactionType.earning, title: 'Parcel Received', subtitle: 'PRC1123333998', amount: 90, date: now.subtract(const Duration(days: 4))),
    ];

    notifications = [
      NotificationItem(title: 'New Parcel Assigned', subtitle: 'PRC9876546210', time: now.subtract(const Duration(minutes: 5)), showChevron: true),
      NotificationItem(title: 'Payment Credited', subtitle: '₹1000 added to wallet', time: now.subtract(const Duration(days: 3)), showChevron: true),
      NotificationItem(title: 'KYC Verified', subtitle: 'Your documents are verified', time: now.subtract(const Duration(days: 5))),
    ];

    withdrawals = [
      WithdrawalRequest(id: _genId('WD'), amount: 500, status: WithdrawalStatus.approved, requestedAt: now.subtract(const Duration(days: 6)), processedAt: now.subtract(const Duration(days: 5))),
    ];

    _registered = true;
  }
}
