import 'dart:io';

import 'package:dio/dio.dart';

import 'package:partner/core/api_client.dart';
import 'package:partner/core/app_exception.dart';
import 'package:partner/shared/models/models.dart';

/// Registration KYC (vehicle/bank/documents), approval-status polling,
/// online/offline + location broadcasting, and document-expiry alerts.
class PartnerService {
  final Dio _dio;
  const PartnerService(this._dio);

  Future<VehicleInfo?> getVehicle() async {
    try {
      final res = await _dio.get(ApiPaths.meVehicle);
      if (res.data == null) return null;
      return VehicleInfo.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  Future<VehicleInfo> setVehicle(VehicleInfo vehicle) async {
    try {
      final numVal = vehicle.number.isNotEmpty ? vehicle.number : 'PENDING';
      final res = await _dio.post(ApiPaths.meVehicle, data: {
        'type': vehicle.type,
        'number': numVal,
      });
      return VehicleInfo.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  /// Step 7 — brand/model/fuelType/year, layered on top of the type+number
  /// already captured at Step 2 via [setVehicle].
  Future<VehicleInfo> setVehicleDetails(VehicleInfo vehicle) async {
    try {
      final res = await _dio.post(ApiPaths.meVehicleDetails, data: {
        'number': vehicle.number,
        'brand': vehicle.brand,
        'model': vehicle.model,
        'fuelType': vehicle.fuelType,
        'year': vehicle.year,
      });
      final data = res.data as Map<String, dynamic>;
      return VehicleInfo.fromJson({...data, 'type': vehicle.type});
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  Future<BankAccount?> getBank() async {
    try {
      final res = await _dio.get(ApiPaths.meBank);
      if (res.data == null) return null;
      return BankAccount.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  Future<BankAccount> setBank(BankAccount bank) async {
    try {
      final res = await _dio.post(ApiPaths.meBank, data: bank.toJson());
      return BankAccount.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  /// Step 8 — triggers penny-drop bank verification (demo auto-verify
  /// after a few seconds server-side; see partners.service.js).
  Future<BankAccount> verifyBank() async {
    try {
      final res = await _dio.post(ApiPaths.meBankVerify);
      return BankAccount.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  Future<DocumentItem> uploadDocument(String key, String filePath) async {
    try {
      final res = await _dio.post(ApiPaths.meDocuments, data: {'key': key, 'filePath': filePath});
      return DocumentItem.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  /// Real end-to-end file upload: asks the backend for a presigned S3 PUT
  /// URL, uploads the raw bytes directly to S3, then records the returned
  /// public URL against [docType] via [uploadDocument] (unchanged) — the
  /// old flow just POSTed a local device path and never sent any bytes.
  Future<DocumentItem> uploadDocumentFile(String docType, File file) async {
    try {
      final contentType = _contentTypeFor(file.path);
      final presign = await _dio.post(ApiPaths.meDocumentsPresign, data: {
        'docType': docType,
        'contentType': contentType,
      });
      final uploadUrl = (presign.data as Map<String, dynamic>)['uploadUrl'] as String;
      final publicUrl = (presign.data as Map<String, dynamic>)['publicUrl'] as String;

      await Dio().put(
        uploadUrl,
        data: file.openRead(),
        options: Options(
          headers: {
            'Content-Type': contentType,
            Headers.contentLengthHeader: await file.length(),
          },
        ),
      );

      return uploadDocument(docType, publicUrl);
    } catch (_) {
      try {
        final fileName = file.path.split('/').last;
        final formData = FormData.fromMap({
          'docType': docType,
          'file': await MultipartFile.fromFile(file.path, filename: fileName),
        });

        final res = await _dio.post(
          '/partners/me/documents/upload',
          data: formData,
        );
        return DocumentItem.fromJson(res.data as Map<String, dynamic>);
      } on DioException catch (e2) {
        throw AppException.fromDio(e2);
      } catch (e2) {
        throw AppException(e2.toString());
      }
    }
  }

  String _contentTypeFor(String path) {
    final ext = path.split('.').last.toLowerCase();
    return switch (ext) {
      'png' => 'image/png',
      'heic' => 'image/heic',
      'pdf' => 'application/pdf',
      _ => 'image/jpeg',
    };
  }

  // ---- Step 3: personal details ----

  Future<PersonalDetails?> getPersonalDetails() async {
    try {
      final res = await _dio.get(ApiPaths.mePersonal);
      if (res.data == null) return null;
      return PersonalDetails.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  Future<PersonalDetails> setPersonalDetails(PersonalDetails details) async {
    try {
      final res = await _dio.patch(ApiPaths.mePersonal, data: details.toJson());
      return PersonalDetails.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  // ---- Step 5: KYC (Aadhaar/PAN) ----

  Future<KycDetails?> getKyc() async {
    try {
      final res = await _dio.get(ApiPaths.meKyc);
      if (res.data == null) return null;
      return KycDetails.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  Future<KycDetails> setKyc(KycDetails kyc) async {
    try {
      final res = await _dio.post(ApiPaths.meKyc, data: kyc.toJson());
      return KycDetails.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  // ---- Step 6: driving licence ----

  Future<DrivingLicence?> getDrivingLicence() async {
    try {
      final res = await _dio.get(ApiPaths.meDrivingLicence);
      if (res.data == null) return null;
      return DrivingLicence.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  Future<DrivingLicence> setDrivingLicence(DrivingLicence licence) async {
    try {
      final res = await _dio.post(ApiPaths.meDrivingLicence, data: licence.toJson());
      return DrivingLicence.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  // ---- Step 9: background check (optional) ----

  Future<BackgroundCheckStatus> requestBackgroundCheck({required bool consented}) async {
    try {
      final res = await _dio.post(ApiPaths.meBackgroundCheck, data: {'consented': consented});
      return backgroundCheckStatusFromServer((res.data as Map<String, dynamic>)['status'] as String?);
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  Future<BackgroundCheckStatus> getBackgroundCheck() async {
    try {
      final res = await _dio.get(ApiPaths.meBackgroundCheck);
      if (res.data == null) return BackgroundCheckStatus.notRequested;
      return backgroundCheckStatusFromServer((res.data as Map<String, dynamic>)['status'] as String?);
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  // ---- Step 10: terms & conditions ----

  Future<void> acceptTerms() async {
    try {
      await _dio.post(ApiPaths.meTerms, data: {
        'partnerAgreement': true,
        'privacyPolicy': true,
        'earningsPolicy': true,
        'cancellationPolicy': true,
      });
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  Future<List<DocumentItem>> getDocuments() async {
    try {
      final res = await _dio.get(ApiPaths.meDocuments);
      return (res.data as List).map((e) => DocumentItem.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  Future<ApprovalStatus> getApprovalStatus() async {
    try {
      final res = await _dio.get(ApiPaths.meStatus);
      return ApprovalStatus.values.byName((res.data as Map<String, dynamic>)['approvalStatus'] as String);
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  Future<bool> setOnlineStatus(bool online) async {
    try {
      final res = await _dio.post(ApiPaths.meStatus, data: {'online': online});
      return (res.data as Map<String, dynamic>)['isOnline'] as bool;
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  Future<void> updateLocation(double lat, double lng) async {
    try {
      await _dio.post(ApiPaths.meLocation, data: {'lat': lat, 'lng': lng});
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  /// Registers this device's FCM token so the dispatch worker can push a
  /// real notification alongside the in-app `order:request` popup.
  Future<void> registerFcmToken(String token) async {
    try {
      await _dio.post(ApiPaths.meFcmToken, data: {'token': token});
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }
}
