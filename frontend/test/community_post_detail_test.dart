import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doggy/features/community/data/models/community_post_model.dart';
import 'package:doggy/features/community/data/repositories/community_repository.dart';
import 'package:doggy/features/community/presentation/screens/post_detail_screen.dart';
import 'package:doggy/features/home/data/models/user_profile_model.dart';
import 'package:doggy/features/home/domain/providers/home_provider.dart';

void main() {
  testWidgets('상세 조회 네트워크 오류를 구분하고 재시도한다', (tester) async {
    final repository = _RetryRepository(
      DioException(
        requestOptions: RequestOptions(path: '/api/community/1'),
        type: DioExceptionType.connectionError,
      ),
    );

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.textContaining('네트워크 상태'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);

    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();

    expect(repository.calls, 2);
    expect(find.text('테스트 게시글'), findsOneWidget);
  });

  testWidgets('상세 조회 404는 삭제되었거나 없는 글로 안내한다', (tester) async {
    final request = RequestOptions(path: '/api/community/404');
    final repository = _AlwaysFailRepository(
      DioException(
        requestOptions: request,
        response: Response(requestOptions: request, statusCode: 404),
        type: DioExceptionType.badResponse,
      ),
    );

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.textContaining('삭제되었거나'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
  });

  testWidgets('상세 조회 500은 서버 오류로 안내한다', (tester) async {
    final request = RequestOptions(path: '/api/community/1');
    final repository = _AlwaysFailRepository(
      DioException(
        requestOptions: request,
        response: Response(requestOptions: request, statusCode: 500),
        type: DioExceptionType.badResponse,
      ),
    );

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.textContaining('서버에서 문제'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
  });
}

Widget _app(CommunityRepository repository) {
  return ProviderScope(
    overrides: [
      communityRepositoryProvider.overrideWithValue(repository),
      userProfileProvider.overrideWith(
        (ref) async => UserProfile(id: 99, nickname: 'tester'),
      ),
    ],
    child: const MaterialApp(home: PostDetailScreen(postId: 1)),
  );
}

class _AlwaysFailRepository extends CommunityRepository {
  _AlwaysFailRepository(this.error) : super(Dio());

  final DioException error;

  @override
  Future<CommunityPost> getPost(int postId) => Future.error(error);
}

class _RetryRepository extends CommunityRepository {
  _RetryRepository(this.error) : super(Dio());

  final DioException error;
  int calls = 0;

  @override
  Future<CommunityPost> getPost(int postId) async {
    calls++;
    if (calls == 1) throw error;
    return CommunityPost(
      id: 1,
      userId: 1,
      nickname: 'tester',
      type: PostType.ADOPTION,
      title: '테스트 게시글',
      content: '상세 내용',
      status: PostStatus.OPEN,
      createdAt: DateTime(2026, 10, 28),
    );
  }
}
