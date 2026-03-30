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
        data: (detail) => _DetailBody(detail: detail),
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

class _DetailBody extends StatelessWidget {
  final WalkDetail detail;

  const _DetailBody({required this.detail});

  @override
  Widget build(BuildContext context) {
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

  void _drawRoute() {
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
      _controller!.updateCamera(
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
