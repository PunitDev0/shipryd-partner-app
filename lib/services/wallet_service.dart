import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/app_exception.dart';
import '../data/models.dart';

class EarningsSummary {
  final String period;
  final double totalEarning;
  final int tripCount;
  final double incentives;
  const EarningsSummary({required this.period, required this.totalEarning, required this.tripCount, required this.incentives});
}

class IncentiveTier {
  final int orders;
  final double bonus;
  final bool achieved;
  final int ordersRemaining;
  const IncentiveTier({required this.orders, required this.bonus, required this.achieved, required this.ordersRemaining});

  factory IncentiveTier.fromJson(Map<String, dynamic> json) => IncentiveTier(
        orders: json['orders'] as int,
        bonus: (json['bonus'] as num).toDouble(),
        achieved: json['achieved'] as bool,
        ordersRemaining: json['ordersRemaining'] as int,
      );
}

/// Today's (IST) Peak Hours Incentive + Target Bonus snapshot — powers the
/// incentive card on the earnings screen.
class TodayIncentives {
  final int ordersToday;
  final bool isPeakHourNow;
  final double peakHourAmount;
  final List<String> peakHourWindows;
  final double peakHourEarningsToday;
  final double targetBonusEarnedToday;
  final List<IncentiveTier> tiers;
  final IncentiveTier? nextTier;

  const TodayIncentives({
    required this.ordersToday,
    required this.isPeakHourNow,
    required this.peakHourAmount,
    required this.peakHourWindows,
    required this.peakHourEarningsToday,
    required this.targetBonusEarnedToday,
    required this.tiers,
    required this.nextTier,
  });

  factory TodayIncentives.fromJson(Map<String, dynamic> json) => TodayIncentives(
        ordersToday: json['ordersToday'] as int,
        isPeakHourNow: json['isPeakHourNow'] as bool,
        peakHourAmount: (json['peakHourAmount'] as num).toDouble(),
        peakHourWindows: (json['peakHourWindows'] as List).cast<String>(),
        peakHourEarningsToday: (json['peakHourEarningsToday'] as num).toDouble(),
        targetBonusEarnedToday: (json['targetBonusEarnedToday'] as num).toDouble(),
        tiers: (json['tiers'] as List).map((e) => IncentiveTier.fromJson(e as Map<String, dynamic>)).toList(),
        nextTier: json['nextTier'] != null ? IncentiveTier.fromJson(json['nextTier'] as Map<String, dynamic>) : null,
      );
}

class WalletSnapshot {
  final double balance;
  final double codSettlementDue;
  final List<Transaction> transactions;
  const WalletSnapshot({required this.balance, required this.codSettlementDue, required this.transactions});
}

class RatingsSummary {
  final double average;
  final int total;
  final List<Parcel> recent;
  const RatingsSummary({required this.average, required this.total, required this.recent});
}

/// Earnings by period, wallet balance + COD settlement ledger, withdrawal
/// requests (pending → admin-approved → payout), and ratings.
class WalletService {
  final Dio _dio;
  const WalletService(this._dio);

  Future<EarningsSummary> getEarnings({required String period}) async {
    try {
      final res = await _dio.get(ApiPaths.meEarnings, queryParameters: {'period': period});
      final data = res.data as Map<String, dynamic>;
      return EarningsSummary(
        period: data['period'] as String,
        totalEarning: (data['totalEarning'] as num).toDouble(),
        tripCount: data['tripCount'] as int,
        incentives: (data['incentives'] as num).toDouble(),
      );
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  Future<TodayIncentives> getTodayIncentives() async {
    try {
      final res = await _dio.get(ApiPaths.meIncentivesToday);
      return TodayIncentives.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  Future<WalletSnapshot> getWallet() async {
    try {
      final res = await _dio.get(ApiPaths.meWallet);
      final data = res.data as Map<String, dynamic>;
      return WalletSnapshot(
        balance: (data['balance'] as num).toDouble(),
        codSettlementDue: (data['codSettlementDue'] as num).toDouble(),
        transactions: (data['transactions'] as List).map((e) => Transaction.fromJson(e as Map<String, dynamic>)).toList(),
      );
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  Future<WithdrawalRequest> requestWithdrawal(double amount) async {
    try {
      final res = await _dio.post(ApiPaths.meWithdrawals, data: {'amount': amount});
      return WithdrawalRequest.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  Future<List<WithdrawalRequest>> getWithdrawals() async {
    try {
      final res = await _dio.get(ApiPaths.meWithdrawals);
      return (res.data as List).map((e) => WithdrawalRequest.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  Future<RatingsSummary> getRatings() async {
    try {
      final res = await _dio.get(ApiPaths.meRatings);
      final data = res.data as Map<String, dynamic>;
      final recent = (data['recent'] as List)
          .map((e) => Parcel(
                id: e['parcelId'] as String,
                orderId: '',
                fromName: '',
                fromAddress: '',
                toAddress: '',
                itemType: '',
                weightKg: 0,
                paymentMode: 'Prepaid',
                codAmount: 0,
                earning: 0,
                status: ParcelStatus.received,
                createdAt: DateTime.parse(e['date'] as String),
                rating: e['rating'] as int?,
                ratingComment: e['comment'] as String?,
              ))
          .toList();
      return RatingsSummary(average: (data['averageRating'] as num).toDouble(), total: data['totalRatings'] as int, recent: recent);
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }
}
