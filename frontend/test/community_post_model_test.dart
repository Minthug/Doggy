import 'package:flutter_test/flutter_test.dart';
import 'package:doggy/features/community/data/models/community_post_model.dart';

void main() {
  Map<String, dynamic> postJson({Object? imageUrls}) => {
    'id': 1,
    'userId': 2,
    'nickname': '테스터',
    'type': 'LOST',
    'title': '게시글 제목',
    'content': '게시글 내용',
    if (imageUrls != null) 'imageUrls': imageUrls,
    'status': 'OPEN',
    'createdAt': '2026-10-27T12:00:00',
  };

  test('커뮤니티 게시글의 첨부 사진 순서를 유지한다', () {
    final post = CommunityPost.fromJson(
      postJson(imageUrls: ['/images/first.jpg', '/images/second.jpg']),
    );

    expect(post.imageUrls, ['/images/first.jpg', '/images/second.jpg']);
  });

  test('기존 게시글 응답에 사진 필드가 없어도 빈 목록으로 처리한다', () {
    final post = CommunityPost.fromJson(postJson());

    expect(post.imageUrls, isEmpty);
  });
}
