import '../../../../core/providers/household_change_provider.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/walk_model.dart';
import '../../../home/domain/providers/home_provider.dart';
import '../../data/repositories/walk_repository.dart';
import '../../domain/providers/walk_provider.dart';
import '../models/dog_trace_visual.dart';
import '../models/route_segments.dart';
import '../widgets/marking_dog_chart.dart';
import '../widgets/marking_spot_detail_sheet.dart';
import '../widgets/trace_affiliation.dart';
import '../widgets/dog_face_icon.dart';
import '../widgets/marking_scent_notice.dart';
import '../../../home/presentation/widgets/app_intro_gate.dart';

class DogTraceMapScreen extends ConsumerStatefulWidget {
  const DogTraceMapScreen({super.key});

  @override
  ConsumerState<DogTraceMapScreen> createState() => _DogTraceMapScreenState();
}

class _DogTraceMapScreenState extends ConsumerState<DogTraceMapScreen> {
  final _spotIcons = <bool, NOverlayImage>{};

  Future<NOverlayImage> _spotIcon(bool family) async {
    return _spotIcons[family] ??= await NOverlayImage.fromWidget(
      context: context,
      size: const Size(42, 48),
      widget: Center(
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: family ? familyTraceColor : otherTraceColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const Icon(Icons.pets, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  NaverMapController? _controller;
  DogTraceVisual? _selectedTrace;
  PopularMarkingSpot? _popularSpot;
  Timer? _popularSpotTimer;
  int _popularSpotRequest = 0;
  bool _todayOnly = true;

  List<DogTraceVisual> _visibleTraces(List<DogTraceVisual> traces) =>
      _todayOnly ? traces.where((trace) => trace.isToday).toList() : traces;

  @override
  void dispose() {
    _popularSpotTimer?.cancel();
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final discoveriesAsync = ref.watch(latestTodayWalkTraceDiscoveriesProvider);
    final allTraces = buildDogTraceMapItems(
      (discoveriesAsync.isLoading || discoveriesAsync.hasError)
          ? const []
          : discoveriesAsync.valueOrNull ?? const [],
    );
    final traces = _visibleTraces(allTraces);

    ref.listen(latestTodayWalkDetailProvider, (_, next) {
      if (!next.isLoading) _drawTraces(next.hasError ? const [] : traces);
    });
    ref.listen(latestTodayWalkTraceDiscoveriesProvider, (_, next) {
      if (next.hasValue && !next.isLoading && !next.hasError) {
        final updated = _visibleTraces(buildDogTraceMapItems(next.value!));
        _drawTraces(updated);
      }
    });

    final topPadding = MediaQuery.of(context).padding.top;
    final todayStatsAsync = ref.watch(todayWalkStatsProvider);
    final todayStats = todayStatsAsync.hasError
        ? null
        : todayStatsAsync.valueOrNull;
    final distanceText = todayStatsAsync.isLoading
        ? '...'
        : todayStats?.distanceText ?? '0m';
    final durationText = todayStatsAsync.isLoading
        ? '...'
        : todayStats?.durationText ?? '0분';

    return Scaffold(
      body: Stack(
        children: [
          NaverMap(
            options: const NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: NLatLng(37.21850, 126.94530),
                zoom: 16,
              ),
              liteModeEnable: true,
              activeLayerGroups: [],
              buildingHeight: 0,
              lightness: 0.18,
              symbolScale: 0.55,
              consumeSymbolTapEvents: false,
              scaleBarEnable: false,
              locationButtonEnable: false,
              compassEnable: false,
              rotationGesturesEnable: false,
              tiltGesturesEnable: false,
            ),
            onMapReady: (controller) {
              _controller = controller;
              _drawTraces(traces);
              final profile = ref.read(userProfileProvider).valueOrNull;
              if (profile?.hasNeighborhood == true) {
                controller.updateCamera(
                  NCameraUpdate.scrollAndZoomTo(
                    target: NLatLng(profile!.homeLat!, profile.homeLng!),
                    zoom: 15,
                  ),
                );
              }
              _schedulePopularSpot();
            },
            onMapTapped: (_, _) => setState(() => _selectedTrace = null),
          ),
          Positioned(
            top: topPadding + 12,
            right: 16,
            child: IconButton.filledTonal(
              tooltip: '앱 사용 안내',
              icon: const Icon(Icons.info_outline),
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (_) => const AppIntroDialog(),
              ),
            ),
          ),
          Positioned(
            top: topPadding + 68,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: _shadow,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _filterChip('오늘', _todayOnly, true, allTraces),
                      _filterChip('최근 3일', !_todayOnly, false, allTraces),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: _shadow,
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _RouteLegend(
                        color: familyTraceColor,
                        width: 5,
                        label: '우리 가족 산책길 · 초록색',
                        isStrong: true,
                      ),
                      SizedBox(height: 7),
                      _RouteLegend(
                        color: otherTraceColor,
                        width: 3,
                        label: '다른 강아지의 흔적 · 파란색',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: _selectedTrace == null
                ? _TraceSummaryCard(
                    traces: traces,
                    distanceText: distanceText,
                    durationText: durationText,
                    popularSpot: _popularSpot,
                  )
                : _TraceDetailCard(
                    trace: _selectedTrace!,
                    onClose: () => setState(() => _selectedTrace = null),
                  ),
          ),
        ],
      ),
    );
  }

  bool _spotDetailOpen = false;

  Future<void> _openPopularSpot(PopularMarkingSpot spot) async {
    if (!mounted || _spotDetailOpen) return;
    _spotDetailOpen = true;
    try {
      await showMarkingSpotDetail(
        context,
        spotId: spot.id,
        title: '내 동네 마킹 스팟 1위',
        lastVisitedAt: spot.lastVisitedAt,
        color: spot.familyVisited ? familyTraceColor : otherTraceColor,
      );
    } finally {
      _spotDetailOpen = false;
    }
  }

  void _schedulePopularSpot() {
    _popularSpotTimer?.cancel();
    ++_popularSpotRequest;
    _popularSpotTimer = Timer(
      const Duration(milliseconds: 400),
      _loadPopularSpot,
    );
  }

  Future<void> _loadPopularSpot() async {
    final controller = _controller;
    if (controller == null) return;
    final request = ++_popularSpotRequest;
    PopularMarkingSpot? spot;
    try {
      final change = ref.read(householdChangeProvider);
      if (change != null) await change;
      if (!mounted || request != _popularSpotRequest) return;
      final profile = ref.read(userProfileProvider).valueOrNull;
      if (profile?.hasNeighborhood != true) return;
      spot = await ref
          .read(walkRepositoryProvider)
          .getPopularMarkingSpot(profile!.homeLat!, profile.homeLng!);
    } catch (_) {
      spot = null;
    }
    if (!mounted || request != _popularSpotRequest) return;
    setState(() => _popularSpot = spot);
    _drawTraces(
      _visibleTraces(
        buildDogTraceMapItems(
          ref.read(latestTodayWalkTraceDiscoveriesProvider).valueOrNull ??
              const [],
        ),
      ),
    );
  }

  Widget _filterChip(
    String label,
    bool selected,
    bool todayOnly,
    List<DogTraceVisual> allTraces,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        if (_todayOnly == todayOnly) return;
        setState(() {
          _todayOnly = todayOnly;
          _selectedTrace = null;
        });
        _drawTraces(_visibleTraces(allTraces));
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF4CAF50) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black54,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<void> _drawTraces(List<DogTraceVisual> traces) async {
    final controller = _controller;
    if (controller == null) return;
    await controller.clearOverlays();

    for (final trace in traces) {
      for (var i = 0; i < trace.segments.length; i++) {
        await controller.addOverlay(
          NPolylineOverlay(
            id: 'trace-${trace.id}-$i',
            coords: trace.segments[i],
            color: trace.color.withValues(alpha: 0.42),
            width: 4,
            lineCap: NLineCap.round,
            lineJoin: NLineJoin.round,
          ),
        );
      }
      final marker = NMarker(
        id: 'dog-${trace.id}',
        position: trace.points[trace.markerIndex],
        caption: NOverlayCaption(
          text: '${trace.name} · ${trace.isToday ? '오늘' : '3일 내'}',
        ),
        iconTintColor: trace.color.withValues(alpha: 0.82),
      );
      marker.setOnTapListener((_) => setState(() => _selectedTrace = trace));
      await controller.addOverlay(marker);
    }

    final popularSpot = _popularSpot;
    if (popularSpot != null) {
      final marker = NMarker(
        id: 'popular-marking-spot',
        alpha: markingScentOpacity(
          lastVisitedAt: popularSpot.lastVisitedAt,
          lastRainAt: popularSpot.lastRainAt,
        ),
        position: NLatLng(popularSpot.lat, popularSpot.lng),
        icon: await _spotIcon(popularSpot.familyVisited),
        size: const Size(42, 48),
        anchor: const NPoint(0.5, 1),
        caption: NOverlayCaption(
          text:
              '주변 1위 · ${popularSpot.dogCount}마리 · ${popularSpot.familyVisited ? '가족도 방문' : '다른 강아지'}',
        ),
        isForceShowIcon: true,
        isHideCollidedMarkers: false,
      );
      marker.setOnTapListener((_) => _openPopularSpot(popularSpot));
      await controller.addOverlay(marker);
    }

    final detail = ref.read(latestTodayWalkDetailProvider);
    final ownSegments = parseRouteSegments(
      (detail.isLoading || detail.hasError)
          ? null
          : detail.valueOrNull?.routeGeoJson,
    );
    for (var i = 0; i < ownSegments.length; i++) {
      await controller.addOverlay(
        NPolylineOverlay(
          id: 'my-route-outline-$i',
          coords: ownSegments[i],
          color: const Color(0xFFF5F8F3).withValues(alpha: 0.9),
          width: 9,
          lineCap: NLineCap.round,
          lineJoin: NLineJoin.round,
        ),
      );
      await controller.addOverlay(
        NPolylineOverlay(
          id: 'my-route-$i',
          coords: ownSegments[i],
          color: familyTraceColor,
          width: 6,
          lineCap: NLineCap.round,
          lineJoin: NLineJoin.round,
        ),
      );
    }
  }

  static final _shadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      blurRadius: 12,
      offset: const Offset(0, 3),
    ),
  ];
}

class _RouteLegend extends StatelessWidget {
  final Color color;
  final double width;
  final String label;
  final bool isStrong;

  const _RouteLegend({
    required this.color,
    required this.width,
    required this.label,
    this.isStrong = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: width,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(width),
            boxShadow: isStrong
                ? const [BoxShadow(color: Colors.white, spreadRadius: 2)]
                : null,
          ),
        ),
        const SizedBox(width: 9),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isStrong ? FontWeight.w800 : FontWeight.w600,
            color: isStrong ? Colors.black87 : Colors.black54,
          ),
        ),
      ],
    );
  }
}

class _TraceSummaryCard extends StatelessWidget {
  final List<DogTraceVisual> traces;
  final String distanceText;
  final String durationText;
  final PopularMarkingSpot? popularSpot;

  const _TraceSummaryCard({
    required this.traces,
    required this.distanceText,
    required this.durationText,
    required this.popularSpot,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _DogMascot(count: traces.length),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${traces.length}마리의 흔적이 보여요',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (popularSpot != null) ...[
                      const SizedBox(height: 2),
                      MarkingDogChart(
                        dogCount: popularSpot!.dogCount,
                        lastVisitedAt: popularSpot!.lastVisitedAt,
                        lastRainAt: popularSpot!.lastRainAt,
                      ),
                    ],
                    if (traces.isNotEmpty) const SizedBox(height: 4),
                    if (traces.isNotEmpty)
                      Text(
                        traces.map((trace) => trace.name).join(' · '),
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
          if (popularSpot != null) ...[
            TraceAffiliationBadge(
              isFamily: popularSpot!.familyVisited,
              isSpot: true,
            ),
            const SizedBox(height: 4),
            Text(
              '내 동네 2km · 마킹 스팟 1위 · ${popularSpot!.dogCount}마리',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F8F0),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.directions_walk,
                  color: Color(0xFF4CAF50),
                  size: 18,
                ),
                const SizedBox(width: 7),
                const Text(
                  '오늘의 산책',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                _TodayWalkValue(icon: Icons.straighten, value: distanceText),
                Container(
                  width: 1,
                  height: 20,
                  margin: const EdgeInsets.symmetric(horizontal: 11),
                  color: const Color(0xFFD8E8D6),
                ),
                _TodayWalkValue(
                  icon: Icons.timer_outlined,
                  value: durationText,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayWalkValue extends StatelessWidget {
  final IconData icon;
  final String value;

  const _TodayWalkValue({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Colors.black45),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _DogMascot extends StatelessWidget {
  final int count;
  const _DogMascot({required this.count});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 84,
    height: 68,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        const Center(child: DogFaceIcon(size: 64)),
        Positioned(
          right: -5,
          top: -5,
          child: Container(
            width: 25,
            height: 25,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Text(
              '$count',
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
  );
}

class _TraceDetailCard extends StatelessWidget {
  final DogTraceVisual trace;
  final VoidCallback onClose;

  const _TraceDetailCard({required this.trace, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration,
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: trace.color,
            child: DogFaceIcon(variant: trace.colorIndex, size: 40),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  trace.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  trace.recency,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 5),
                const Text(
                  '정확한 시간과 보호자 정보는 표시하지 않아요',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
        ],
      ),
    );
  }
}

final _cardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(20),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.14),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ],
);
