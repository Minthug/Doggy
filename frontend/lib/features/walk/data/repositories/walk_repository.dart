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

  Future<WalkSession> start() async {
    final response = await _dio.post('/api/walks');
    return WalkSession.fromJson(response.data);
  }

  Future<WalkSession> pause(int sessionId) async {
    final response = await _dio.patch('/api/walks/$sessionId/pause');
    return WalkSession.fromJson(response.data);
  }

  Future<WalkSession> resume(int sessionId) async {
    final response = await _dio.patch('/api/walks/$sessionId/resume');
    return WalkSession.fromJson(response.data);
  }

  Future<void> complete({
    required int sessionId,
    required List<Map<String, dynamic>> points,
  }) async {
    await _dio.post('/api/walks/$sessionId/complete', data: {
      'points': points,
    });
  }

  Future<List<WalkSession>> getHistory({int page = 0, int size = 20}) async {
    final response = await _dio.get('/api/walks', queryParameters: {
      'page': page,
      'size': size,
    });
    return (response.data as List).map((e) => WalkSession.fromJson(e)).toList();
  }

  Future<WalkDetail> getDetail(int sessionId) async {
    final response = await _dio.get('/api/walks/$sessionId');
    return WalkDetail.fromJson(response.data);
  }
}
