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
