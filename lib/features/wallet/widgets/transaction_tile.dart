import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:partner/shared/theme/app_colors.dart';

class TransactionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? date;
  final String amount;
  final bool positive;

  const TransactionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.amount,
    this.date,
    this.positive = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFF6F6F8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.inbox_rounded,
            size: 20,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  color: AppColors.textTertiary,
                ),
              ),
              if (date != null) ...[
                const SizedBox(height: 2),
                Text(
                  date!,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
        Text(
          amount,
          style: GoogleFonts.inter(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: positive ? AppColors.success : const Color(0xFFE53935),
          ),
        ),
      ],
    );
  }
}
