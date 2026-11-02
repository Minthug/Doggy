import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/community_post_model.dart';
import '../../data/repositories/community_repository.dart';

final selectedPostTypeProvider = StateProvider<PostType?>((ref) => null);

class CommunityFeedState {
  final List<CommunityPost> posts;
  final bool hasMore;
  final bool isLoadingMore;
  final Object? loadMoreError;

  const CommunityFeedState({
    required this.posts,
    required this.hasMore,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  CommunityFeedState copyWith({
    List<CommunityPost>? posts,
    bool? hasMore,
    bool? isLoadingMore,
    Object? loadMoreError,
    bool clearLoadMoreError = false,
  }) {
    return CommunityFeedState(
      posts: posts ?? this.posts,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreError: clearLoadMoreError
          ? null
          : loadMoreError ?? this.loadMoreError,
    );
  }
}

class CommunityPostsNotifier
    extends AutoDisposeAsyncNotifier<CommunityFeedState> {
  static const pageSize = 20;

  int _nextPage = 1;
  int _requestGeneration = 0;

  @override
  Future<CommunityFeedState> build() async {
    final type = ref.watch(selectedPostTypeProvider);
    final generation = ++_requestGeneration;
    _nextPage = 1;

    final posts = await ref
        .read(communityRepositoryProvider)
        .getPosts(type: type, page: 0, size: pageSize);

    if (generation != _requestGeneration) {
      return state.valueOrNull ??
          const CommunityFeedState(posts: [], hasMore: false);
    }
    return CommunityFeedState(posts: posts, hasMore: posts.length == pageSize);
  }

  Future<void> refresh() async {
    final current = state.valueOrNull;
    final generation = ++_requestGeneration;
    final type = ref.read(selectedPostTypeProvider);
    late final List<CommunityPost> posts;
    try {
      posts = await ref
          .read(communityRepositoryProvider)
          .getPosts(type: type, page: 0, size: pageSize);
    } catch (_) {
      if (generation == _requestGeneration && current != null) {
        state = AsyncData(current.copyWith(isLoadingMore: false));
      }
      rethrow;
    }

    if (generation != _requestGeneration ||
        type != ref.read(selectedPostTypeProvider)) {
      return;
    }
    _nextPage = 1;
    state = AsyncData(
      CommunityFeedState(posts: posts, hasMore: posts.length == pageSize),
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) {
      return;
    }

    final generation = _requestGeneration;
    final requestedPage = _nextPage;
    final type = ref.read(selectedPostTypeProvider);
    state = AsyncData(
      current.copyWith(isLoadingMore: true, clearLoadMoreError: true),
    );

    try {
      final nextPosts = await ref
          .read(communityRepositoryProvider)
          .getPosts(type: type, page: requestedPage, size: pageSize);
      if (generation != _requestGeneration ||
          type != ref.read(selectedPostTypeProvider)) {
        return;
      }

      final existingIds = current.posts.map((post) => post.id).toSet();
      final uniqueNextPosts = nextPosts
          .where((post) => existingIds.add(post.id))
          .toList();
      _nextPage = requestedPage + 1;
      state = AsyncData(
        CommunityFeedState(
          posts: [...current.posts, ...uniqueNextPosts],
          hasMore: nextPosts.length == pageSize,
        ),
      );
    } catch (error) {
      if (generation != _requestGeneration) return;
      state = AsyncData(
        current.copyWith(isLoadingMore: false, loadMoreError: error),
      );
    }
  }
}

final communityPostsProvider =
    AsyncNotifierProvider.autoDispose<
      CommunityPostsNotifier,
      CommunityFeedState
    >(CommunityPostsNotifier.new);
