import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../models/community_post_model.dart';

final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  return CommunityRepository(ref.watch(dioProvider));
});

class CommunityRepository {
  final Dio _dio;
  CommunityRepository(this._dio);

  Future<List<CommunityPost>> getPosts({PostType? type, int page = 0, int size = 20}) async {
    final response = await _dio.get('/api/community', queryParameters: {
      if (type != null) 'type': type.name,
      'page': page,
      'size': size,
    });
    return (response.data as List).map((e) => CommunityPost.fromJson(e)).toList();
  }

  Future<CommunityPost> getPost(int postId) async {
    final response = await _dio.get('/api/community/$postId');
    return CommunityPost.fromJson(response.data);
  }

  Future<CommunityPost> create({
    required PostType type,
    required String title,
    required String content,
    String? dogName,
    String? breed,
    String? lastSeenArea,
    DateTime? lastSeenAt,
    double? lat,
    double? lng,
    String? contactInfo,
    int? relatedPostId,
  }) async {
    final response = await _dio.post('/api/community', data: {
      'type': type.name,
      'title': title,
      'content': content,
      if (dogName != null) 'dogName': dogName,
      if (breed != null) 'breed': breed,
      if (lastSeenArea != null) 'lastSeenArea': lastSeenArea,
      if (lastSeenAt != null) 'lastSeenAt': lastSeenAt.toUtc().toIso8601String(),
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (contactInfo != null) 'contactInfo': contactInfo,
      if (relatedPostId != null) 'relatedPostId': relatedPostId,
    });
    return CommunityPost.fromJson(response.data);
  }

  Future<List<CommunityPost>> getSightings(int postId) async {
    final response = await _dio.get('/api/community/$postId/sightings');
    return (response.data as List).map((e) => CommunityPost.fromJson(e)).toList();
  }

  Future<CommunityPost> resolve(int postId) async {
    final response = await _dio.patch('/api/community/$postId/resolve');
    return CommunityPost.fromJson(response.data);
  }

  Future<void> delete(int postId) async {
    await _dio.delete('/api/community/$postId');
  }
}
