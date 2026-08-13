import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_config.dart';
import '../storage/device_id_storage.dart';
import '../storage/token_storage.dart';

final dioProvider = Provider<Dio>((ref) {
  final baseUrl = validatedApiBaseUrl();
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
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
        if (error.response != null) {
          // ignore: avoid_print
          print(
            '[API ERROR] ${error.response?.statusCode} '
            '${error.requestOptions.path}\n'
            'body: ${error.response?.data}',
          );
        }
        // 401이면 refreshToken으로 재발급 시도
        if (error.response?.statusCode == 401) {
          final refreshToken = await TokenStorage.getRefreshToken();
          if (refreshToken != null) {
            try {
              final deviceId = await DeviceIdStorage.getOrCreateDeviceId();
              final response = await Dio().post(
                '$baseUrl/api/auth/refresh',
                options: Options(
                  headers: {
                    'Refresh-Token': refreshToken,
                    'X-Device-Id': deviceId,
                  },
                ),
              );
              final newAccessToken = response.data['accessToken'];
              final newRefreshToken = response.data['refreshToken'];
              await TokenStorage.saveTokens(
                accessToken: newAccessToken,
                refreshToken: newRefreshToken,
              );
              // 원래 요청 재시도
              error.requestOptions.headers['Authorization'] =
                  'Bearer $newAccessToken';
              final retryResponse = await dio.fetch(error.requestOptions);
              return handler.resolve(retryResponse);
            } catch (_) {
              await TokenStorage.clear();
            }
          }
        }
        handler.next(error);
      },
    ),
  );

  return dio;
});

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
