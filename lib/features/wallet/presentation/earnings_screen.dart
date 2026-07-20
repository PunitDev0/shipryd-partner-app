import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:partner/shared/state/app_store.dart';
import 'package:partner/shared/utils/formatters.dart';
import 'package:partner/shared/data/wallet_service.dart';
import 'package:partner/shared/theme/app_colors.dart';
import '../widgets/transaction_tile.dart';
import 'transactions_screen.dart';

class EarningsScreen extends StatelessWidget {
  static const route = '/earnings';
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppStore.instance,
      builder: (context, _) {
        final store = AppStore.instance;
        final recent = store.transactions.take(3).toList();
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, size: 22),
              onPressed: () => Navigator.maybePop(context),
            ),
            title: Text(
              'Earnings',
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

                  // Total earnings card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Earnings',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.black.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          formatAmount(store.monthEarnings),
                          style: GoogleFonts.inter(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'This Month',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.black.withOpacity(0.65),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: _MiniStatCard(label: 'Today', value: formatAmount(store.todayEarnings)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _MiniStatCard(label: 'This Week', value: formatAmount(store.weekEarnings)),
                      ),
                    ],
                  ),

                  if (store.codSettlementDue > 0) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDECEA),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance_wallet_outlined, size: 20, color: Color(0xFFE53935)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('COD to Settle', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700)),
                                Text(
                                  'Cash collected from customers, owed to the company',
                                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            formatAmount(store.codSettlementDue),
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFFE53935)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (store.todayIncentives != null) ...[
                    const SizedBox(height: 14),
                    _IncentivesCard(incentives: store.todayIncentives!),
                  ],

                  const SizedBox(height: 28),

                  Text(
                    'Recent Transactions',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (recent.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No transactions yet',
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    )
                  else
                    ...recent.map(
                      (t) => Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: TransactionTile(
                          title: t.title,
                          subtitle: t.subtitle,
                          date: formatDate(t.date),
                          amount: '${t.amount >= 0 ? '+' : ''}${formatAmount(t.amount)}',
                          positive: t.amount >= 0,
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TransactionsScreen()),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFFDF8E8),
                        foregroundColor: AppColors.textPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'View All Transactions',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _IncentivesCard extends StatelessWidget {
  final TodayIncentives incentives;
  const _IncentivesCard({required this.incentives});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Peak Hours Incentive ----
          Row(
            children: [
              Icon(Icons.bolt, size: 18, color: incentives.isPeakHourNow ? AppColors.success : AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Peak Hours Incentive',
                  style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
              ),
              if (incentives.isPeakHourNow)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.success.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                  child: Text('Active now', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.success)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '+₹${incentives.peakHourAmount.toStringAsFixed(0)} per ride · ${incentives.peakHourWindows.join(' & ')}',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
          ),
          if (incentives.peakHourEarningsToday > 0) ...[
            const SizedBox(height: 2),
            Text(
              'Earned today: ${formatAmount(incentives.peakHourEarningsToday)}',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success),
            ),
          ],

          const SizedBox(height: 16),
          Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 16),

          // ---- Target Bonus ----
          Row(
            children: [
              const Icon(Icons.emoji_events_outlined, size: 18, color: AppColors.primaryDark),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Target Bonus · ${incentives.ordersToday} orders today',
                  style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...incentives.tiers.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      t.achieved ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 16,
                      color: t.achieved ? AppColors.success : AppColors.textTertiary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${t.orders} orders/day',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: t.achieved ? AppColors.textPrimary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      formatAmount(t.bonus),
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: t.achieved ? AppColors.success : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              )),
          if (incentives.nextTier != null)
            Text(
              '${incentives.nextTier!.ordersRemaining} more order${incentives.nextTier!.ordersRemaining == 1 ? '' : 's'} for ${formatAmount(incentives.nextTier!.bonus)} bonus',
              style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary),
            )
          else
            Text(
              'All target bonuses unlocked today',
              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.success),
            ),
        ],
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
