import 'dart:async';

import 'package:dio/dio.dart';

import 'api_config.dart';
import 'secure_storage.dart';

/// Central place documenting the REST contract the partner app is built
/// against — every path here is a real endpoint on shipryd-backend (see
/// api_config.dart for the base URL).
class ApiPaths {
  static const sendOtp = '/auth/otp/send';
  static const verifyOtp = '/auth/otp/verify';
  static const refresh = '/auth/refresh';
  static const logout = '/auth/logout';
  static const me = '/partners/me';
  static const meVehicle = '/partners/me/vehicle';
  static const meVehicleDetails = '/partners/me/vehicle-details';
  static const meBank = '/partners/me/bank';
  static const meBankVerify = '/partners/me/bank/verify';
  static const meDocuments = '/partners/me/documents';
  static const meDocumentsPresign = '/partners/me/documents/presign';
  static const mePersonal = '/partners/me/personal';
  static const meKyc = '/partners/me/kyc';
  static const meDrivingLicence = '/partners/me/driving-licence';
  static const meBackgroundCheck = '/partners/me/background-check';
  static const meTerms = '/partners/me/terms';
  static const meStatus = '/partners/me/status'; // GET approval status, POST online/offline
  static const meLocation = '/partners/me/location';
  static const meFcmToken = '/partners/me/fcm-token';
  static const meEarnings = '/partners/me/earnings';
  static const meIncentivesToday = '/partners/me/incentives/today';
  static const meWallet = '/partners/me/wallet';
  static const meWithdrawals = '/partners/me/withdrawals';
  static const meRatings = '/partners/me/ratings';
  static const bookings = '/bookings';
  static const tickets = '/tickets';
  static const notifications = '/notifications';
}

typedef SessionExpiredCallback = void Function();

class ApiClient {
  ApiClient._();

  static Dio create({required SessionExpiredCallback onSessionExpired}) {
    final dio = Dio(BaseOptions(
      baseUrl: ApiConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ));

    dio.interceptors.addAll([
      _AuthHeaderInterceptor(),
      _RefreshInterceptor(dio, onSessionExpired: onSessionExpired),
    ]);

    return dio;
  }
}

class _AuthHeaderInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra['skipAuth'] != true) {
      final token = await SecureStorage.instance.accessToken;
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

/// Silently retries a request once after a successful token refresh whenever
/// the mock (or a real) backend answers 401.
class _RefreshInterceptor extends Interceptor {
  final Dio _dio;
  final SessionExpiredCallback onSessionExpired;
  Future<bool>? _refreshing;

  _RefreshInterceptor(this._dio, {required this.onSessionExpired});

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final isAuthEndpoint = err.requestOptions.path == ApiPaths.refresh ||
        err.requestOptions.path == ApiPaths.sendOtp ||
        err.requestOptions.path == ApiPaths.verifyOtp;

    if (err.response?.statusCode != 401 || err.requestOptions.extra['isRetry'] == true || isAuthEndpoint) {
      handler.next(err);
      return;
    }

    _refreshing ??= _doRefresh();
    final refreshed = await _refreshing!;
    _refreshing = null;

    if (!refreshed) {
      onSessionExpired();
      handler.next(err);
      return;
    }

    try {
      final retryOptions = err.requestOptions;
      retryOptions.extra['isRetry'] = true;
      final token = await SecureStorage.instance.accessToken;
      retryOptions.headers['Authorization'] = 'Bearer $token';
      final response = await _dio.fetch(retryOptions);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  Future<bool> _doRefresh() async {
    final refreshToken = await SecureStorage.instance.refreshToken;
    if (refreshToken == null) return false;
    try {
      final response = await _dio.post(
        ApiPaths.refresh,
        data: {'refreshToken': refreshToken},
        options: Options(extra: {'skipAuth': true, 'isRetry': true}),
      );
      await SecureStorage.instance.saveTokens(
        accessToken: response.data['accessToken'] as String,
        refreshToken: response.data['refreshToken'] as String,
      );
      return true;
    } on DioException {
      await SecureStorage.instance.clear();
      return false;
    }
  }
}
