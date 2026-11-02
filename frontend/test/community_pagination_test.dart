import 'package:dio/dio.dart';
import 'package:doggy/features/community/data/models/community_post_model.dart';
import 'package:doggy/features/community/data/repositories/community_repository.dart';
import 'package:doggy/features/community/domain/providers/community_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('첫 페이지 다음의 게시글을 중복 없이 이어 붙인다', () async {
    final repository = _FakeCommunityRepository();
    repository.pages[0] = List.generate(20, (index) => _post(index + 1));
    repository.pages[1] = [_post(20), _post(21)];
    final container = ProviderContainer(
      overrides: [communityRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      communityPostsProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final firstPage = await container.read(communityPostsProvider.future);
    expect(firstPage.posts, hasLength(20));
    expect(firstPage.hasMore, isTrue);

    await container.read(communityPostsProvider.notifier).loadMore();

    final feed = container.read(communityPostsProvider).requireValue;
    expect(
      feed.posts.map((post) => post.id),
      orderedEquals(List.generate(21, (i) => i + 1)),
    );
    expect(feed.hasMore, isFalse);
    expect(repository.requestedPages, [0, 1]);
  });

  test('새로고침하면 첫 페이지와 다음 페이지 위치를 초기화한다', () async {
    final repository = _FakeCommunityRepository();
    repository.pages[0] = [_post(1)];
    final container = ProviderContainer(
      overrides: [communityRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      communityPostsProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    await container.read(communityPostsProvider.future);
    repository.pages[0] = [_post(100)];

    await container.read(communityPostsProvider.notifier).refresh();

    final feed = container.read(communityPostsProvider).requireValue;
    expect(feed.posts.single.id, 100);
    expect(repository.requestedPages, [0, 0]);
  });
}

class _FakeCommunityRepository extends CommunityRepository {
  _FakeCommunityRepository() : super(Dio());

  final Map<int, List<CommunityPost>> pages = {};
  final List<int> requestedPages = [];

  @override
  Future<List<CommunityPost>> getPosts({
    PostType? type,
    int page = 0,
    int size = 20,
  }) async {
    requestedPages.add(page);
    return pages[page] ?? [];
  }
}

CommunityPost _post(int id) => CommunityPost(
  id: id,
  userId: 1,
  nickname: '테스터',
  type: PostType.LOST,
  title: '게시글 $id',
  content: '내용',
  status: PostStatus.OPEN,
  createdAt: DateTime(2026, 10, 27),
);
