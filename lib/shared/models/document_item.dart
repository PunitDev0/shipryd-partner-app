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
