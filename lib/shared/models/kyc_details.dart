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
