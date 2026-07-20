import 'package:dio/dio.dart';

import 'package:partner/core/api_client.dart';
import 'package:partner/core/app_exception.dart';
import 'package:partner/shared/models/models.dart';

class TicketService {
  final Dio _dio;
  const TicketService(this._dio);

  Future<SupportTicket> raise(String subject, String description) async {
    try {
      final res = await _dio.post(ApiPaths.tickets, data: {'subject': subject, 'description': description});
      return SupportTicket.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  Future<List<SupportTicket>> list() async {
    try {
      final res = await _dio.get(ApiPaths.tickets);
      return (res.data as List).map((e) => SupportTicket.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }
}
