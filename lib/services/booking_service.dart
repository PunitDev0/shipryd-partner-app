import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/app_exception.dart';
import '../data/models.dart';

/// Order lifecycle: `GET /bookings`, accept/scan/status-update/cancel.
class BookingService {
  final Dio _dio;
  const BookingService(this._dio);

  Future<List<Parcel>> getBookings({String? status}) async {
    try {
      final res = await _dio.get(ApiPaths.bookings, queryParameters: status != null ? {'status': status} : null);
      return (res.data as List).map((e) => Parcel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  Future<Parcel> accept(String id) async {
    try {
      final res = await _dio.post('${ApiPaths.bookings}/$id/accept');
      return Parcel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  Future<Parcel> cancel(String id) async {
    try {
      final res = await _dio.post('${ApiPaths.bookings}/$id/cancel');
      return Parcel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  Future<Parcel> scanOrCreate(String code) async {
    try {
      final res = await _dio.post('${ApiPaths.bookings}/$code/scan');
      return Parcel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  /// `status` is one of: arrived_pickup, picked_up, arrived_drop, delivered.
  Future<Parcel> updateStatus(String id, String status, {String? proofPath, String? otp}) async {
    try {
      final res = await _dio.post('${ApiPaths.bookings}/$id/status', data: {
        'status': status,
        'proofPath': proofPath,
        if (otp != null) 'otp': otp,
      });
      return Parcel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }
}
