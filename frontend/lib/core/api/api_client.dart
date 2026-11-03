import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/app_metadata.dart';
import 'api_config.dart';
import '../storage/device_id_storage.dart';
import '../storage/token_storage.dart';
import '../../main.dart' show navigatorKey;

Future<String>? _refreshInFlight;

final dioProvider = Provider<Dio>((ref) {
  final baseUrl = validatedApiBaseUrl();
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  // TODO(debug): 응답 시간 측정 — 필요없으면 이 블록 전체 삭제
  if (kDebugMode) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.extra['_startTime'] = DateTime.now().millisecondsSinceEpoch;
          handler.next(options);
        },
        onResponse: (response, handler) {
          final start = response.requestOptions.extra['_startTime'] as int?;
          if (start != null) {
            final ms = DateTime.now().millisecondsSinceEpoch - start;
            debugPrint(
              '[API] ${response.requestOptions.method} '
              '${response.requestOptions.path} → ${response.statusCode} (${ms}ms)',
            );
          }
          handler.next(response);
        },
        onError: (error, handler) {
          final start = error.requestOptions.extra['_startTime'] as int?;
          if (start != null) {
            final ms = DateTime.now().millisecondsSinceEpoch - start;
            debugPrint(
              '[API] ${error.requestOptions.method} '
              '${error.requestOptions.path} → ERROR (${ms}ms)',
            );
          }
          handler.next(error);
        },
      ),
    );
  }

  // 요청마다 저장된 토큰을 자동으로 헤더에 붙임
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        options.headers.addAll(AppMetadata.headers());
        options.headers['X-Device-Id'] =
            await DeviceIdStorage.getOrCreateDeviceId();
        final token = await TokenStorage.getAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        // 에러 응답 body 로그 출력 (디버깅용)
        if (kDebugMode && error.response != null) {
          // ignore: avoid_print
          print(
            '[API ERROR] ${error.response?.statusCode} '
            '${error.requestOptions.path}\n'
            'body: ${error.response?.data}',
          );
        }
        if (error.response?.statusCode == 401 &&
            !error.requestOptions.path.startsWith('/api/auth/') &&
            error.requestOptions.extra['_retriedAfterRefresh'] == true) {
          await _clearSessionAndOpenLogin();
          return handler.next(error);
        }
        // 인증 요청과 이미 재시도한 요청은 토큰을 재발급하지 않는다.
        if (shouldRefreshToken(error)) {
          try {
            final storedAccessToken = await TokenStorage.getAccessToken();
            final failedAuthorization = error
                .requestOptions
                .headers['Authorization']
                ?.toString();
            final newAccessToken =
                storedAccessToken != null &&
                    failedAuthorization != null &&
                    failedAuthorization != 'Bearer $storedAccessToken'
                ? storedAccessToken
                : await _refreshAccessToken(baseUrl);
            error.requestOptions.headers['Authorization'] =
                'Bearer $newAccessToken';
            error.requestOptions.extra['_retriedAfterRefresh'] = true;
            final retryResponse = await dio.fetch(error.requestOptions);
            return handler.resolve(retryResponse);
          } catch (refreshError) {
            if (refreshError is _MissingRefreshToken ||
                (refreshError is DioException &&
                    (refreshError.response?.statusCode == 401 ||
                        refreshError.response?.statusCode == 403))) {
              await _clearSessionAndOpenLogin();
              return handler.next(error);
            }
            if (error.requestOptions.extra['_retriedAfterRefresh'] == true) {
              return handler.next(
                refreshError is DioException ? refreshError : error,
              );
            }
            return handler.next(
              refreshError is DioException ? refreshError : error,
            );
          }
        }
        handler.next(error);
      },
    ),
  );

  return dio;
});

bool shouldRefreshToken(DioException error) =>
    error.response?.statusCode == 401 &&
    !error.requestOptions.path.startsWith('/api/auth/') &&
    error.requestOptions.extra['_retriedAfterRefresh'] != true;

Future<String> _refreshAccessToken(String baseUrl) {
  final inFlight = _refreshInFlight;
  if (inFlight != null) return inFlight;

  late final Future<String> shared;
  shared = _performTokenRefresh(baseUrl).then(
    (accessToken) {
      if (identical(_refreshInFlight, shared)) _refreshInFlight = null;
      return accessToken;
    },
    onError: (Object error, StackTrace stackTrace) {
      if (identical(_refreshInFlight, shared)) _refreshInFlight = null;
      Error.throwWithStackTrace(error, stackTrace);
    },
  );
  _refreshInFlight = shared;
  return shared;
}

Future<String> _performTokenRefresh(String baseUrl) async {
  final refreshToken = await TokenStorage.getRefreshToken();
  if (refreshToken == null) throw const _MissingRefreshToken();

  final deviceId = await DeviceIdStorage.getOrCreateDeviceId();
  final response =
      await Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 20),
        ),
      ).post(
        '$baseUrl/api/auth/refresh',
        options: Options(
          headers: {
            'Refresh-Token': refreshToken,
            'X-Device-Id': deviceId,
            ...AppMetadata.headers(),
          },
        ),
      );
  final newAccessToken = response.data['accessToken'];
  final newRefreshToken = response.data['refreshToken'];
  if (newAccessToken is! String || newRefreshToken is! String) {
    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
      error: 'Invalid token refresh response',
    );
  }
  await TokenStorage.saveTokens(
    accessToken: newAccessToken,
    refreshToken: newRefreshToken,
  );
  return newAccessToken;
}

class _MissingRefreshToken implements Exception {
  const _MissingRefreshToken();
}

Future<bool> hasValidSession(Dio dio) async {
  if (await TokenStorage.getAccessToken() == null) return false;
  try {
    await dio.get('/api/users/me');
    return true;
  } on DioException catch (error) {
    return error.response?.statusCode != 401;
  }
}

Future<void> _clearSessionAndOpenLogin() async {
  await TokenStorage.clear();
  navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (_) => false);
}

final imageUploadProvider = Provider<ImageUploadClient>((ref) {
  return ImageUploadClient(ref.watch(dioProvider));
});

class ImageUploadClient {
  final Dio _dio;
  ImageUploadClient(this._dio);

  Future<String> upload(File file) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/images/upload',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return response.data!['url'] as String;
  }
}
