import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../models/walk_model.dart';

// UTC 포맷: 서버(Railway)가 UTC 기준으로 startedAt을 저장하므로 맞춰야 함
String _formatDateTime(DateTime dt) {
  final utc = dt.toUtc();
  return '${utc.year.toString().padLeft(4, '0')}'
      '-${utc.month.toString().padLeft(2, '0')}'
      '-${utc.day.toString().padLeft(2, '0')}'
      'T${utc.hour.toString().padLeft(2, '0')}'
      ':${utc.minute.toString().padLeft(2, '0')}'
      ':${utc.second.toString().padLeft(2, '0')}';
}

final walkRepositoryProvider = Provider<WalkRepository>((ref) {
  return WalkRepository(ref.watch(dioProvider));
});

class WalkRepository {
  final Dio _dio;

  WalkRepository(this._dio);

  Future<WalkSession> start({List<int> dogIds = const []}) async {
    final response = await _dio.post(
      '/api/walks',
      data: dogIds.isEmpty ? null : {'dogIds': dogIds},
    );
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
    required DateTime endedAt,
  }) async {
    await _dio.post(
      '/api/walks/$sessionId/complete',
      data: {'endedAt': _formatDateTime(endedAt), 'points': points},
      options: Options(receiveTimeout: const Duration(seconds: 30)),
    );
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

  Future<void> publish(int sessionId, String title) async {
    await _dio.patch('/api/walks/$sessionId/publish', data: {'title': title});
  }

  Future<void> unpublish(int sessionId) async {
    await _dio.patch('/api/walks/$sessionId/unpublish');
  }

  Future<List<PublicRoute>> getPublicRoutes({
    int page = 0,
    int size = 20,
    double? lat,
    double? lng,
  }) async {
    final response = await _dio.get('/api/walks/public', queryParameters: {
      'page': page,
      'size': size,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
    });
    return (response.data as List).map((e) => PublicRoute.fromJson(e)).toList();
  }

  Future<void> toggleLike(int sessionId) async {
    await _dio.post('/api/walks/$sessionId/like');
  }

  Future<void> toggleBookmark(int sessionId) async {
    await _dio.post('/api/walks/$sessionId/bookmark');
  }

  Future<void> updateLocation(int sessionId, double lat, double lng) async {
    await _dio.patch('/api/walks/$sessionId/location', data: {
      'lat': lat,
      'lng': lng,
    });
  }

  Future<List<WalkMeet>> getMeets(int sessionId) async {
    final response = await _dio.get('/api/walks/$sessionId/meets');
    return (response.data as List).map((e) => WalkMeet.fromJson(e)).toList();
  }
}
