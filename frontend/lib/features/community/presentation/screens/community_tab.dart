import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/community_post_model.dart';
import '../../domain/providers/community_provider.dart';
import 'create_post_screen.dart';
import 'post_detail_screen.dart';

class CommunityTab extends ConsumerStatefulWidget {
  const CommunityTab({super.key});

  @override
  ConsumerState<CommunityTab> createState() => _CommunityTabState();
}

class _CommunityTabState extends ConsumerState<CommunityTab> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.extentAfter < 400) {
      ref.read(communityPostsProvider.notifier).loadMore();
    }
  }

  Future<void> _refresh() async {
    try {
      await ref.read(communityPostsProvider.notifier).refresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('새로고침하지 못했어요. 잠시 후 다시 시도해 주세요.')),
      );
    }
  }

  Future<void> _openCreate(PostType? initialType) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreatePostScreen(initialType: initialType),
      ),
    );
    if (mounted) {
      await ref.read(communityPostsProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedType = ref.watch(selectedPostTypeProvider);
    final postsAsync = ref.watch(communityPostsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: SafeArea(
        child: Column(
          children: [
            _Header(selectedType: selectedType),
            Expanded(
              child: postsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _CommunityErrorView(
                  error: e,
                  onRetry: () => ref.invalidate(communityPostsProvider),
                ),
                data: (feed) => RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: _itemCount(feed),
                    itemBuilder: (ctx, i) {
                      if (feed.posts.isEmpty) {
                        return _EmptyView(
                          onCreate: () => _openCreate(selectedType),
                        );
                      }
                      final showPromo = feed.posts.length >= 3;
                      if (showPromo && i == 3) {
                        return const _PromoBanner();
                      }
                      final postIndex = showPromo && i > 3 ? i - 1 : i;
                      if (postIndex >= feed.posts.length) {
                        return _LoadMoreFooter(
                          isLoading: feed.isLoadingMore,
                          hasError: feed.loadMoreError != null,
                          onRetry: () => ref
                              .read(communityPostsProvider.notifier)
                              .loadMore(),
                        );
                      }
                      final post = feed.posts[postIndex];
                      return _PostCard(
                        post: post,
                        onTap: () =>
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    PostDetailScreen(postId: post.id),
                              ),
                            ).then(
                              (_) => ref
                                  .read(communityPostsProvider.notifier)
                                  .refresh(),
                            ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: postsAsync.valueOrNull?.posts.isNotEmpty == true
          ? FloatingActionButton(
              heroTag: 'community-create-post',
              onPressed: () => _openCreate(selectedType),
              backgroundColor: const Color(0xFF4CAF50),
              child: const Icon(Icons.edit, color: Colors.white),
            )
          : null,
    );
  }

  int _itemCount(CommunityFeedState feed) {
    if (feed.posts.isEmpty) return 1;
    final promoCount = feed.posts.length >= 3 ? 1 : 0;
    final hasFooter = feed.isLoadingMore || feed.loadMoreError != null;
    return feed.posts.length + promoCount + (hasFooter ? 1 : 0);
  }
}

class _LoadMoreFooter extends StatelessWidget {
  final bool isLoading;
  final bool hasError;
  final VoidCallback onRetry;

  const _LoadMoreFooter({
    required this.isLoading,
    required this.hasError,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(hasError ? '더 불러오기 다시 시도' : '더 불러오기'),
              ),
      ),
    );
  }
}

class _CommunityErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _CommunityErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final message = _messageFor(error);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFF9E9E9E), size: 36),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF616161),
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }

  String _messageFor(Object error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 401) {
        return '로그인이 필요합니다.\n다시 로그인한 뒤 이용해 주세요.';
      }
      if (statusCode != null && statusCode >= 500) {
        return '서버에서 문제가 발생했습니다.\n잠시 후 다시 시도해 주세요.';
      }
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return '서버에 연결하지 못했습니다.\n네트워크 상태를 확인해 주세요.';
      }
    }

    return '커뮤니티를 불러오지 못했습니다.\n잠시 후 다시 시도해 주세요.';
  }
}

class _Header extends ConsumerWidget {
  final PostType? selectedType;
  const _Header({required this.selectedType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '커뮤니티',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _FilterChip(
                  label: '전체',
                  selected: selectedType == null,
                  onTap: () =>
                      ref.read(selectedPostTypeProvider.notifier).state = null,
                ),
              ),
              ...PostType.values.expand(
                (t) => [
                  const SizedBox(width: 4),
                  Expanded(
                    child: _FilterChip(
                      label: _shortTypeLabel(t),
                      selected: selectedType == t,
                      onTap: () =>
                          ref.read(selectedPostTypeProvider.notifier).state = t,
                      color: _typeColor(t),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  String _shortTypeLabel(PostType t) {
    switch (t) {
      case PostType.LOST:
        return '실종';
      case PostType.FOUND:
        return '목격';
      case PostType.ADOPTION:
        return '입양';
      case PostType.FOOD_REVIEW:
        return '사료';
      case PostType.SUPPLY_REVIEW:
        return '용품';
    }
  }

  Color _typeColor(PostType t) {
    switch (t) {
      case PostType.LOST:
        return Colors.red;
      case PostType.FOUND:
        return Colors.orange;
      case PostType.ADOPTION:
        return const Color(0xFF7C4DFF);
      case PostType.FOOD_REVIEW:
        return const Color(0xFF2E7D32);
      case PostType.SUPPLY_REVIEW:
        return const Color(0xFF1565C0);
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = const Color(0xFF4CAF50),
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.45)
                  : Colors.grey[200]!,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              color: selected ? color : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final CommunityPost post;
  final VoidCallback onTap;
  const _PostCard({required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isResolved = post.status == PostStatus.RESOLVED;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isResolved ? Colors.grey[50] : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _TypeBadge(type: post.type),
                const SizedBox(width: 8),
                if (isResolved)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '해결완료',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                const Spacer(),
                Text(
                  _timeAgo(post.createdAt),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              post.title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isResolved ? Colors.grey : Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              post.content,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (post.imageUrls.isNotEmpty) ...[
              const SizedBox(height: 10),
              _PostImagePreview(imageUrls: post.imageUrls),
            ],
            if (post.type.isReview) ...[
              const SizedBox(height: 10),
              _ReviewPreview(post: post),
            ],
            if (post.dogName != null || post.lastSeenArea != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (post.dogName != null)
                    _InfoChip(icon: Icons.pets, text: post.dogName!),
                  if (post.lastSeenArea != null) ...[
                    const SizedBox(width: 6),
                    _InfoChip(
                      icon: Icons.location_on_outlined,
                      text: post.lastSeenArea!,
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                _AuthorAvatar(post: post),
                const SizedBox(width: 6),
                Text(
                  post.nickname,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${dt.month}/${dt.day}';
  }
}

class _PostImagePreview extends StatelessWidget {
  final List<String> imageUrls;

  const _PostImagePreview({required this.imageUrls});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              imageUrls.first,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                color: Colors.grey[100],
                alignment: Alignment.center,
                child: const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.grey,
                ),
              ),
            ),
            if (imageUrls.length > 1)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '+${imageUrls.length - 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  final CommunityPost post;

  const _AuthorAvatar({required this.post});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
      alignment: Alignment.center,
      child: Text(
        post.nickname.isNotEmpty ? post.nickname[0] : '?',
        style: const TextStyle(
          fontSize: 10,
          color: Color(0xFF4CAF50),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    final profileImage = post.profileImage;

    return ClipOval(
      child: SizedBox.square(
        dimension: 24,
        child: profileImage == null || profileImage.isEmpty
            ? fallback
            : Image.network(
                profileImage,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

class _ReviewPreview extends StatelessWidget {
  final CommunityPost post;
  const _ReviewPreview({required this.post});

  @override
  Widget build(BuildContext context) {
    final rating = post.ratingPercent ?? 0;
    final color = _ratingColor(rating);
    final verdict = _ratingVerdict(rating);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 3),
            ),
            child: Center(
              child: Text(
                '$rating%',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '보호자 추천도',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        verdict,
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  post.productName ?? '제품명 없음',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                if (post.reviewSummary != null)
                  Text(
                    post.reviewSummary!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _ratingColor(int rating) {
    if (rating >= 70) return const Color(0xFF2E7D32);
    if (rating >= 45) return const Color(0xFFFF9800);
    return const Color(0xFFD32F2F);
  }

  String _ratingVerdict(int rating) {
    if (rating >= 70) return '추천';
    if (rating >= 45) return '보통';
    return '비추천';
  }
}

class _TypeBadge extends StatelessWidget {
  final PostType type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (type) {
      case PostType.LOST:
        color = Colors.red;
        break;
      case PostType.FOUND:
        color = Colors.orange;
        break;
      case PostType.ADOPTION:
        color = const Color(0xFF7C4DFF);
        break;
      case PostType.FOOD_REVIEW:
        color = const Color(0xFF2E7D32);
        break;
      case PostType.SUPPLY_REVIEW:
        color = const Color(0xFF1565C0);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        type.label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.grey),
        const SizedBox(width: 3),
        Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

class _EmptyView extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyView({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 28),
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF2FAF3), Color(0xFFFFFFFF)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDCEEDD)),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFFE1F2E2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.forum_outlined,
              size: 30,
              color: Color(0xFF388E3C),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            '아직 게시글이 없어요',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            '궁금한 점이나 우리 아이 소식을\n이웃 보호자와 나눠보세요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF6F766F),
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('첫 글 작성하기'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF43A047),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 게시글 사이에 노출하는 소형 쇼핑 배너
class _PromoBanner extends StatelessWidget {
  const _PromoBanner();

  static const _banners = [
    (
      emoji: '🍖',
      title: '이달의 추천 사료',
      subtitle: '수의사가 추천하는 건강 사료 모음',
      color: Color(0xFF4CAF50),
      query: '강아지 사료 추천',
    ),
    (
      emoji: '🦴',
      title: '간식 베스트',
      subtitle: '강아지가 좋아하는 간식 TOP 20',
      color: Color(0xFFFFA726),
      query: '강아지 간식 베스트',
    ),
    (
      emoji: '✂️',
      title: '미용 용품 특가',
      subtitle: '집에서 쉽게 하는 셀프 미용 용품',
      color: Color(0xFF7C4DFF),
      query: '강아지 미용 용품',
    ),
  ];

  Future<void> _open(String query) async {
    final encoded = Uri.encodeComponent(query);
    final uri = Uri.parse(
      'https://search.shopping.naver.com/search/all?query=$encoded',
    );
    if (await canLaunchUrl(uri)) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8, top: 4),
          child: Row(
            children: [
              Text(
                '추천 쇼핑',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(width: 6),
              Text('AD', style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ),
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _banners.length,
            separatorBuilder: (_, index) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final b = _banners[i];
              return GestureDetector(
                onTap: () => _open(b.query),
                child: Container(
                  width: 210,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: b.color,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Text(b.emoji, style: const TextStyle(fontSize: 25)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              b.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              b.subtitle,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: Colors.white54,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
