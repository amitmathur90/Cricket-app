import 'dart:async';

import 'package:dio/dio.dart';

import '../config/env.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

/// Endpoint paths that must NOT get an `Authorization` header attached, and
/// must NOT trigger the 401-refresh-and-retry flow — attempting either for
/// these would recurse into `/auth/refresh` itself.
///
/// Note `/auth/select-org` is intentionally excluded from this list: unlike
/// login/register/refresh it *requires* a bearer token (see
/// apps/backend/src/modules/auth/auth.controller.ts), so it must go through
/// the normal attach/refresh path.
const _unauthenticatedPaths = ['/auth/login', '/auth/register', '/auth/refresh'];

bool _isUnauthenticatedPath(String path) =>
    _unauthenticatedPaths.any((p) => path.startsWith(p));

/// Dio-based API client talking to the NestJS backend.
///
/// Responsibilities:
///  - attach the JWT access token (from secure storage) to every request
///    that needs one;
///  - on a 401 response, attempt a single silent refresh (`POST
///    /auth/refresh`) and retry the original request once;
///  - if the refresh itself fails (refresh token expired/revoked/reused),
///    clear stored tokens and notify [onSessionExpired] so the app can route
///    back to the login screen.
class ApiClient {
  ApiClient({TokenStorage? tokenStorage, this.onSessionExpired})
      : tokenStorage = tokenStorage ?? TokenStorage() {
    _dio = Dio(
      BaseOptions(
        baseUrl: Env.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        contentType: 'application/json',
      ),
    );
    _dio.interceptors.add(_AuthInterceptor(this));
  }

  final TokenStorage tokenStorage;

  /// Invoked when the refresh token is no longer usable — the session is
  /// over and the caller should clear app state and navigate to login.
  final Future<void> Function()? onSessionExpired;

  late final Dio _dio;

  Completer<String?>? _refreshInFlight;

  /// Performs the actual `/auth/refresh` call, de-duplicating concurrent
  /// callers (e.g. several requests failing with 401 at once) behind a
  /// single in-flight [Completer].
  Future<String?> refreshAccessToken() {
    final inFlight = _refreshInFlight;
    if (inFlight != null) {
      return inFlight.future;
    }

    final completer = Completer<String?>();
    _refreshInFlight = completer;

    () async {
      try {
        final refreshToken = await tokenStorage.readRefreshToken();
        if (refreshToken == null) {
          completer.complete(null);
          return;
        }

        // Bare Dio instance: must not go through this client's interceptor
        // (which would try to attach an access token / re-trigger refresh).
        final plain = Dio(BaseOptions(baseUrl: Env.apiBaseUrl));
        final response = await plain.post<Map<String, dynamic>>(
          '/auth/refresh',
          data: {'refreshToken': refreshToken},
        );
        final body = response.data!;
        final newAccessToken = body['accessToken'] as String;
        final newRefreshToken = body['refreshToken'] as String;
        await tokenStorage.saveTokens(accessToken: newAccessToken, refreshToken: newRefreshToken);
        completer.complete(newAccessToken);
      } catch (_) {
        await tokenStorage.clear();
        completer.complete(null);
      } finally {
        _refreshInFlight = null;
      }
    }();

    return completer.future;
  }

  Future<Response<dynamic>> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw apiExceptionFromDio(e);
    }
  }

  Future<Response<dynamic>> post(String path, {dynamic data}) async {
    try {
      return await _dio.post(path, data: data);
    } on DioException catch (e) {
      throw apiExceptionFromDio(e);
    }
  }

  Future<Response<dynamic>> patch(String path, {dynamic data}) async {
    try {
      return await _dio.patch(path, data: data);
    } on DioException catch (e) {
      throw apiExceptionFromDio(e);
    }
  }

  Future<Response<dynamic>> put(String path, {dynamic data}) async {
    try {
      return await _dio.put(path, data: data);
    } on DioException catch (e) {
      throw apiExceptionFromDio(e);
    }
  }

  Future<Response<dynamic>> delete(String path) async {
    try {
      return await _dio.delete(path);
    } on DioException catch (e) {
      throw apiExceptionFromDio(e);
    }
  }

  /// Multipart file upload. The client's [BaseOptions.contentType] defaults
  /// to `application/json`, which would break the multipart boundary if not
  /// explicitly overridden here.
  Future<Response<dynamic>> uploadFile(String path, {required FormData data}) async {
    try {
      return await _dio.post(
        path,
        data: data,
        options: Options(contentType: 'multipart/form-data'),
      );
    } on DioException catch (e) {
      throw apiExceptionFromDio(e);
    }
  }

  /// Exposed so the auth interceptor can retry the original request through
  /// the same configured Dio instance (interceptors, base URL, etc).
  Dio get rawDio => _dio;
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._client);

  final ApiClient _client;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (!_isUnauthenticatedPath(options.path)) {
      final token = await _client.tokenStorage.readAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final requestOptions = err.requestOptions;
    final alreadyRetried = requestOptions.extra['ammctRetried'] == true;

    final shouldAttemptRefresh = err.response?.statusCode == 401 &&
        !_isUnauthenticatedPath(requestOptions.path) &&
        !alreadyRetried;

    if (!shouldAttemptRefresh) {
      handler.next(err);
      return;
    }

    final newAccessToken = await _client.refreshAccessToken();
    if (newAccessToken == null) {
      await _client.onSessionExpired?.call();
      handler.next(err);
      return;
    }

    requestOptions.extra['ammctRetried'] = true;
    requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';

    try {
      final retried = await _client.rawDio.fetch(requestOptions);
      handler.resolve(retried);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }
}
