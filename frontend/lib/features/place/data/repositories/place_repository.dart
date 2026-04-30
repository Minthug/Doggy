import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../models/place_model.dart';

final placeRepositoryProvider = Provider<PlaceRepository>((ref) {
  return PlaceRepository(ref.watch(dioProvider));
});

class PlaceRepository {
  final Dio _dio;

  PlaceRepository(this._dio);

  Future<Place> create({
    required String name,
    required String category,
    required double lat,
    required double lng,
    String? address,
    String? phone,
    bool isOpen24h = false,
    bool isEmergency = false,
    bool allowsDogs = true,
  }) async {
    final response = await _dio.post('/api/places', data: {
      'name': name,
      'category': category,
      'lat': lat,
      'lng': lng,
      'address': address,
      'phone': phone,
      'isOpen24h': isOpen24h,
      'isEmergency': isEmergency,
      'allowsDogs': allowsDogs,
    });
    return Place.fromJson(response.data);
  }

  Future<List<Place>> findNearby({
    required double lat,
    required double lng,
    double radiusMeters = 2000,
    String? category,
  }) async {
    final params = <String, dynamic>{
      'lat': lat,
      'lng': lng,
      'radiusMeters': radiusMeters,
    };
    if (category != null) params['category'] = category;

    final response = await _dio.get(
      '/api/places',
      queryParameters: params,
      options: Options(receiveTimeout: const Duration(seconds: 20)),
    );
    return (response.data as List).map((e) => Place.fromJson(e)).toList();
  }
}
