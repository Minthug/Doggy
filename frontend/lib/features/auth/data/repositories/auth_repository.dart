import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/storage/token_storage.dart';
import '../models/auth_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(dioProvider));
});

class AuthRepository {
  final Dio _dio;

  AuthRepository(this._dio);

  Future<TokenResponse> signUp({
    required String email,
    required String password,
    required String nickname,
    String? phone,
    String? address,
    String? birthDate,
  }) async {
    final data = <String, dynamic>{
      'email': email,
      'password': password,
      'nickname': nickname,
    };
    if (phone != null && phone.isNotEmpty) data['phone'] = phone;
    if (address != null && address.isNotEmpty) data['address'] = address;
    if (birthDate != null) data['birthDate'] = birthDate;

    final response = await _dio.post('/api/auth/signup', data: data);
    return TokenResponse.fromJson(response.data);
  }

  Future<TokenResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post(
      '/api/auth/login',
      data: {'email': email, 'password': password},
    );
    return TokenResponse.fromJson(response.data);
  }

  Future<void> saveTokens(TokenResponse tokens) async {
    await TokenStorage.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
  }

  Future<bool> hasToken() async {
    final token = await TokenStorage.getAccessToken();
    return token != null;
  }

  Future<void> logout() async {
    final refreshToken = await TokenStorage.getRefreshToken();
    try {
      if (refreshToken != null) {
        await _dio.post(
          '/api/auth/logout',
          options: Options(headers: {'Refresh-Token': refreshToken}),
        );
      }
    } finally {
      await TokenStorage.clear();
    }
  }
}
