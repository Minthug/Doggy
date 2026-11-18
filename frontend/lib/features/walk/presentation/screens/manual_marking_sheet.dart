import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../models/route_segments.dart';

Future<bool> showManualMarkingSheet(
  BuildContext context, {
  required String routeGeoJson,
  required Future<void> Function(double lat, double lng) onSubmit,
}) async {
  final segments = parseRouteSegments(routeGeoJson);
  if (segments.isEmpty) return false;
  NLatLng? selected;
  var submitting = false;

  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '빠진 마킹 위치 추가',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text('산책 경로에서 마킹한 곳을 지도에서 눌러주세요. 한 곳씩 추가할 수 있어요.'),
              const SizedBox(height: 12),
              SizedBox(
                height: (MediaQuery.sizeOf(sheetContext).height * 0.42).clamp(
                  180.0,
                  320.0,
                ),
                child: _ManualMarkingMap(
                  segments: segments,
                  onSelected: (position) =>
                      setSheetState(() => selected = position),
                ),
              ),
              const SizedBox(height: 8),
              Text(selected == null ? '경로 위의 위치를 선택해주세요' : '선택한 위치에 핀을 놓았어요'),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: selected == null || submitting
                      ? null
                      : () async {
                          setSheetState(() => submitting = true);
                          try {
                            await onSubmit(
                              selected!.latitude,
                              selected!.longitude,
                            );
                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext, true);
                            }
                          } catch (_) {
                            if (sheetContext.mounted) {
                              setSheetState(() => submitting = false);
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                const SnackBar(
                                  content: Text('경로 근처 위치인지 확인하고 다시 시도해주세요'),
                                ),
                              );
                            }
                          }
                        },
                  child: const Text('마킹 위치 저장'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return saved ?? false;
}

class _ManualMarkingMap extends StatefulWidget {
  final List<List<NLatLng>> segments;
  final ValueChanged<NLatLng> onSelected;

  const _ManualMarkingMap({required this.segments, required this.onSelected});

  @override
  State<_ManualMarkingMap> createState() => _ManualMarkingMapState();
}

class _ManualMarkingMapState extends State<_ManualMarkingMap> {
  NaverMapController? _controller;
  NMarker? _marker;
  Offset? _lastTapPosition;

  Future<void> _select(NLatLng position) async {
    widget.onSelected(position);
    final controller = _controller;
    if (controller == null) return;
    final marker = _marker;
    if (marker != null) {
      marker.setPosition(position);
    } else {
      final next = NMarker(id: 'manual-marking', position: position);
      _marker = next;
      await controller.addOverlay(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final positions = widget.segments.expand((segment) => segment).toList();
    return Listener(
      onPointerDown: (event) => _lastTapPosition = event.localPosition,
      onPointerUp: (event) async {
        final start = _lastTapPosition;
        final controller = _controller;
        if (start == null || controller == null) return;
        if ((start - event.localPosition).distance > 8) return;
        final position = await controller.screenLocationToLatLng(
          NPoint(event.localPosition.dx, event.localPosition.dy),
        );
        await _select(position);
      },
      child: NaverMap(
        options: NaverMapViewOptions(
          initialCameraPosition: NCameraPosition(
            target: positions.first,
            zoom: 16,
          ),
          locationButtonEnable: false,
          rotationGesturesEnable: false,
          tiltGesturesEnable: false,
        ),
        onMapReady: (controller) async {
          _controller = controller;
          try {
            for (final (index, segment) in widget.segments.indexed) {
              await controller.addOverlay(
                NPolylineOverlay(
                  id: 'manual-route-$index',
                  coords: segment,
                  color: const Color(0xFF4CAF50),
                  width: 4,
                ),
              );
            }
            await controller.updateCamera(
              NCameraUpdate.fitBounds(
                NLatLngBounds.from(positions),
                padding: const EdgeInsets.all(30),
              ),
            );
          } catch (_) {
            // The sheet may close before the map finishes loading.
          }
        },
        onMapTapped: (_, position) => _select(position),
      ),
    );
  }
}
