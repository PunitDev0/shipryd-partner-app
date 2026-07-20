import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:partner/shared/theme/app_colors.dart';
import 'chat_support_screen.dart';

class HelpCenterScreen extends StatefulWidget {
  static const route = '/help-center';
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  static const _faqs = {
    'How to receive a parcel?':
        'Tap "Scan Parcel" on the dashboard, scan the QR/barcode on the '
            'package, confirm the details, then tap "Confirm Receive" and '
            'optionally add a photo as proof.',
    'How to add bank account?':
        'Go to Profile > Bank Details > Add Bank Account and fill in your '
            'bank name, account number, IFSC code and account holder name.',
    'How to check earnings?':
        'Open the Earnings screen from the dashboard quick actions to see '
            'today, this week and this month\'s totals along with recent '
            'transactions.',
    'What if parcel is damaged?':
        'Do not confirm receipt. Instead use Support > Raise an Issue to '
            'report the damaged parcel with details, and our team will '
            'follow up.',
  };

  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAnswer(String topic) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(topic, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800)),
        content: Text(_faqs[topic] ?? '', style: GoogleFonts.inter(fontSize: 13.5, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Got it')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topics = _faqs.keys
        .where((t) => t.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 22),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          'Help Center',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border, width: 1.4),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _query = v),
                        style: GoogleFonts.inter(fontSize: 13.5),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          hintText: 'Search help topics...',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 13.5,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              Text(
                'Popular Topics',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),

              if (topics.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'No topics match your search',
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                  ),
                )
              else
                ...topics.map(
                  (topic) => InkWell(
                    onTap: () => _showAnswer(topic),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        children: [
                          Icon(
                            Icons.help_outline_rounded,
                            size: 19,
                            color: AppColors.textPrimary,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              topic,
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: AppColors.textTertiary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 20),
              Text(
                'Still need help?',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),

              InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChatSupportScreen()),
                ),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF8E8),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_outline_rounded,
                        size: 20,
                        color: AppColors.textPrimary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Contact Support',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
