import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../models/user_profile_model.dart';

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepository(ref.watch(dioProvider));
});

class HomeRepository {
  final Dio _dio;

  HomeRepository(this._dio);

  Future<UserProfile> getMyProfile() async {
    final response = await _dio.get('/api/users/me');
    return UserProfile.fromJson(response.data);
  }

  Future<Map<String, dynamic>> getWalkIndex({double? lat, double? lng}) async {
    final response = await _dio.get(
      '/api/weather/walk-index',
      queryParameters: (lat != null && lng != null)
          ? {'lat': lat, 'lng': lng}
          : null,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getWalkForecast({double? lat, double? lng}) async {
    final response = await _dio.get(
      '/api/weather/walk-forecast',
      queryParameters: (lat != null && lng != null)
          ? {'lat': lat, 'lng': lng}
          : null,
    );
    return (response.data['slots'] as List);
  }
}
