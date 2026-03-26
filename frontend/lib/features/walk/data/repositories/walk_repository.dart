import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../models/walk_model.dart';

final walkRepositoryProvider = Provider<WalkRepository>((ref) {
  return WalkRepository(ref.watch(dioProvider));
});

class WalkRepository {
  final Dio _dio;

  WalkRepository(this._dio);

  Future<List<WalkSession>> getHistory({int page = 0, int size = 20}) async {
    final response = await _dio.get('/api/walks', queryParameters: {
      'page': page,
      'size': size,
    });
    return (response.data as List).map((e) => WalkSession.fromJson(e)).toList();
  }
}
