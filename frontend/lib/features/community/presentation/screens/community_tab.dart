import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/community_post_model.dart';
import '../../domain/providers/community_provider.dart';
import 'create_post_screen.dart';
import 'post_detail_screen.dart';

class CommunityTab extends ConsumerWidget {
  const CommunityTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                data: (posts) => ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: posts.isEmpty ? 2 : posts.length + 1,
                  itemBuilder: (ctx, i) {
                    if (i == 0) return const _PromoBanner();
                    if (posts.isEmpty) return const _EmptyView();
                    final post = posts[i - 1];
                    return _PostCard(
                      post: post,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PostDetailScreen(postId: post.id),
                        ),
                      ).then((_) => ref.invalidate(communityPostsProvider)),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'community-create-post',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreatePostScreen()),
        ).then((_) => ref.invalidate(communityPostsProvider)),
        backgroundColor: const Color(0xFF4CAF50),
        child: const Icon(Icons.edit, color: Colors.white),
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: '전체',
                  selected: selectedType == null,
                  onTap: () =>
                      ref.read(selectedPostTypeProvider.notifier).state = null,
                ),
                const SizedBox(width: 8),
                ...PostType.values.map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(
                      label: '${_typeIcon(t)} ${t.label}',
                      selected: selectedType == t,
                      onTap: () =>
                          ref.read(selectedPostTypeProvider.notifier).state = t,
                      color: _typeColor(t),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _typeIcon(PostType t) {
    switch (t) {
      case PostType.LOST:
        return '🚨';
      case PostType.FOUND:
        return '👀';
      case PostType.ADOPTION:
        return '🏠';
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : Colors.grey[300]!),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? Colors.white : Colors.black87,
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
                CircleAvatar(
                  radius: 10,
                  backgroundColor: const Color(
                    0xFF4CAF50,
                  ).withValues(alpha: 0.2),
                  child: Text(
                    post.nickname.isNotEmpty ? post.nickname[0] : '?',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                ),
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
  const _EmptyView();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🐾', style: TextStyle(fontSize: 48)),
          SizedBox(height: 12),
          Text('아직 게시글이 없어요', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

// 커뮤니티 상단 배너 광고
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
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _banners.length,
            separatorBuilder: (_, index) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final b = _banners[i];
              return GestureDetector(
                onTap: () => _open(b.query),
                child: Container(
                  width: 220,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: b.color,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Text(b.emoji, style: const TextStyle(fontSize: 30)),
                      const SizedBox(width: 12),
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
