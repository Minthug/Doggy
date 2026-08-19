import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/walk_model.dart';
import '../../data/repositories/walk_repository.dart';
import '../../../dog/data/repositories/dog_repository.dart';

final _walkDetailProvider = FutureProvider.family<WalkDetail, int>((
  ref,
  sessionId,
) {
  return ref.watch(walkRepositoryProvider).getDetail(sessionId);
});

final _walkMeetsProvider = FutureProvider.family<List<WalkMeet>, int>((
  ref,
  sessionId,
) {
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
        title: const Text(
          '산책 상세',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _showPublishDialog(context, ref),
            icon: const Icon(Icons.share_outlined, size: 18),
            label: const Text('공개'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF4CAF50),
            ),
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '산책 경로를 공개하면 다른 사용자가 지도에서 경로를 볼 수 있습니다. 시작 지점과 종료 지점으로 생활권이 추정될 수 있으니 공개 전에 확인해주세요.',
              style: TextStyle(fontSize: 14, height: 1.45),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                hintText: '예) 한강 야경 코스, 북한산 둘레길',
                labelText: '경로 제목',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (titleController.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              try {
                await ref
                    .read(walkRepositoryProvider)
                    .publish(sessionId, titleController.text.trim());
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('경로가 공개됐습니다')));
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('공개에 실패했습니다')));
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
          child: _RouteMap(
            geoJson: detail.routeGeoJson,
            markingSpots: detail.markingSpots,
          ),
        ),

        // 통계
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateText,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
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
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatItem(
                        icon: Icons.straighten,
                        label: '거리',
                        value: detail.distanceText,
                      ),
                      _divider(),
                      _StatItem(
                        icon: Icons.timer,
                        label: '시간',
                        value: detail.durationText,
                      ),
                      _divider(),
                      _StatItem(
                        icon: Icons.speed,
                        label: '평균속도',
                        value: _avgSpeed(
                          detail.distanceMeters,
                          detail.durationSeconds,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                if (detail.markingSpots.isNotEmpty) ...[
                  Text(
                    '마킹 스팟 ${detail.markingSpots.length}곳',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Column(
                    children: [
                      for (int i = 0; i < detail.markingSpots.length; i++)
                        _MarkingSpotCard(
                          spot: detail.markingSpots[i],
                          index: i + 1,
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                // 만난 강아지들
                const Text(
                  '이번 산책에서 만난 강아지들',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stackTrace) => const _EmptyMeets(),
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
  final List<MarkingSpot> markingSpots;

  const _RouteMap({this.geoJson, this.markingSpots = const []});

  @override
  State<_RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<_RouteMap> {
  static const _markingSpotIcon = NOverlayImage.fromAssetImage(
    'assets/markers/marking_spot_paw.png',
  );

  NaverMapController? _controller;

  @override
  void dispose() {
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        NaverMap(
          options: const NaverMapViewOptions(
            scrollGesturesEnable: true,
            zoomGesturesEnable: true,
            rotationGesturesEnable: false,
            tiltGesturesEnable: false,
          ),
          onMapReady: (controller) {
            _controller = controller;
            _drawRoute();
          },
        ),
        Positioned(
          right: 12,
          bottom: 16,
          child: _MapZoomControls(
            onZoomIn: () => _zoomBy(1),
            onZoomOut: () => _zoomBy(-1),
          ),
        ),
      ],
    );
  }

  Future<void> _zoomBy(double delta) async {
    final controller = _controller;
    if (controller == null) return;
    final update = NCameraUpdate.zoomBy(delta)
      ..setAnimation(duration: const Duration(milliseconds: 180));
    await controller.updateCamera(update);
  }

  Future<void> _drawRoute() async {
    if (_controller == null) return;

    try {
      final boundsCoords = <NLatLng>[];
      final coords = <NLatLng>[];

      if (widget.geoJson != null) {
        final geoJson = jsonDecode(widget.geoJson!);
        final coordinates = geoJson['coordinates'] as List<dynamic>?;
        if (coordinates != null && coordinates.isNotEmpty) {
          coords.addAll(
            coordinates.map(
              (c) =>
                  NLatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
            ),
          );
          boundsCoords.addAll(coords);
        }
      }

      if (coords.isNotEmpty) {
        // 경로 폴리라인
        _controller!.addOverlay(
          NPolylineOverlay(
            id: 'route',
            coords: coords,
            color: const Color(0xFF4CAF50),
            width: 5,
          ),
        );

        // 시작 마커
        _controller!.addOverlay(
          NMarker(
            id: 'start',
            position: coords.first,
            caption: const NOverlayCaption(text: '시작'),
          ),
        );

        // 종료 마커
        _controller!.addOverlay(
          NMarker(
            id: 'end',
            position: coords.last,
            caption: const NOverlayCaption(text: '종료'),
          ),
        );
      }

      for (int i = 0; i < widget.markingSpots.length; i++) {
        final spot = widget.markingSpots[i];
        final position = NLatLng(spot.lat, spot.lng);
        boundsCoords.add(position);
        _controller!.addOverlay(
          NMarker(
            id: 'marking-${spot.id}',
            position: position,
            icon: _markingSpotIcon,
            size: const Size(34, 40),
            anchor: const NPoint(0.5, 1),
            isForceShowIcon: true,
            isHideCollidedMarkers: false,
          ),
        );
      }

      // 경로 전체가 보이도록 카메라 조정
      if (!mounted || _controller == null || boundsCoords.isEmpty) return;
      if (boundsCoords.length == 1) {
        await _controller!.updateCamera(
          NCameraUpdate.scrollAndZoomTo(target: boundsCoords.first, zoom: 16),
        );
      } else {
        await _controller!.updateCamera(
          NCameraUpdate.fitBounds(
            NLatLngBounds(
              southWest: NLatLng(
                boundsCoords
                    .map((c) => c.latitude)
                    .reduce((a, b) => a < b ? a : b),
                boundsCoords
                    .map((c) => c.longitude)
                    .reduce((a, b) => a < b ? a : b),
              ),
              northEast: NLatLng(
                boundsCoords
                    .map((c) => c.latitude)
                    .reduce((a, b) => a > b ? a : b),
                boundsCoords
                    .map((c) => c.longitude)
                    .reduce((a, b) => a > b ? a : b),
              ),
            ),
            padding: const EdgeInsets.all(40),
          ),
        );
      }
    } catch (e) {
      // GeoJSON 파싱 실패 시 무시
    }
  }
}

class _MapZoomControls extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const _MapZoomControls({required this.onZoomIn, required this.onZoomOut});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ZoomButton(icon: Icons.add, onPressed: onZoomIn),
          Container(width: 28, height: 1, color: const Color(0xFFE0E0E0)),
          _ZoomButton(icon: Icons.remove, onPressed: onZoomOut),
        ],
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _ZoomButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 22),
        color: const Color(0xFF2E7D32),
        onPressed: onPressed,
      ),
    );
  }
}

class _MarkingSpotCard extends ConsumerWidget {
  final MarkingSpot spot;
  final int index;

  const _MarkingSpotCard({required this.spot, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showMarkingSpotDetail(context, ref),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.pets, color: Color(0xFF4CAF50)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$index번째 마킹 스팟',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '이곳을 지난 강아지 ${spot.visitCount}마리 보기',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMarkingSpotDetail(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: FutureBuilder<MarkingSpotDetail>(
            future: ref
                .read(walkRepositoryProvider)
                .getMarkingSpotDetail(spot.id),
            builder: (context, snapshot) {
              final detail = snapshot.data;
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0E0E0),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF4CAF50,
                            ).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.pets,
                            color: Color(0xFF4CAF50),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$index번째 마킹 스팟',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                detail == null
                                    ? '방문한 강아지 정보를 불러오는 중'
                                    : '총 ${detail.visitCount}마리의 발자국',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (snapshot.connectionState != ConnectionState.done)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 28),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (snapshot.hasError)
                      const _MarkingSpotDetailMessage(
                        icon: Icons.error_outline,
                        text: '마킹 스팟 정보를 불러오지 못했습니다',
                      )
                    else if (detail == null || detail.visits.isEmpty)
                      const _MarkingSpotDetailMessage(
                        icon: Icons.pets,
                        text: '아직 이곳을 지난 강아지 정보가 없어요',
                      )
                    else ...[
                      const Text(
                        '이곳을 지난 강아지',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: detail.visits.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            return _MarkingSpotVisitTile(
                              visit: detail.visits[i],
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _MarkingSpotDetailMessage extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MarkingSpotDetailMessage({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF4CAF50), size: 28),
            const SizedBox(height: 8),
            Text(text, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

class _MarkingSpotVisitTile extends StatelessWidget {
  final MarkingSpotVisit visit;

  const _MarkingSpotVisitTile({required this.visit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFFE8F5E9),
            backgroundImage: visit.dog.profileImage != null
                ? NetworkImage(visit.dog.profileImage!)
                : null,
            child: visit.dog.profileImage == null
                ? const Icon(Icons.pets, color: Color(0xFF4CAF50), size: 20)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  visit.dog.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (visit.dog.breed != null && visit.dog.breed!.isNotEmpty)
                      visit.dog.breed!,
                    if (visit.visitedAt != null)
                      _formatVisitTime(visit.visitedAt!),
                  ].join(' · '),
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatVisitTime(String value) {
  try {
    final dt = DateTime.parse(value);
    return '${dt.month}.${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} 방문';
  } catch (_) {
    return '최근 방문';
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
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
        ],
      ),
      child: const Column(
        children: [
          Text('🐾', style: TextStyle(fontSize: 28)),
          SizedBox(height: 8),
          Text(
            '만난 강아지가 없어요',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _MeetCard extends ConsumerStatefulWidget {
  final WalkMeet meet;

  const _MeetCard({required this.meet});

  @override
  ConsumerState<_MeetCard> createState() => _MeetCardState();
}

class _MeetCardState extends ConsumerState<_MeetCard> {
  late Set<int> _favoritedDogIds;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _favoritedDogIds = widget.meet.dogs
        .where((d) => d.isFavorited)
        .map((d) => d.id)
        .toSet();
  }

  Future<void> _toggleFavorite(int dogId) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(dogRepositoryProvider).toggleFavorite(dogId);
      setState(() {
        if (_favoritedDogIds.contains(dogId)) {
          _favoritedDogIds.remove(dogId);
        } else {
          _favoritedDogIds.add(dogId);
        }
      });
    } catch (_) {
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFFE8F5E9),
            backgroundImage: widget.meet.user.profileImage != null
                ? NetworkImage(widget.meet.user.profileImage!)
                : null,
            child: widget.meet.user.profileImage == null
                ? const Text('🐶', style: TextStyle(fontSize: 20))
                : null,
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.meet.user.nickname,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                if (widget.meet.dogs.isNotEmpty)
                  Column(
                    children: widget.meet.dogs.map((dog) {
                      final isFav = _favoritedDogIds.contains(dog.id);
                      return Row(
                        children: [
                          Expanded(
                            child: Text(
                              dog.breed != null
                                  ? '${dog.name} · ${dog.breed}'
                                  : dog.name,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _toggleFavorite(dog.id),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              child: Icon(
                                isFav ? Icons.star : Icons.star_border,
                                size: 20,
                                color: isFav
                                    ? const Color(0xFFFFC107)
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                if (widget.meet.dogs.any((d) => d.warnings.isNotEmpty))
                  const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  children: widget.meet.dogs
                      .expand((d) => d.warnings)
                      .toSet()
                      .map(
                        (w) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '⚠️ ${_warningLabel(w)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFE65100),
                            ),
                          ),
                        ),
                      )
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

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF4CAF50), size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF4CAF50),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}
