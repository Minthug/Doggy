import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/token_storage.dart';

const _baseUrl = 'https://doggy-production-6c3f.up.railway.app';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Content-Type': 'application/json'},
  ));

  // 요청마다 저장된 토큰을 자동으로 헤더에 붙임
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
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
        print('[API ERROR] ${error.response?.statusCode} '
            '${error.requestOptions.path}\n'
            'body: ${error.response?.data}');
      }
      // 401이면 refreshToken으로 재발급 시도
      if (error.response?.statusCode == 401) {
        final refreshToken = await TokenStorage.getRefreshToken();
        if (refreshToken != null) {
          try {
            final response = await Dio().post(
              '$_baseUrl/api/auth/refresh',
              options: Options(headers: {'Refresh-Token': refreshToken}),
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
  ));

  return dio;
});
