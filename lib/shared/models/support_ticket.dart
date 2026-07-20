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
