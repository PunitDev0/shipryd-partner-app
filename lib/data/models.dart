enum ApprovalStatus { pending, approved, rejected, suspended }

enum ParcelStatus { requested, pending, pickedUp, received, canceled }

enum OrderType { parcel, ride }

class Parcel {
  final String id;
  final OrderType orderType;
  final String orderId;
  final String fromName;
  final String fromAddress;
  final String toAddress;
  final String itemType;
  final double weightKg;
  final String paymentMode;
  final double codAmount;
  final double earning;
  final double distanceKm;
  final int etaMinutes;
  ParcelStatus status;
  bool viewed;
  final DateTime createdAt;
  DateTime? receivedAt;
  String? proofPhotoPath;
  int? rating;
  String? ratingComment;

  Parcel({
    required this.id,
    this.orderType = OrderType.parcel,
    required this.orderId,
    required this.fromName,
    required this.fromAddress,
    required this.toAddress,
    required this.itemType,
    required this.weightKg,
    required this.paymentMode,
    required this.codAmount,
    required this.earning,
    this.distanceKm = 3.2,
    this.etaMinutes = 12,
    this.status = ParcelStatus.pending,
    this.viewed = false,
    DateTime? createdAt,
    this.receivedAt,
    this.proofPhotoPath,
    this.rating,
    this.ratingComment,
  }) : createdAt = createdAt ?? DateTime.now();

  /// The amount the partner must remit to the company for a COD parcel —
  /// they collect the full COD amount in cash from the customer but only
  /// keep their delivery fee, so the rest is a running liability until
  /// settled with the company.
  double get codSettlementDue => paymentMode == 'COD' ? (codAmount - earning).clamp(0, double.infinity) : 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'orderType': orderType.name,
        'orderId': orderId,
        'fromName': fromName,
        'fromAddress': fromAddress,
        'toAddress': toAddress,
        'itemType': itemType,
        'weightKg': weightKg,
        'paymentMode': paymentMode,
        'codAmount': codAmount,
        'earning': earning,
        'distanceKm': distanceKm,
        'etaMinutes': etaMinutes,
        'status': status.name,
        'viewed': viewed,
        'createdAt': createdAt.toIso8601String(),
        'receivedAt': receivedAt?.toIso8601String(),
        'proofPhotoPath': proofPhotoPath,
        'rating': rating,
        'ratingComment': ratingComment,
      };

  factory Parcel.fromJson(Map<String, dynamic> json) => Parcel(
        id: json['id'] as String,
        orderType: OrderType.values.byName(json['orderType'] as String? ?? 'parcel'),
        orderId: json['orderId'] as String,
        fromName: json['fromName'] as String,
        fromAddress: json['fromAddress'] as String,
        toAddress: json['toAddress'] as String,
        itemType: json['itemType'] as String,
        weightKg: (json['weightKg'] as num).toDouble(),
        paymentMode: json['paymentMode'] as String,
        codAmount: (json['codAmount'] as num).toDouble(),
        earning: (json['earning'] as num).toDouble(),
        distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 3.2,
        etaMinutes: (json['etaMinutes'] as num?)?.toInt() ?? 12,
        status: ParcelStatus.values.byName(json['status'] as String),
        viewed: json['viewed'] as bool,
        createdAt: DateTime.parse(json['createdAt'] as String),
        receivedAt: json['receivedAt'] != null
            ? DateTime.parse(json['receivedAt'] as String)
            : null,
        proofPhotoPath: json['proofPhotoPath'] as String?,
        rating: json['rating'] as int?,
        ratingComment: json['ratingComment'] as String?,
      );
}

enum TransactionType { earning, withdrawal, credit, codSettlement }

class Transaction {
  final String id;
  final TransactionType type;
  final String title;
  final String subtitle;
  final double amount;
  final DateTime date;

  const Transaction({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'subtitle': subtitle,
        'amount': amount,
        'date': date.toIso8601String(),
      };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        id: json['id'] as String,
        type: TransactionType.values.byName(json['type'] as String),
        title: json['title'] as String,
        subtitle: json['subtitle'] as String,
        amount: (json['amount'] as num).toDouble(),
        date: DateTime.parse(json['date'] as String),
      );
}

class PartnerProfile {
  String name;
  String email;
  String phone;
  double rating;
  int totalDeliveries;

  PartnerProfile({
    required this.name,
    required this.email,
    required this.phone,
    this.rating = 5.0,
    this.totalDeliveries = 0,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'phone': phone,
        'rating': rating,
        'totalDeliveries': totalDeliveries,
      };

  factory PartnerProfile.fromJson(Map<String, dynamic> json) =>
      PartnerProfile(
        name: json['name'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String,
        rating: (json['rating'] as num).toDouble(),
        totalDeliveries: json['totalDeliveries'] as int,
      );
}

class VehicleInfo {
  String type;
  String number;
  String? brand;
  String? model;
  String? fuelType;
  int? year;

  VehicleInfo({
    required this.type,
    required this.number,
    this.brand,
    this.model,
    this.fuelType,
    this.year,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'number': number,
        'brand': brand,
        'model': model,
        'fuelType': fuelType,
        'year': year,
      };

  factory VehicleInfo.fromJson(Map<String, dynamic> json) => VehicleInfo(
        type: json['type'] as String,
        number: json['number'] as String,
        brand: json['brand'] as String?,
        model: json['model'] as String?,
        fuelType: json['fuelType'] as String?,
        year: json['year'] as int?,
      );
}

enum BankVerificationStatus { unverified, pending, verified, failed }

class BankAccount {
  String bankName;
  String accountNumber;
  String ifsc;
  String holderName;
  BankVerificationStatus verificationStatus;

  BankAccount({
    required this.bankName,
    required this.accountNumber,
    required this.ifsc,
    required this.holderName,
    this.verificationStatus = BankVerificationStatus.unverified,
  });

  Map<String, dynamic> toJson() => {
        'bankName': bankName,
        'accountNumber': accountNumber,
        'ifsc': ifsc,
        'holderName': holderName,
      };

  factory BankAccount.fromJson(Map<String, dynamic> json) => BankAccount(
        bankName: json['bankName'] as String,
        accountNumber: json['accountNumber'] as String,
        ifsc: json['ifsc'] as String,
        holderName: json['holderName'] as String,
        verificationStatus: BankVerificationStatus.values.byName(
          json['verificationStatus'] as String? ?? 'unverified',
        ),
      );
}

// ---- Onboarding: personal details (Step 3) ----
class PersonalDetails {
  DateTime? dob;
  String? gender;
  String emergencyContact;
  String address;
  String city;
  String state;
  String pincode;
  String preferredLanguage;

  PersonalDetails({
    this.dob,
    this.gender,
    this.emergencyContact = '',
    this.address = '',
    this.city = '',
    this.state = '',
    this.pincode = '',
    this.preferredLanguage = 'English',
  });

  Map<String, dynamic> toJson() => {
        'dob': dob?.toIso8601String(),
        'gender': gender,
        'emergencyContact': emergencyContact,
        'address': address,
        'city': city,
        'state': state,
        'pincode': pincode,
        'preferredLanguage': preferredLanguage,
      };

  factory PersonalDetails.fromJson(Map<String, dynamic> json) => PersonalDetails(
        dob: json['dob'] != null ? DateTime.parse(json['dob'] as String) : null,
        gender: json['gender'] as String?,
        emergencyContact: json['emergencyContact'] as String? ?? '',
        address: json['address'] as String? ?? '',
        city: json['city'] as String? ?? '',
        state: json['state'] as String? ?? '',
        pincode: json['pincode'] as String? ?? '',
        preferredLanguage: json['preferredLanguage'] as String? ?? 'English',
      );
}

// ---- Onboarding: KYC — Aadhaar/PAN (Step 5) ----
enum KycStatus { notSubmitted, pending, verified, failed }

class KycDetails {
  String aadhaarNumber;
  String panNumber;
  KycStatus status;

  KycDetails({
    required this.aadhaarNumber,
    required this.panNumber,
    this.status = KycStatus.notSubmitted,
  });

  Map<String, dynamic> toJson() => {'aadhaarNumber': aadhaarNumber, 'panNumber': panNumber};

  factory KycDetails.fromJson(Map<String, dynamic> json) => KycDetails(
        aadhaarNumber: json['aadhaarNumber'] as String,
        panNumber: json['panNumber'] as String,
        status: _kycStatusFromServer(json['status'] as String?),
      );
}

KycStatus _kycStatusFromServer(String? s) => switch (s) {
      'pending' => KycStatus.pending,
      'verified' => KycStatus.verified,
      'failed' => KycStatus.failed,
      _ => KycStatus.notSubmitted,
    };

// ---- Onboarding: driving licence (Step 6) ----
class DrivingLicence {
  String number;
  DateTime expiryDate;
  bool verified;

  DrivingLicence({required this.number, required this.expiryDate, this.verified = false});

  bool get isExpired => expiryDate.isBefore(DateTime.now());

  Map<String, dynamic> toJson() => {'number': number, 'expiryDate': expiryDate.toIso8601String()};

  factory DrivingLicence.fromJson(Map<String, dynamic> json) => DrivingLicence(
        number: json['number'] as String,
        expiryDate: DateTime.parse(json['expiryDate'] as String),
        verified: json['verified'] as bool? ?? false,
      );
}

// ---- Onboarding: background check (Step 9, optional) ----
enum BackgroundCheckStatus { notRequested, pending, clear, flagged }

BackgroundCheckStatus backgroundCheckStatusFromServer(String? s) => switch (s) {
      'pending' => BackgroundCheckStatus.pending,
      'clear' => BackgroundCheckStatus.clear,
      'flagged' => BackgroundCheckStatus.flagged,
      _ => BackgroundCheckStatus.notRequested,
    };

class NotificationItem {
  final String title;
  final String subtitle;
  final DateTime time;
  final String? trailingAmount;
  final bool showChevron;
  bool read;

  NotificationItem({
    required this.title,
    required this.subtitle,
    required this.time,
    this.trailingAmount,
    this.showChevron = false,
    this.read = false,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'subtitle': subtitle,
        'time': time.toIso8601String(),
        'trailingAmount': trailingAmount,
        'showChevron': showChevron,
        'read': read,
      };

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      NotificationItem(
        title: json['title'] as String,
        subtitle: json['subtitle'] as String,
        time: DateTime.parse(json['time'] as String),
        trailingAmount: json['trailingAmount'] as String?,
        showChevron: json['showChevron'] as bool,
        read: json['read'] as bool,
      );
}

enum DocumentStatus { missing, pending, verified }

class DocumentItem {
  final String key;
  final String label;
  String? filePath;
  DocumentStatus status;
  DateTime? expiryDate;

  DocumentItem({
    required this.key,
    required this.label,
    this.filePath,
    this.status = DocumentStatus.missing,
    this.expiryDate,
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'filePath': filePath,
        'status': status.name,
        'expiryDate': expiryDate?.toIso8601String(),
      };

  factory DocumentItem.fromJson(Map<String, dynamic> json) => DocumentItem(
        key: json['key'] as String,
        label: json['label'] as String,
        filePath: json['filePath'] as String?,
        status: DocumentStatus.values.byName(json['status'] as String),
        expiryDate: json['expiryDate'] != null ? DateTime.parse(json['expiryDate'] as String) : null,
      );
}

enum WithdrawalStatus { pending, approved, rejected }

class WithdrawalRequest {
  final String id;
  final double amount;
  WithdrawalStatus status;
  final DateTime requestedAt;
  DateTime? processedAt;

  WithdrawalRequest({
    required this.id,
    required this.amount,
    this.status = WithdrawalStatus.pending,
    DateTime? requestedAt,
    this.processedAt,
  }) : requestedAt = requestedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'status': status.name,
        'requestedAt': requestedAt.toIso8601String(),
        'processedAt': processedAt?.toIso8601String(),
      };

  factory WithdrawalRequest.fromJson(Map<String, dynamic> json) => WithdrawalRequest(
        id: json['id'] as String,
        amount: (json['amount'] as num).toDouble(),
        status: WithdrawalStatus.values.byName(json['status'] as String),
        requestedAt: DateTime.parse(json['requestedAt'] as String),
        processedAt: json['processedAt'] != null ? DateTime.parse(json['processedAt'] as String) : null,
      );
}

class SupportTicket {
  final String id;
  final String subject;
  final String description;
  final DateTime createdAt;
  String status;

  SupportTicket({
    required this.id,
    required this.subject,
    required this.description,
    required this.createdAt,
    this.status = 'Open',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject': subject,
        'description': description,
        'createdAt': createdAt.toIso8601String(),
        'status': status,
      };

  factory SupportTicket.fromJson(Map<String, dynamic> json) => SupportTicket(
        id: json['id'] as String,
        subject: json['subject'] as String,
        description: json['description'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        status: json['status'] as String,
      );
}
