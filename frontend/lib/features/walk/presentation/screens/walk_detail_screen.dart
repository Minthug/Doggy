import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/walk_model.dart';
import '../../data/repositories/walk_repository.dart';
import '../../domain/providers/walk_provider.dart';
import '../../../dog/data/repositories/dog_repository.dart';
import '../models/dog_trace_visual.dart';

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
    final detail = detailAsync.valueOrNull;

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
          if (detail != null)
            IconButton(
              onPressed: () => _toggleArchive(context, ref, detail),
              tooltip: detail.archived ? '보관 해제' : '흔적 보관',
              icon: Icon(
                detail.archived
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                color: const Color(0xFF7A9B76),
              ),
            ),
          if (detail == null || !detail.detailsPurged)
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

  Future<void> _toggleArchive(
    BuildContext context,
    WidgetRef ref,
    WalkDetail detail,
  ) async {
    if (detail.archived && detail.detailsPurged) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('보관을 해제할까요?'),
          content: const Text('원본 GPS가 이미 삭제되어 보관을 해제하면 이 흔적길은 복구할 수 없어요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('해제'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    try {
      final repository = ref.read(walkRepositoryProvider);
      if (detail.archived) {
        await repository.unarchive(sessionId);
      } else {
        await repository.archive(sessionId);
      }
      ref.invalidate(_walkDetailProvider(sessionId));
      ref.invalidate(walkHistoryProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(detail.archived ? '보관을 해제했습니다' : '산책 흔적을 보관했습니다'),
          ),
        );
        if (detail.archived && detail.detailsPurged) Navigator.pop(context);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('보관 상태를 변경하지 못했습니다')));
      }
    }
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
    final tracesAsync = ref.watch(walkTraceDiscoveriesProvider(sessionId));
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
          child: detail.tracePathData != null
              ? _ArchivedTrace(pathData: detail.tracePathData!)
              : detail.archived && detail.detailsPurged
              ? const _TraceUnavailable()
              : _RouteMap(
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
                _RetentionNotice(detail: detail),
                const SizedBox(height: 14),
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

                // 산책 동안 직접 만난 강아지들
                const Text(
                  '산책 동안 만난 강아지',
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
                const SizedBox(height: 24),
                const Text(
                  '산책 중 발견한 강아지 흔적',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  '내 산책길과 가까운 최근 흔적이에요.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 12),
                tracesAsync.when(
                  data: (discoveries) {
                    final traces = discoveries
                        .expand(
                          (discovery) => discovery.dogs.map(
                            (dog) => (discovery: discovery, dog: dog),
                          ),
                        )
                        .toList();
                    if (traces.isEmpty) {
                      return const _EmptyDiscoveredTraces();
                    }
                    return Column(
                      children: traces
                          .map(
                            (trace) => _DiscoveredTraceCard(
                              discovery: trace.discovery,
                              dog: trace.dog,
                            ),
                          )
                          .toList(),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => _TraceLoadError(
                    onRetry: () => ref.invalidate(
                      walkTraceDiscoveriesProvider(sessionId),
                    ),
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

class _ArchivedTrace extends StatelessWidget {
  final String pathData;

  const _ArchivedTrace({required this.pathData});

  @override
  Widget build(BuildContext context) {
    final points = _decodeTracePath(pathData);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF8EE), Color(0xFFEEF8F1)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: points.length < 2
              ? const _TraceUnavailable()
              : Semantics(
                  label: '보관한 산책 흔적길',
                  image: true,
                  child: CustomPaint(
                    painter: _TracePainter(points: points, source: pathData),
                    child: const SizedBox.expand(),
                  ),
                ),
        ),
      ),
    );
  }
}

List<Offset> _decodeTracePath(String source) {
  if (!source.startsWith('v1|')) return const [];
  try {
    final chunks = source.substring(3).split(';');
    if (chunks.length < 2 || chunks.length > 72) return const [];
    final result = <Offset>[];
    var x = 0;
    var y = 0;
    for (int i = 0; i < chunks.length; i++) {
      final pair = chunks[i].split(',');
      if (pair.length != 2) return const [];
      final first = int.parse(pair[0]);
      final second = int.parse(pair[1]);
      if (i == 0) {
        x = first;
        y = second;
      } else {
        x += first;
        y += second;
      }
      if (x < 0 || x > 1000 || y < 0 || y > 600) return const [];
      result.add(Offset(x.toDouble(), y.toDouble()));
    }
    return result;
  } catch (_) {
    return const [];
  }
}

class _TracePainter extends CustomPainter {
  final List<Offset> points;
  final String source;

  const _TracePainter({required this.points, required this.source});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 1000, size.height / 600);
    final origin = Offset(
      (size.width - 1000 * scale) / 2,
      (size.height - 600 * scale) / 2,
    );
    Offset transform(Offset point) => origin + point * scale;

    final accentTop = Path()
      ..moveTo(20, size.height * 0.25)
      ..cubicTo(
        size.width * 0.25,
        5,
        size.width * 0.55,
        size.height * 0.28,
        size.width - 18,
        size.height * 0.16,
      );
    canvas.drawPath(
      accentTop,
      Paint()
        ..color = const Color(0xFFDDEBDD).withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.round,
    );

    final accentBottom = Path()
      ..moveTo(16, size.height * 0.82)
      ..cubicTo(
        size.width * 0.28,
        size.height * 0.62,
        size.width * 0.55,
        size.height,
        size.width - 16,
        size.height * 0.78,
      );
    canvas.drawPath(
      accentBottom,
      Paint()
        ..color = const Color(0xFFF2DFC5).withValues(alpha: 0.68)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 19
        ..strokeCap = StrokeCap.round,
    );

    final transformed = points.map(transform).toList(growable: false);
    final route = Path()..moveTo(transformed.first.dx, transformed.first.dy);
    for (int i = 1; i < transformed.length; i++) {
      final previous = transformed[i - 1];
      final current = transformed[i];
      final midpoint = Offset(
        (previous.dx + current.dx) / 2,
        (previous.dy + current.dy) / 2,
      );
      route.quadraticBezierTo(
        previous.dx,
        previous.dy,
        midpoint.dx,
        midpoint.dy,
      );
    }
    route.lineTo(transformed.last.dx, transformed.last.dy);

    canvas.drawPath(
      route.shift(Offset(0, 4 * scale)),
      Paint()
        ..color = const Color(0xFF315B43).withValues(alpha: 0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 15 * scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      route,
      Paint()
        ..color = const Color(0xFF5F9D75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12 * scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      route,
      Paint()
        ..color = const Color(0xFFDDF1E4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.drawCircle(
      transformed.first,
      12 * scale,
      Paint()..color = const Color(0xFF5F9D75),
    );
    canvas.drawCircle(
      transformed.first,
      6 * scale,
      Paint()..color = const Color(0xFFFFFDF8),
    );
    canvas.drawCircle(
      transformed.last,
      15 * scale,
      Paint()..color = const Color(0xFFFFFDF8),
    );
    canvas.drawCircle(
      transformed.last,
      10 * scale,
      Paint()..color = const Color(0xFFF5A96B),
    );

    _drawPaw(canvas, Offset(size.width - 42, size.height - 42), scale);
  }

  void _drawPaw(Canvas canvas, Offset center, double scale) {
    final paint = Paint()
      ..color = const Color(0xFF89B99A).withValues(alpha: 0.48);
    final pawScale = math.max(scale, 0.45);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.2);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: 28 * pawScale,
        height: 34 * pawScale,
      ),
      paint,
    );
    for (final toe in const [
      Offset(-14, -20),
      Offset(0, -25),
      Offset(14, -20),
    ]) {
      canvas.drawCircle(toe * pawScale, 7 * pawScale, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TracePainter oldDelegate) =>
      oldDelegate.source != source;
}

class _TraceUnavailable extends StatelessWidget {
  const _TraceUnavailable();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFF4F0E8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pets_rounded, color: Color(0xFF7A9B76), size: 34),
            SizedBox(height: 8),
            Text(
              '흔적길을 표시할 수 없어요',
              style: TextStyle(color: Color(0xFF657061), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _RetentionNotice extends StatelessWidget {
  final WalkDetail detail;

  const _RetentionNotice({required this.detail});

  @override
  Widget build(BuildContext context) {
    final text = detail.detailsPurged
        ? '원본 GPS는 삭제되고 좌표 없는 가벼운 흔적길만 보관 중이에요.'
        : detail.archived
        ? '보관 완료 · 7일 후 GPS는 삭제되고 좌표 없는 흔적길만 남아요.'
        : '상세 경로는 7일 동안 보관돼요. 오래 남기려면 북마크를 눌러주세요.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1E6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            detail.archived ? Icons.bookmark_rounded : Icons.schedule_rounded,
            color: const Color(0xFF6F8F6A),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF50634D),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
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

class _EmptyDiscoveredTraces extends StatelessWidget {
  const _EmptyDiscoveredTraces();

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
            '이 산책길에서 발견한 흔적이 없어요',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _DiscoveredTraceCard extends StatelessWidget {
  final WalkTraceDiscovery discovery;
  final WalkTraceDog dog;

  const _DiscoveredTraceCard({required this.discovery, required this.dog});

  @override
  Widget build(BuildContext context) {
    final hasProfileImage = dog.profileImage?.isNotEmpty ?? false;
    return Container(
      width: double.infinity,
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
            backgroundColor: dogTracePalette[dog.id % dogTracePalette.length]
                .withValues(alpha: 0.25),
            backgroundImage: hasProfileImage
                ? NetworkImage(dog.profileImage!)
                : null,
            child: !hasProfileImage
                ? Icon(
                    Icons.pets,
                    color: dogTracePalette[dog.id % dogTracePalette.length],
                    size: 24,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dog.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (dog.breed != null && dog.breed!.isNotEmpty) dog.breed!,
                    discovery.recencyText,
                  ].join(' · '),
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: dogTracePalette[dog.id % dogTracePalette.length]
                  .withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              discovery.isToday ? '오늘' : '3일 내',
              style: TextStyle(
                color: dogTracePalette[dog.id % dogTracePalette.length],
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TraceLoadError extends StatelessWidget {
  final VoidCallback onRetry;

  const _TraceLoadError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            '흔적을 불러오지 못했어요',
            style: TextStyle(color: Colors.grey),
          ),
          TextButton(onPressed: onRetry, child: const Text('다시 시도')),
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
