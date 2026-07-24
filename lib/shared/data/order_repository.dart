import 'package:dio/dio.dart';

import 'package:partner/core/api_client.dart';
import 'package:partner/core/app_exception.dart';
import 'package:partner/shared/models/order.dart';

/// Order lifecycle: `GET /bookings`, accept/scan/status-update/cancel.
///
/// The backend serves both ride and parcel bookings from one `/bookings`
/// collection (see shipryd-backend `Booking.orderType`), so this stays one
/// repository rather than being artificially split in two — every method
/// returns [Order], and [Order.fromJson] is what turns the wire payload
/// into the correctly-typed [ParcelOrder]/[RideOrder] subclass. Callers
/// that need a specific subtype (`ParcelController`/`RideController`) do
/// the narrowing themselves; this class never inspects `orderType` itself.
class OrderRepository {
  final Dio _dio;
  const OrderRepository(this._dio);

  Future<List<Order>> getOrders({String? status}) async {
    try {
      final res = await _dio.get(ApiPaths.bookings, queryParameters: status != null ? {'status': status} : null);
      return (res.data as List).map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  Future<Order> accept(String id) async {
    try {
      final res = await _dio.post('${ApiPaths.bookings}/$id/accept');
      return Order.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  Future<Order> cancel(String id) async {
    try {
      final res = await _dio.post('${ApiPaths.bookings}/$id/cancel');
      return Order.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  Future<Order> scanOrCreate(String code) async {
    try {
      final res = await _dio.post('${ApiPaths.bookings}/$code/scan');
      return Order.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  /// `status` is one of: arrived_pickup, picked_up, arrived_drop, delivered.
  Future<Order> updateStatus(String id, String status, {String? proofPath, String? otp}) async {
    try {
      final res = await _dio.post('${ApiPaths.bookings}/$id/status', data: {
        'status': status,
        'proofPath': proofPath,
        if (otp != null) 'otp': otp,
      });
      return Order.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> initiatePayment({required double amount, required String bookingId}) async {
    try {
      final res = await _dio.post(ApiPaths.initiatePayment, data: {
        'amount': amount,
        'bookingId': bookingId,
      });
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  Future<List<Map<String, dynamic>>> getDemandHeatmap() async {
    try {
      final res = await _dio.get('${ApiPaths.bookings}/demand');
      return List<Map<String, dynamic>>.from(
        (res.data as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }
}
