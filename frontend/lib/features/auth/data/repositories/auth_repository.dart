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
    final response = await _dio.post('/api/auth/signup', data: {
      'email': email,
      'password': password,
      'nickname': nickname,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (address != null && address.isNotEmpty) 'address': address,
      if (birthDate != null) 'birthDate': birthDate,
    });
    return TokenResponse.fromJson(response.data);
  }

  Future<TokenResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post('/api/auth/login', data: {
      'email': email,
      'password': password,
    });
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

  Future<void> logout() => TokenStorage.clear();
}
