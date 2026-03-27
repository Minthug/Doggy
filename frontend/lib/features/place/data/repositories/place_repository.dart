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

  Future<List<Place>> findNearby({
    required double lat,
    required double lng,
    double radiusMeters = 2000,
    String? category,
  }) async {
    final response = await _dio.get('/api/places', queryParameters: {
      'lat': lat,
      'lng': lng,
      'radiusMeters': radiusMeters,
      'category': category,
    });
    return (response.data as List).map((e) => Place.fromJson(e)).toList();
  }
}
