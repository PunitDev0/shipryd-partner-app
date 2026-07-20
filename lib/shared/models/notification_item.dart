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
