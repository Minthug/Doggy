import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/walk_model.dart';
import '../../data/repositories/walk_repository.dart';

final _publicRoutesProvider = FutureProvider.autoDispose<List<PublicRoute>>((ref) async {
  return ref.watch(walkRepositoryProvider).getPublicRoutes();
});

class PublicRoutesScreen extends ConsumerWidget {
  const PublicRoutesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routesAsync = ref.watch(_publicRoutesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('인기 산책 경로',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(_publicRoutesProvider.future),
        child: routesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('불러오기 실패')),
          data: (routes) => routes.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 120),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.route, size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('아직 공개된 경로가 없어요',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: routes.length,
                  itemBuilder: (context, index) =>
                      _RouteCard(route: routes[index], ref: ref),
                ),
        ),
      ),
    );
  }
}

class _RouteCard extends StatefulWidget {
  final PublicRoute route;
  final WidgetRef ref;

  const _RouteCard({required this.route, required this.ref});

  @override
  State<_RouteCard> createState() => _RouteCardState();
}

class _RouteCardState extends State<_RouteCard> {
  late bool _likedByMe;
  late bool _bookmarkedByMe;
  late int _likeCount;

  @override
  void initState() {
    super.initState();
    _likedByMe = widget.route.likedByMe;
    _bookmarkedByMe = widget.route.bookmarkedByMe;
    _likeCount = widget.route.likeCount;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 지도 미리보기
          if (widget.route.routeGeoJson != null)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 160,
                child: _RouteMapPreview(geoJson: widget.route.routeGeoJson!),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 제목
                Text(
                  widget.route.title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.route.dogName}의 산책 경로에요',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 10),

                // 거리/시간
                Row(
                  children: [
                    _statChip(Icons.straighten, widget.route.distanceText,
                        Colors.blue),
                    const SizedBox(width: 8),
                    _statChip(Icons.timer, widget.route.durationText,
                        Colors.orange),
                  ],
                ),
                const SizedBox(height: 10),

                // 좋아요 / 북마크
                Row(
                  children: [
                    GestureDetector(
                      onTap: _toggleLike,
                      child: Row(
                        children: [
                          Icon(
                            _likedByMe
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: _likedByMe ? Colors.red : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text('$_likeCount',
                              style: TextStyle(
                                  color: _likedByMe
                                      ? Colors.red
                                      : Colors.grey)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: _toggleBookmark,
                      child: Icon(
                        _bookmarkedByMe
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                        color: _bookmarkedByMe
                            ? const Color(0xFF4CAF50)
                            : Colors.grey,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleLike() async {
    try {
      await widget.ref
          .read(walkRepositoryProvider)
          .toggleLike(widget.route.sessionId);
      setState(() {
        _likedByMe = !_likedByMe;
        _likeCount += _likedByMe ? 1 : -1;
      });
    } catch (_) {}
  }

  Future<void> _toggleBookmark() async {
    try {
      await widget.ref
          .read(walkRepositoryProvider)
          .toggleBookmark(widget.route.sessionId);
      setState(() => _bookmarkedByMe = !_bookmarkedByMe);
    } catch (_) {}
  }

  Widget _statChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _RouteMapPreview extends StatefulWidget {
  final String geoJson;

  const _RouteMapPreview({required this.geoJson});

  @override
  State<_RouteMapPreview> createState() => _RouteMapPreviewState();
}

class _RouteMapPreviewState extends State<_RouteMapPreview> {
  NaverMapController? _controller;

  @override
  Widget build(BuildContext context) {
    return NaverMap(
      options: const NaverMapViewOptions(
        scrollGesturesEnable: false,
        zoomGesturesEnable: false,
        tiltGesturesEnable: false,
        locationButtonEnable: false,
      ),
      onMapReady: (controller) {
        _controller = controller;
        _drawRoute();
      },
    );
  }

  void _drawRoute() async {
    if (_controller == null) return;
    try {
      final geoJson = jsonDecode(widget.geoJson);
      final coordinates = geoJson['coordinates'] as List;
      if (coordinates.isEmpty) return;

      final coords = coordinates
          .map((c) => NLatLng(c[1].toDouble(), c[0].toDouble()))
          .toList();

      final polyline = NPolylineOverlay(
        id: 'route_preview',
        coords: coords,
        color: const Color(0xFF4CAF50),
        width: 4,
      );
      await _controller!.addOverlay(polyline);

      // 경로 전체 보이도록 카메라 조정
      if (coords.isNotEmpty) {
        final bounds = NLatLngBounds.from(coords);
        await _controller!.updateCamera(
          NCameraUpdate.fitBounds(bounds,
              padding: const EdgeInsets.all(20)),
        );
      }
    } catch (_) {}
  }
}
