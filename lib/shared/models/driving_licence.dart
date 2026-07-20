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
