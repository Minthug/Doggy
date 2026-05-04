import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../home/domain/providers/home_provider.dart';
import '../../data/models/community_post_model.dart';
import '../../data/repositories/community_repository.dart';
import 'create_post_screen.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  final int postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  CommunityPost? _post;
  List<CommunityPost> _sightings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(communityRepositoryProvider);
      final post = await repo.getPost(widget.postId);
      List<CommunityPost> sightings = [];
      if (post.type == PostType.LOST) {
        sightings = await repo.getSightings(widget.postId);
      }
      if (mounted) setState(() { _post = post; _sightings = sightings; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resolve() async {
    try {
      final post = await ref.read(communityRepositoryProvider).resolve(widget.postId);
      if (mounted) setState(() => _post = post);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('실패: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('게시글 삭제'),
        content: const Text('삭제하면 복구할 수 없습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(communityRepositoryProvider).delete(widget.postId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_post == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('게시글을 찾을 수 없습니다')),
      );
    }

    final post = _post!;
    final myId = ref.watch(userProfileProvider).valueOrNull?.id;
    final isMyPost = myId != null && myId == post.userId;
    final isResolved = post.status == PostStatus.RESOLVED;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: Row(
          children: [
            _TypeBadge(type: post.type),
            if (isResolved) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('해결완료',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            ],
          ],
        ),
        actions: [
          if (isMyPost)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'resolve') _resolve();
                if (v == 'delete') _delete();
              },
              itemBuilder: (_) => [
                if (!isResolved)
                  const PopupMenuItem(value: 'resolve', child: Text('해결완료 처리')),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('삭제', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(post.title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                  child: Text(
                    post.nickname.isNotEmpty ? post.nickname[0] : '?',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF4CAF50)),
                  ),
                ),
                const SizedBox(width: 8),
                Text(post.nickname,
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                const SizedBox(width: 8),
                Text(_timeAgo(post.createdAt),
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),
            Text(post.content, style: const TextStyle(fontSize: 15, height: 1.6)),
            if (post.dogName != null || post.lastSeenArea != null ||
                post.lastSeenAt != null || post.contactInfo != null) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              const Text('상세 정보',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 12),
              if (post.dogName != null)
                _InfoRow(icon: Icons.pets, label: '이름', value: post.dogName!),
              if (post.breed != null)
                _InfoRow(icon: Icons.info_outline, label: '견종', value: post.breed!),
              if (post.lastSeenAt != null)
                _InfoRow(
                    icon: Icons.access_time,
                    label: '시간',
                    value: _formatDateTime(post.lastSeenAt!)),
              if (post.lastSeenArea != null)
                _InfoRow(
                    icon: Icons.location_on_outlined,
                    label: '장소',
                    value: post.lastSeenArea!),
              if (post.contactInfo != null)
                _InfoRow(
                    icon: Icons.phone_outlined,
                    label: '연락처',
                    value: post.contactInfo!),
            ],
            // 목격 제보 목록 (실종 게시글에만)
            if (post.type == PostType.LOST) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    '목격 제보 ${_sightings.length}건',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreatePostScreen(relatedLostPost: post),
                      ),
                    ).then((_) => _load()),
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text('목격 신고'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.orange,
                      backgroundColor: Colors.orange.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_sightings.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    children: [
                      Text('👀', style: TextStyle(fontSize: 28)),
                      SizedBox(height: 6),
                      Text('아직 목격 제보가 없어요',
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                )
              else
                ..._sightings.map((s) => _SightingCard(
                      sighting: s,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => PostDetailScreen(postId: s.id)),
                      ).then((_) => _load()),
                    )),
            ],

            // 지도 (lat/lng 있을 때만)
            if (post.lat != null && post.lng != null) ...[
              const SizedBox(height: 20),
              const Text('마지막 목격 위치',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 220,
                  child: NaverMap(
                    options: NaverMapViewOptions(
                      initialCameraPosition: NCameraPosition(
                        target: NLatLng(post.lat!, post.lng!),
                        zoom: 15,
                      ),
                      scrollGesturesEnable: false,
                      zoomGesturesEnable: false,
                      tiltGesturesEnable: false,
                      rotationGesturesEnable: false,
                      locationButtonEnable: false,
                    ),
                    onMapReady: (ctrl) {
                      ctrl.addOverlay(NMarker(
                        id: 'location',
                        position: NLatLng(post.lat!, post.lng!),
                      ));
                    },
                  ),
                ),
              ),
            ],
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
    return '${dt.year}.${dt.month}.${dt.day}';
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}'
        ' ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _SightingCard extends StatelessWidget {
  final CommunityPost sighting;
  final VoidCallback onTap;
  const _SightingCard({required this.sighting, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('👀', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(sighting.nickname,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      const Spacer(),
                      if (sighting.lastSeenAt != null)
                        Text(
                          _fmt(sighting.lastSeenAt!),
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(sighting.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: Colors.black87)),
                  if (sighting.lastSeenArea != null) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.location_on_outlined,
                          size: 12, color: Colors.grey),
                      const SizedBox(width: 2),
                      Text(sighting.lastSeenArea!,
                          style:
                              const TextStyle(fontSize: 11, color: Colors.grey)),
                    ]),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _TypeBadge extends StatelessWidget {
  final PostType type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (type) {
      case PostType.LOST:    color = Colors.red; break;
      case PostType.FOUND:   color = Colors.orange; break;
      case PostType.GENERAL: color = const Color(0xFF4CAF50); break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(type.label,
          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label  ', style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
