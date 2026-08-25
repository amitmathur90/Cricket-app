import 'package:dio/dio.dart';

/// A normalized error surfaced to the UI layer — hides Dio's exception
/// shape behind a single message + status code, matching NestJS's default
/// error body: `{ statusCode, message, error }` (message may be a string or
/// an array of class-validator messages).
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;
  bool get isConflict => statusCode == 409;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

ApiException apiExceptionFromDio(DioException error) {
  final response = error.response;
  final data = response?.data;

  String message;
  if (data is Map<String, dynamic> && data['message'] != null) {
    final raw = data['message'];
    message = raw is List ? raw.join(', ') : raw.toString();
  } else if (error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout) {
    message = 'The server took too long to respond. Please try again.';
  } else if (error.type == DioExceptionType.connectionError) {
    message = 'Could not reach the server. Check your connection and the API base URL.';
  } else {
    message = error.message ?? 'Something went wrong';
  }

  return ApiException(message, statusCode: response?.statusCode);
}
