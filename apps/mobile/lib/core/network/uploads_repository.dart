import 'dart:io';

import 'package:dio/dio.dart';

import 'api_client.dart';

/// Talks to `UploadsController` (apps/backend/src/modules/uploads) —
/// a generic org-scoped file upload endpoint. Currently used for player
/// photos and ID documents; reusable for other media as the app grows.
class UploadsRepository {
  UploadsRepository(this._apiClient);

  final ApiClient _apiClient;

  /// Uploads [file] and returns the server-relative URL (e.g.
  /// `/uploads/{organizationId}/{uuid}.jpg`) to store on the owning record.
  Future<String> upload(String organizationId, File file) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: file.path.split(Platform.pathSeparator).last),
    });
    final response = await _apiClient.uploadFile(
      '/organizations/$organizationId/uploads',
      data: formData,
    );
    return (response.data as Map<String, dynamic>)['url'] as String;
  }
}
