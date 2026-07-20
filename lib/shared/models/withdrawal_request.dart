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
