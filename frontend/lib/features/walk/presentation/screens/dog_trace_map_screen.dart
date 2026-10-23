import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rive/rive.dart' as rive;
import '../../domain/providers/walk_provider.dart';
import '../models/dog_trace_visual.dart';

class DogTraceMapScreen extends ConsumerStatefulWidget {
  const DogTraceMapScreen({super.key});

  @override
  ConsumerState<DogTraceMapScreen> createState() => _DogTraceMapScreenState();
}

class _DogTraceMapScreenState extends ConsumerState<DogTraceMapScreen> {
  static const _markingSpotIcon = NOverlayImage.fromAssetImage(
    'assets/markers/marking_spot_paw.png',
  );

  NaverMapController? _controller;
  DogTraceVisual? _selectedTrace;
  bool _todayOnly = true;

  List<DogTraceVisual> _visibleTraces(List<DogTraceVisual> traces) =>
      _todayOnly ? traces.where((trace) => trace.isToday).toList() : traces;

  @override
  void dispose() {
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final discoveriesAsync = ref.watch(latestTodayWalkTraceDiscoveriesProvider);
    final allTraces = buildDogTraceMapItems(
      discoveriesAsync.valueOrNull ?? const [],
    );
    final traces = _visibleTraces(allTraces);

    ref.listen(latestTodayWalkDetailProvider, (_, next) {
      if (next.hasValue) _drawTraces(traces);
    });
    ref.listen(latestTodayWalkTraceDiscoveriesProvider, (_, next) {
      if (next.hasValue) {
        final updated = _visibleTraces(buildDogTraceMapItems(next.value!));
        _drawTraces(updated);
      }
    });

    final topPadding = MediaQuery.of(context).padding.top;
    final todayStatsAsync = ref.watch(todayWalkStatsProvider);
    final todayStats = todayStatsAsync.valueOrNull;
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
            },
            onMapTapped: (_, _) => setState(() => _selectedTrace = null),
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
                        color: Color(0xFF719B7B),
                        width: 5,
                        label: '내 산책길',
                        isStrong: true,
                      ),
                      SizedBox(height: 7),
                      _RouteLegend(
                        color: Color(0x9987A9C4),
                        width: 3,
                        label: '다른 강아지의 최근 흔적',
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
      await controller.addOverlay(
        NPolylineOverlay(
          id: 'trace-${trace.id}',
          coords: trace.points,
          color: trace.color.withValues(alpha: 0.42),
          width: 4,
          lineCap: NLineCap.round,
          lineJoin: NLineJoin.round,
        ),
      );
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

    final markingSpot = NMarker(
      id: 'shared-marking-spot',
      position: const NLatLng(37.21855, 126.94535),
      icon: _markingSpotIcon,
      size: const Size(42, 48),
      anchor: const NPoint(0.5, 1),
      caption: NOverlayCaption(text: '${traces.length}마리의 흔적'),
      isForceShowIcon: true,
      isHideCollidedMarkers: false,
    );
    await controller.addOverlay(markingSpot);

    final ownRoute = _parseRoute(
      ref.read(latestTodayWalkDetailProvider).valueOrNull?.routeGeoJson,
    );
    if (ownRoute.length >= 2) {
      await controller.addOverlay(
        NPolylineOverlay(
          id: 'my-route-outline',
          coords: ownRoute,
          color: const Color(0xFFF5F8F3).withValues(alpha: 0.9),
          width: 9,
          lineCap: NLineCap.round,
          lineJoin: NLineJoin.round,
        ),
      );
      await controller.addOverlay(
        NPolylineOverlay(
          id: 'my-route',
          coords: ownRoute,
          color: const Color(0xFF719B7B),
          width: 6,
          lineCap: NLineCap.round,
          lineJoin: NLineJoin.round,
        ),
      );
    }
  }

  List<NLatLng> _parseRoute(String? routeGeoJson) {
    if (routeGeoJson == null || routeGeoJson.isEmpty) return const [];
    try {
      final decoded = jsonDecode(routeGeoJson);
      if (decoded is! Map<String, dynamic>) return const [];
      final coordinates = decoded['coordinates'];
      if (coordinates is! List) return const [];
      return coordinates
          .whereType<List>()
          .where((coordinate) => coordinate.length >= 2)
          .map(
            (coordinate) => NLatLng(
              (coordinate[1] as num).toDouble(),
              (coordinate[0] as num).toDouble(),
            ),
          )
          .toList();
    } catch (_) {
      return const [];
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

  const _TraceSummaryCard({
    required this.traces,
    required this.distanceText,
    required this.durationText,
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
              _AnimatedDogMascot(count: traces.length),
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
                    const SizedBox(height: 4),
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

class _AnimatedDogMascot extends StatefulWidget {
  final int count;

  const _AnimatedDogMascot({required this.count});

  @override
  State<_AnimatedDogMascot> createState() => _AnimatedDogMascotState();
}

class _AnimatedDogMascotState extends State<_AnimatedDogMascot>
    with SingleTickerProviderStateMixin {
  late final rive.FileLoader _loader = rive.FileLoader.fromAsset(
    'assets/rive/dog_mascot.riv',
    riveFactory: rive.Factory.flutter,
  );
  late final AnimationController _idleController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _idleController.dispose();
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84,
      height: 68,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: ColoredBox(
                color: const Color(0xFFEAF7E9),
                child: AnimatedBuilder(
                  animation: _idleController,
                  builder: (context, child) {
                    final progress = _idleController.value;
                    return Transform.translate(
                      offset: Offset(0, -2.5 * progress),
                      child: Transform.rotate(
                        angle: (progress - 0.5) * 0.035,
                        child: child,
                      ),
                    );
                  },
                  child: rive.RiveWidgetBuilder(
                    fileLoader: _loader,
                    builder: (context, state) => switch (state) {
                      rive.RiveLoading() => const _MascotFallback(),
                      rive.RiveFailed() => const _MascotFallback(),
                      rive.RiveLoaded() => rive.RiveWidget(
                        controller: state.controller,
                        fit: rive.Fit.contain,
                      ),
                    },
                  ),
                ),
              ),
            ),
          ),
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
                '${widget.count}',
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
}

class _MascotFallback extends StatelessWidget {
  const _MascotFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.pets, color: Color(0xFF4CAF50), size: 30),
    );
  }
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
            child: const Icon(Icons.pets, color: Colors.white),
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
