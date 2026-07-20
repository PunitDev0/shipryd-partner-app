/// The partner app's order domain model.
///
/// The backend serves both Parcel deliveries and Quick Rides from a single
/// `Booking` collection (see shipryd-backend `Booking.orderType`), but the
/// partner app must never let the two mix once an order reaches the UI —
/// a ride must only ever be handled by ride screens/controllers, a parcel
/// only by parcel screens/controllers.
///
/// [Order] is `sealed` specifically so that decision is enforced by the
/// compiler: any `switch` over an [Order] (see `OrderNavigation`) must
/// handle both [ParcelOrder] and [RideOrder] or it won't compile. There is
/// exactly one place in the app that inspects the wire `orderType` string —
/// [Order.fromJson] below — everywhere else works with the already-typed
/// subclass.
library;

enum OrderStatus { requested, pending, pickedUp, received, canceled }

sealed class Order {
  final String id;
  final String orderId;
  final String fromName;
  final String fromAddress;
  final String toAddress;
  final String paymentMode;
  final String paymentStatus;
  final double codAmount;
  final double earning;
  final double distanceKm;
  final int etaMinutes;
  OrderStatus status;
  String rawStatus;
  final double pickupLat;
  final double pickupLng;
  final double dropLat;
  final double dropLng;
  bool viewed;
  final DateTime createdAt;
  DateTime? receivedAt;
  String? proofPhotoPath;
  int? rating;
  String? ratingComment;

  Order({
    required this.id,
    required this.orderId,
    required this.fromName,
    required this.fromAddress,
    required this.toAddress,
    required this.paymentMode,
    this.paymentStatus = 'pending',
    required this.codAmount,
    required this.earning,
    this.distanceKm = 3.2,
    this.etaMinutes = 12,
    this.status = OrderStatus.pending,
    required this.rawStatus,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropLat,
    required this.dropLng,
    this.viewed = false,
    DateTime? createdAt,
    this.receivedAt,
    this.proofPhotoPath,
    this.rating,
    this.ratingComment,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Badge text shown on the incoming-offer overlay.
  String get typeLabel;

  /// Extra chips shown on the incoming-offer overlay (e.g. weight for a
  /// parcel); empty for order types with nothing extra to show.
  List<String> get extraDetailChips;

  /// Short one-word/phrase description of what's being carried — the
  /// parcel's item type, or "Ride" for a ride.
  String get itemDescription;

  /// The amount the partner must remit to the company for a COD order —
  /// they collect the full COD amount in cash but only keep their fee, so
  /// the rest is a running liability until settled with the company.
  double get codSettlementDue => paymentMode == 'COD' ? (codAmount - earning).clamp(0, double.infinity) : 0;

  Map<String, dynamic> toJson();

  static Order fromJson(Map<String, dynamic> json) {
    final isRide = (json['orderType'] as String? ?? 'parcel') == 'ride';
    return isRide ? RideOrder._fromJson(json) : ParcelOrder._fromJson(json);
  }

  Map<String, dynamic> _baseJson(String orderType) => {
        'id': id,
        'orderType': orderType,
        'orderId': orderId,
        'fromName': fromName,
        'fromAddress': fromAddress,
        'toAddress': toAddress,
        'paymentMode': paymentMode,
        'paymentStatus': paymentStatus,
        'codAmount': codAmount,
        'earning': earning,
        'distanceKm': distanceKm,
        'etaMinutes': etaMinutes,
        'status': status.name,
        'rawStatus': rawStatus,
        'pickupLat': pickupLat,
        'pickupLng': pickupLng,
        'dropLat': dropLat,
        'dropLng': dropLng,
        'viewed': viewed,
        'createdAt': createdAt.toIso8601String(),
        'receivedAt': receivedAt?.toIso8601String(),
        'proofPhotoPath': proofPhotoPath,
        'rating': rating,
        'ratingComment': ratingComment,
      };
}

class ParcelOrder extends Order {
  final String itemType;
  final double weightKg;
  final String senderName;
  final String senderPhone;
  final String recipientName;
  final String recipientPhone;
  final String? pickupInstruction;
  final String? dropInstruction;
  String? pickupPhotoPath;
  String? deliveryPhotoPath;

  ParcelOrder({
    required super.id,
    required super.orderId,
    required super.fromName,
    required super.fromAddress,
    required super.toAddress,
    required this.itemType,
    required this.weightKg,
    String? senderName,
    String? senderPhone,
    String? recipientName,
    String? recipientPhone,
    this.pickupInstruction,
    this.dropInstruction,
    this.pickupPhotoPath,
    this.deliveryPhotoPath,
    required super.paymentMode,
    super.paymentStatus = 'pending',
    required super.codAmount,
    required super.earning,
    super.distanceKm,
    super.etaMinutes,
    super.status,
    required super.rawStatus,
    required super.pickupLat,
    required super.pickupLng,
    required super.dropLat,
    required super.dropLng,
    super.viewed,
    super.createdAt,
    super.receivedAt,
    super.proofPhotoPath,
    super.rating,
    super.ratingComment,
  })  : senderName = senderName ?? fromName,
        senderPhone = senderPhone ?? '+91 98765 43210',
        recipientName = recipientName ?? 'Recipient (Drop)',
        recipientPhone = recipientPhone ?? '+91 91234 56789';

  @override
  String get typeLabel => 'NEW PARCEL REQUEST';

  @override
  List<String> get extraDetailChips => ['$weightKg kg', itemType];

  @override
  String get itemDescription => '$itemType ($weightKg kg)';

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson('parcel'),
        'itemType': itemType,
        'weightKg': weightKg,
        'senderName': senderName,
        'senderPhone': senderPhone,
        'recipientName': recipientName,
        'recipientPhone': recipientPhone,
        'pickupInstruction': pickupInstruction,
        'dropInstruction': dropInstruction,
        'pickupPhotoPath': pickupPhotoPath,
        'deliveryPhotoPath': deliveryPhotoPath,
      };

  factory ParcelOrder._fromJson(Map<String, dynamic> json) => ParcelOrder(
        id: json['id'] as String,
        orderId: json['orderId'] as String,
        fromName: json['fromName'] as String,
        fromAddress: json['fromAddress'] as String,
        toAddress: json['toAddress'] as String,
        itemType: json['itemType'] as String? ?? 'Parcel',
        weightKg: (json['weightKg'] as num?)?.toDouble() ?? 1.5,
        senderName: json['senderName'] as String?,
        senderPhone: json['senderPhone'] as String?,
        recipientName: json['recipientName'] as String?,
        recipientPhone: json['recipientPhone'] as String?,
        pickupInstruction: json['pickupInstruction'] as String?,
        dropInstruction: json['dropInstruction'] as String?,
        pickupPhotoPath: json['pickupPhotoPath'] as String?,
        deliveryPhotoPath: json['deliveryPhotoPath'] as String?,
        paymentMode: json['paymentMode'] as String,
        paymentStatus: json['paymentStatus'] as String? ?? 'pending',
        codAmount: (json['codAmount'] as num).toDouble(),
        earning: (json['earning'] as num).toDouble(),
        distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 3.2,
        etaMinutes: (json['etaMinutes'] as num?)?.toInt() ?? 12,
        status: _statusFromWire(json['status'] as String),
        rawStatus: json['rawStatus'] as String? ?? json['status'] as String,
        pickupLat: (json['pickupLat'] as num?)?.toDouble() ?? 28.6273,
        pickupLng: (json['pickupLng'] as num?)?.toDouble() ?? 77.3725,
        dropLat: (json['dropLat'] as num?)?.toDouble() ?? 28.6300,
        dropLng: (json['dropLng'] as num?)?.toDouble() ?? 77.3750,
        viewed: json['viewed'] as bool,
        createdAt: DateTime.parse(json['createdAt'] as String),
        receivedAt: json['receivedAt'] != null ? DateTime.parse(json['receivedAt'] as String) : null,
        proofPhotoPath: json['proofPhotoPath'] as String?,
        rating: json['rating'] as int?,
        ratingComment: json['ratingComment'] as String?,
      );
}

class RideOrder extends Order {
  RideOrder({
    required super.id,
    required super.orderId,
    required super.fromName,
    required super.fromAddress,
    required super.toAddress,
    required super.paymentMode,
    super.paymentStatus = 'pending',
    required super.codAmount,
    required super.earning,
    super.distanceKm,
    super.etaMinutes,
    super.status,
    required super.rawStatus,
    required super.pickupLat,
    required super.pickupLng,
    required super.dropLat,
    required super.dropLng,
    super.viewed,
    super.createdAt,
    super.receivedAt,
    super.proofPhotoPath,
    super.rating,
    super.ratingComment,
  });

  @override
  String get typeLabel => 'NEW RIDE REQUEST';

  @override
  List<String> get extraDetailChips => const [];

  @override
  String get itemDescription => 'Ride';

  @override
  Map<String, dynamic> toJson() => _baseJson('ride');

  factory RideOrder._fromJson(Map<String, dynamic> json) => RideOrder(
        id: json['id'] as String,
        orderId: json['orderId'] as String,
        fromName: json['fromName'] as String,
        fromAddress: json['fromAddress'] as String,
        toAddress: json['toAddress'] as String,
        paymentMode: json['paymentMode'] as String,
        paymentStatus: json['paymentStatus'] as String? ?? 'pending',
        codAmount: (json['codAmount'] as num).toDouble(),
        earning: (json['earning'] as num).toDouble(),
        distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 3.2,
        etaMinutes: (json['etaMinutes'] as num?)?.toInt() ?? 12,
        status: _statusFromWire(json['status'] as String),
        rawStatus: json['rawStatus'] as String? ?? json['status'] as String,
        pickupLat: (json['pickupLat'] as num?)?.toDouble() ?? 28.6273,
        pickupLng: (json['pickupLng'] as num?)?.toDouble() ?? 77.3725,
        dropLat: (json['dropLat'] as num?)?.toDouble() ?? 28.6300,
        dropLng: (json['dropLng'] as num?)?.toDouble() ?? 77.3750,
        viewed: json['viewed'] as bool,
        createdAt: DateTime.parse(json['createdAt'] as String),
        receivedAt: json['receivedAt'] != null ? DateTime.parse(json['receivedAt'] as String) : null,
        proofPhotoPath: json['proofPhotoPath'] as String?,
        rating: json['rating'] as int?,
        ratingComment: json['ratingComment'] as String?,
      );
}

OrderStatus _statusFromWire(String s) => OrderStatus.values.byName(s);
