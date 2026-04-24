import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/walk_model.dart';
import '../../data/repositories/walk_repository.dart';

final _walkDetailProvider =
    FutureProvider.family<WalkDetail, int>((ref, sessionId) {
  return ref.watch(walkRepositoryProvider).getDetail(sessionId);
});

final _walkMeetsProvider =
    FutureProvider.family<List<WalkMeet>, int>((ref, sessionId) {
  return ref.watch(walkRepositoryProvider).getMeets(sessionId);
});

class WalkDetailScreen extends ConsumerWidget {
  final int sessionId;

  const WalkDetailScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(_walkDetailProvider(sessionId));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('산책 상세',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton.icon(
            onPressed: () => _showPublishDialog(context, ref),
            icon: const Icon(Icons.share_outlined, size: 18),
            label: const Text('공개'),
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF4CAF50)),
          ),
        ],
      ),
      body: detailAsync.when(
        data: (detail) => _DetailBody(detail: detail, sessionId: sessionId),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('불러오기 실패')),
      ),
    );
  }

  void _showPublishDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('경로 공개하기'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(
            hintText: '예) 한강 야경 코스, 북한산 둘레길',
            labelText: '경로 제목',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white),
            onPressed: () async {
              if (titleController.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              try {
                await ref
                    .read(walkRepositoryProvider)
                    .publish(sessionId, titleController.text.trim());
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('경로가 공개됐습니다')),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('공개에 실패했습니다')),
                  );
                }
              }
            },
            child: const Text('공개하기'),
          ),
        ],
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  final WalkDetail detail;
  final int sessionId;

  const _DetailBody({required this.detail, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meetsAsync = ref.watch(_walkMeetsProvider(sessionId));
    final date = detail.startedAt != null
        ? DateTime.parse(detail.startedAt!)
        : null;
    final dateText = date != null
        ? '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
        : '-';

    return Column(
      children: [
        // 지도 (경로 표시)
        SizedBox(
          height: 300,
          child: _RouteMap(geoJson: detail.routeGeoJson),
        ),

        // 통계
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateText,
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 16),

                // 통계 카드
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatItem(
                          icon: Icons.straighten,
                          label: '거리',
                          value: detail.distanceText),
                      _divider(),
                      _StatItem(
                          icon: Icons.timer,
                          label: '시간',
                          value: detail.durationText),
                      _divider(),
                      _StatItem(
                          icon: Icons.speed,
                          label: '평균속도',
                          value: _avgSpeed(
                              detail.distanceMeters,
                              detail.durationSeconds)),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 만난 강아지들
                const Text(
                  '이번 산책에서 만난 강아지들',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                meetsAsync.when(
                  data: (meets) => meets.isEmpty
                      ? const _EmptyMeets()
                      : Column(
                          children: meets
                              .map((m) => _MeetCard(meet: m))
                              .toList(),
                        ),
                  loading: () => const Center(
                      child: CircularProgressIndicator()),
                  error: (_, _e) => const _EmptyMeets(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _avgSpeed(int distanceMeters, int durationSeconds) {
    if (durationSeconds == 0) return '-';
    final kmPerHour = (distanceMeters / 1000) / (durationSeconds / 3600);
    return '${kmPerHour.toStringAsFixed(1)}km/h';
  }

  Widget _divider() =>
      Container(height: 48, width: 1, color: const Color(0xFFEEEEEE));
}

// 경로 지도
class _RouteMap extends StatefulWidget {
  final String? geoJson;

  const _RouteMap({this.geoJson});

  @override
  State<_RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<_RouteMap> {
  NaverMapController? _controller;

  @override
  void dispose() {
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NaverMap(
      options: const NaverMapViewOptions(
        scrollGesturesEnable: false,
        zoomGesturesEnable: true,
      ),
      onMapReady: (controller) {
        _controller = controller;
        _drawRoute();
      },
    );
  }

  Future<void> _drawRoute() async {
    if (widget.geoJson == null || _controller == null) return;

    try {
      final geoJson = jsonDecode(widget.geoJson!);
      final coordinates =
          geoJson['coordinates'] as List<dynamic>?;

      if (coordinates == null || coordinates.isEmpty) return;

      final coords = coordinates
          .map((c) => NLatLng(
                (c[1] as num).toDouble(),
                (c[0] as num).toDouble(),
              ))
          .toList();

      // 경로 폴리라인
      _controller!.addOverlay(NPolylineOverlay(
        id: 'route',
        coords: coords,
        color: const Color(0xFF4CAF50),
        width: 5,
      ));

      // 시작 마커
      _controller!.addOverlay(NMarker(
        id: 'start',
        position: coords.first,
        caption: const NOverlayCaption(text: '시작'),
      ));

      // 종료 마커
      _controller!.addOverlay(NMarker(
        id: 'end',
        position: coords.last,
        caption: const NOverlayCaption(text: '종료'),
      ));

      // 경로 전체가 보이도록 카메라 조정
      if (!mounted || _controller == null) return;
      await _controller!.updateCamera(
        NCameraUpdate.fitBounds(
          NLatLngBounds(
            southWest: NLatLng(
              coords.map((c) => c.latitude).reduce((a, b) => a < b ? a : b),
              coords.map((c) => c.longitude).reduce((a, b) => a < b ? a : b),
            ),
            northEast: NLatLng(
              coords.map((c) => c.latitude).reduce((a, b) => a > b ? a : b),
              coords.map((c) => c.longitude).reduce((a, b) => a > b ? a : b),
            ),
          ),
          padding: const EdgeInsets.all(40),
        ),
      );
    } catch (e) {
      // GeoJSON 파싱 실패 시 무시
    }
  }
}

class _EmptyMeets extends StatelessWidget {
  const _EmptyMeets();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
        ],
      ),
      child: const Column(
        children: [
          Text('🐾', style: TextStyle(fontSize: 28)),
          SizedBox(height: 8),
          Text('만난 강아지가 없어요',
              style: TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }
}

class _MeetCard extends StatelessWidget {
  final WalkMeet meet;

  const _MeetCard({required this.meet});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          // 프로필 이미지
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFFE8F5E9),
            backgroundImage: meet.user.profileImage != null
                ? NetworkImage(meet.user.profileImage!)
                : null,
            child: meet.user.profileImage == null
                ? const Text('🐶', style: TextStyle(fontSize: 20))
                : null,
          ),
          const SizedBox(width: 12),

          // 유저/강아지 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(meet.user.nickname,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                if (meet.dogs.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: meet.dogs.map((dog) {
                      final label = dog.breed != null
                          ? '${dog.name} · ${dog.breed}'
                          : dog.name;
                      return Text(label,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 13));
                    }).toList(),
                  ),
                if (meet.dogs.any((d) => d.warnings.isNotEmpty))
                  const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  children: meet.dogs
                      .expand((d) => d.warnings)
                      .toSet()
                      .map((w) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('⚠️ ${_warningLabel(w)}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFE65100))),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _warningLabel(String warning) => switch (warning) {
        'AGGRESSIVE' => '사나움',
        'BITING' => '물림 주의',
        'JUMPING' => '달려듦',
        'ESCAPING' => '도주 주의',
        'BARKING' => '짖음 주의',
        _ => warning,
      };
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF4CAF50), size: 20),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4CAF50))),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}
