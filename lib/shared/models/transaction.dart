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
