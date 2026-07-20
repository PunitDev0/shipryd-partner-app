import 'package:intl/intl.dart';

String formatTime(DateTime d) => DateFormat('hh:mm a').format(d);
String formatDate(DateTime d) => DateFormat('d MMM, yyyy').format(d);
String formatDateTime(DateTime d) => '${formatTime(d)} · ${formatDate(d)}';
String formatAmount(double v) =>
    '${v < 0 ? '-' : ''}₹${v.abs().toStringAsFixed(v.abs() % 1 == 0 ? 0 : 2)}';
