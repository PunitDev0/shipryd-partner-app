import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/app_exception.dart';
import '../data/models.dart';

/// `GET /notifications` — replaces the old mock's shared in-memory list;
/// every action that used to push straight into `MockBackend.notifications`
/// now just re-fetches this after the server records its own notification.
class NotificationService {
  final Dio _dio;
  const NotificationService(this._dio);

  Future<List<NotificationItem>> list() async {
    try {
      final res = await _dio.get(ApiPaths.notifications);
      return (res.data as List).map((e) => NotificationItem.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }
}
