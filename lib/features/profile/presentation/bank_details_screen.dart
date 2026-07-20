import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:partner/shared/state/app_store.dart';
import 'package:partner/shared/theme/app_colors.dart';
import 'package:partner/features/onboarding/presentation/registration_bank_screen.dart';

class BankDetailsScreen extends StatelessWidget {
  static const route = '/bank-details';
  const BankDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppStore.instance,
      builder: (context, _) {
        final accounts = AppStore.instance.bankAccounts;
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, size: 22),
              onPressed: () => Navigator.maybePop(context),
            ),
            title: Text(
              'Bank Details',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  if (accounts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No bank account added yet',
                          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  else
                    for (final account in accounts) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border, width: 1.2),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0B4DA2).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.account_balance_rounded,
                                color: Color(0xFF0B4DA2),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    account.bankName,
                                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    'A/C No.  ••••  ${_lastFour(account.accountNumber)}',
                                    style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'IFSC: ${account.ifsc}',
                                    style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    account.holderName,
                                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegistrationBankScreen(isOnboarding: false),
                        ),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(
                        accounts.isEmpty ? 'Add Bank Account' : 'Replace Bank Account',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryDark,
                        side: BorderSide(
                          color: AppColors.primary.withOpacity(0.6),
                          width: 1.4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _lastFour(String accountNumber) =>
      accountNumber.length <= 4 ? accountNumber : accountNumber.substring(accountNumber.length - 4);
}
