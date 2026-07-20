import 'package:dio/dio.dart';

import 'package:partner/core/api_client.dart';
import 'package:partner/core/app_exception.dart';
import 'package:partner/core/secure_storage.dart';
import 'package:partner/shared/models/models.dart';

class OtpVerifyResult {
  final PartnerProfile profile;
  final ApprovalStatus approvalStatus;
  final bool isNewUser;
  const OtpVerifyResult(this.profile, this.approvalStatus, this.isNewUser);
}

/// Implements the auth/registration half of the spec: phone+OTP via the
/// shared `/auth/otp/*` endpoints (role: partner), silent refresh (handled
/// inside [ApiClient]'s interceptor), and logout.
class AuthService {
  final Dio _dio;
  const AuthService(this._dio);

  Future<void> sendOtp(String phone) async {
    try {
      await _dio.post(ApiPaths.sendOtp, data: {'phone': phone, 'role': 'partner'}, options: Options(extra: {'skipAuth': true}));
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  /// Verifies the OTP and, on success, creates a session — for a brand-new
  /// phone number this also creates the Partner account (passing [name]/
  /// [email] collected during registration); for a returning partner those
  /// are ignored server-side.
  Future<OtpVerifyResult> verifyOtp(String phone, String otp, {String? name, String? email}) async {
    try {
      final res = await _dio.post(
        ApiPaths.verifyOtp,
        data: {
          'phone': phone,
          'otp': otp,
          'role': 'partner',
          if (name != null) 'name': name,
          if (email != null) 'email': email,
        },
        options: Options(extra: {'skipAuth': true}),
      );
      final data = res.data as Map<String, dynamic>;
      await SecureStorage.instance.saveTokens(accessToken: data['accessToken'] as String, refreshToken: data['refreshToken'] as String);
      final partnerJson = data['partner'] as Map<String, dynamic>;
      return OtpVerifyResult(
        PartnerProfile.fromJson(partnerJson),
        ApprovalStatus.values.byName(partnerJson['approvalStatus'] as String),
        data['isNewUser'] as bool,
      );
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  Future<PartnerProfile> getMe() async {
    try {
      final res = await _dio.get(ApiPaths.me);
      return PartnerProfile.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  Future<PartnerProfile> updateProfile({required String name, required String email}) async {
    try {
      final res = await _dio.patch(ApiPaths.me, data: {'name': name, 'email': email});
      return PartnerProfile.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  Future<bool> hasSession() async => await SecureStorage.instance.refreshToken != null;

  Future<void> logout() async {
    try {
      await _dio.post(ApiPaths.logout);
    } on DioException {
      // best-effort — always clear locally regardless
    } finally {
      await SecureStorage.instance.clear();
    }
  }
}
