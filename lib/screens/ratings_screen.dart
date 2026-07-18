import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/app_store.dart';
import '../theme/app_colors.dart';

/// "Ratings dekho" — the partner's average rating plus recent per-trip
/// feedback (`GET /partners/me/ratings`).
class RatingsScreen extends StatelessWidget {
  static const route = '/ratings';
  const RatingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppStore.instance,
      builder: (context, _) {
        final store = AppStore.instance;
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, size: 22),
              onPressed: () => Navigator.maybePop(context),
            ),
            title: Text('My Ratings', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    children: [
                      Text(store.averageRating.toStringAsFixed(1),
                          style: GoogleFonts.inter(fontSize: 40, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (i) {
                          final filled = i < store.averageRating.round();
                          return Icon(
                            filled ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: AppColors.primaryDark,
                            size: 22,
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${store.totalRatings} rated ${store.totalRatings == 1 ? 'trip' : 'trips'}',
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('Recent Feedback', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                if (store.recentRatedParcels.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('No feedback yet', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                    ),
                  )
                else
                  ...store.recentRatedParcels.map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border, width: 1.2),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(p.id, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700)),
                                  Row(
                                    children: List.generate(
                                      5,
                                      (i) => Icon(
                                        i < (p.rating ?? 0) ? Icons.star_rounded : Icons.star_outline_rounded,
                                        size: 14,
                                        color: AppColors.primaryDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if ((p.ratingComment ?? '').isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(p.ratingComment!, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                              ],
                              const SizedBox(height: 6),
                              Text(
                                formatDate(p.receivedAt ?? p.createdAt),
                                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textTertiary),
                              ),
                            ],
                          ),
                        ),
                      )),
              ],
            ),
          ),
        );
      },
    );
  }
}
