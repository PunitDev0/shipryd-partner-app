import 'package:dio/dio.dart';

/// A user-presentable error, mapped from whatever transport-level failure
/// (Dio/HTTP, or the mock backend) actually happened.
class AppException implements Exception {
  final String message;
  final int? statusCode;

  const AppException(this.message, {this.statusCode});

  factory AppException.fromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      return AppException(data['message'] as String, statusCode: e.response?.statusCode);
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const AppException('Request timed out. Check your connection and try again.');
      case DioExceptionType.connectionError:
        return const AppException('No internet connection.');
      default:
        return AppException(
          e.response?.statusCode == 401
              ? 'Session expired. Please log in again.'
              : 'Something went wrong. Please try again.',
          statusCode: e.response?.statusCode,
        );
    }
  }

  @override
  String toString() => message;
}
