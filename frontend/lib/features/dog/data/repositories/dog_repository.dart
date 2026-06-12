import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../models/dog_model.dart';

final dogRepositoryProvider = Provider<DogRepository>((ref) {
  return DogRepository(ref.watch(dioProvider));
});

class DogRepository {
  final Dio _dio;

  DogRepository(this._dio);

  Future<List<Dog>> getMyDogs() async {
    final response = await _dio.get('/api/dogs');
    return (response.data as List).map((e) => Dog.fromJson(e)).toList();
  }

  Future<Dog> create({
    required String name,
    String? breed,
    String? birthDate,
    double? weightKg,
    required String gender,
    required bool isNeutered,
    List<String> warnings = const [],
    String? profileImage,
  }) async {
    final response = await _dio.post('/api/dogs', data: {
      'name': name,
      'breed': breed?.isNotEmpty == true ? breed : null,
      'birthDate': birthDate,
      'weightKg': weightKg,
      'gender': gender,
      'isNeutered': isNeutered,
      'warnings': warnings,
      'profileImage': profileImage,
    });
    return Dog.fromJson(response.data);
  }

  Future<Dog> update({
    required int dogId,
    required String name,
    String? breed,
    String? birthDate,
    double? weightKg,
    required String gender,
    required bool isNeutered,
    List<String> warnings = const [],
    String? profileImage,
  }) async {
    final response = await _dio.patch('/api/dogs/$dogId', data: {
      'name': name,
      'breed': breed?.isNotEmpty == true ? breed : null,
      'birthDate': birthDate,
      'weightKg': weightKg,
      'gender': gender,
      'isNeutered': isNeutered,
      'warnings': warnings,
      'profileImage': profileImage,
    });
    return Dog.fromJson(response.data);
  }

  Future<void> delete(int dogId) async {
    await _dio.delete('/api/dogs/$dogId');
  }

  Future<void> toggleFavorite(int dogId) async {
    await _dio.post('/api/dogs/$dogId/favorite');
  }
}
