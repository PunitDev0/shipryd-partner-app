import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/app_store.dart';
import '../theme/app_colors.dart';
import '../widgets/transaction_tile.dart';

class TransactionsScreen extends StatelessWidget {
  static const route = '/transactions';
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppStore.instance,
      builder: (context, _) {
        final transactions = AppStore.instance.transactions;
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, size: 22),
              onPressed: () => Navigator.maybePop(context),
            ),
            title: Text(
              'All Transactions',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          body: SafeArea(
            child: transactions.isEmpty
                ? Center(
                    child: Text(
                      'No transactions yet',
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    itemCount: transactions.length,
                    separatorBuilder: (context, i) => Divider(color: AppColors.border, height: 28),
                    itemBuilder: (context, i) {
                      final t = transactions[i];
                      final positive = t.amount >= 0;
                      return TransactionTile(
                        title: t.title,
                        subtitle: t.subtitle,
                        date: formatDateTime(t.date),
                        amount: '${positive ? '+' : ''}${formatAmount(t.amount)}',
                        positive: positive,
                      );
                    },
                  ),
          ),
        );
      },
    );
  }
}
