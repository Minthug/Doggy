import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import '../../data/models/walk_model.dart';
import '../models/route_segments.dart';

Future<bool> showMarkingFeedbackSheet(
  BuildContext context, {
  required List<MarkingSpotCandidate> candidates,
  required String? routeGeoJson,
  required Future<void> Function(Map<String, bool>) onSubmit,
  Widget? mapOverride,
}) async {
  if (candidates.isEmpty) return false;
  final answers = <String, bool>{};
  final mapKey = GlobalKey<_MarkingCandidatesMapState>();
  var submitting = false;

  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.pets, color: Color(0xFF4CAF50)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '마킹한 곳이 있나요?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  '산책 경로에서 고른 최대 3곳이에요. 각 장소를 확인해주세요.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 200,
                    child:
                        mapOverride ??
                        _MarkingCandidatesMap(
                          key: mapKey,
                          candidates: candidates,
                          routeGeoJson: routeGeoJson,
                        ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '지도 번호와 아래 장소 번호를 비교해 주세요.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: candidates.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (itemContext, index) {
                      final candidate = candidates[index];
                      return _MarkingCandidateTile(
                        index: index + 1,
                        timeText: candidate.timeText,
                        dwellText: candidate.dwellText,
                        nearbyVisitCount: candidate.nearbyVisitCount,
                        answer: answers[candidate.candidateKey],
                        onShowOnMap: () =>
                            mapKey.currentState?.focus(candidate),
                        onAnswer: (marked) {
                          setSheetState(
                            () => answers[candidate.candidateKey] = marked,
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: submitting || answers.length != candidates.length
                        ? null
                        : () async {
                            setSheetState(() => submitting = true);
                            try {
                              await onSubmit(answers);
                              if (ctx.mounted) Navigator.pop(ctx, true);
                            } catch (_) {
                              if (ctx.mounted) {
                                setSheetState(() => submitting = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text('저장하지 못했어요. 다시 시도해주세요'),
                                  ),
                                );
                              }
                            }
                          },
                    child: const Text('확인 저장'),
                  ),
                ),
                TextButton(
                  onPressed: submitting ? null : () => Navigator.pop(ctx),
                  child: const Text('이번에는 건너뛰기'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('마킹 확인을 저장했어요')));
  }
  return saved ?? false;
}

class _MarkingCandidatesMap extends StatefulWidget {
  final List<MarkingSpotCandidate> candidates;
  final String? routeGeoJson;

  const _MarkingCandidatesMap({
    super.key,
    required this.candidates,
    required this.routeGeoJson,
  });

  @override
  State<_MarkingCandidatesMap> createState() => _MarkingCandidatesMapState();
}

class _MarkingCandidatesMapState extends State<_MarkingCandidatesMap> {
  NaverMapController? _controller;

  Future<void> focus(MarkingSpotCandidate candidate) async {
    final controller = _controller;
    if (controller == null || !mounted) return;
    try {
      await controller.updateCamera(
        NCameraUpdate.scrollAndZoomTo(
          target: NLatLng(candidate.lat, candidate.lng),
          zoom: 17,
        ),
      );
    } catch (_) {
      // 지도를 닫는 중이면 카메라 이동을 중단한다.
    }
  }

  @override
  Widget build(BuildContext context) {
    final first = widget.candidates.first;
    return NaverMap(
      options: NaverMapViewOptions(
        initialCameraPosition: NCameraPosition(
          target: NLatLng(first.lat, first.lng),
          zoom: 16,
        ),
        locationButtonEnable: false,
        rotationGesturesEnable: false,
        tiltGesturesEnable: false,
      ),
      onMapReady: (controller) async {
        _controller = controller;
        try {
          for (final (index, segment) in parseRouteSegments(
            widget.routeGeoJson,
          ).indexed) {
            if (!mounted) return;
            await controller.addOverlay(
              NPolylineOverlay(
                id: 'candidate-route-$index',
                coords: segment,
                color: const Color(0xFF4CAF50),
                width: 4,
              ),
            );
          }
          final positions = <NLatLng>[];
          for (final (index, candidate) in widget.candidates.indexed) {
            if (!mounted) return;
            final position = NLatLng(candidate.lat, candidate.lng);
            positions.add(position);
            await controller.addOverlay(
              NMarker(
                id: 'candidate-${candidate.candidateKey}',
                position: position,
                caption: NOverlayCaption(text: '${index + 1}번 후보'),
              ),
            );
          }
          if (!mounted) return;
          await controller.updateCamera(
            positions.length == 1
                ? NCameraUpdate.scrollAndZoomTo(
                    target: positions.first,
                    zoom: 17,
                  )
                : NCameraUpdate.fitBounds(
                    NLatLngBounds.from(positions),
                    padding: const EdgeInsets.all(40),
                  ),
          );
        } catch (error) {
          debugPrint('마킹 후보 지도 표시 실패: $error');
        }
      },
    );
  }
}

class _MarkingCandidateTile extends StatelessWidget {
  final int index;
  final String timeText;
  final String dwellText;
  final int nearbyVisitCount;
  final bool? answer;
  final VoidCallback onShowOnMap;
  final ValueChanged<bool> onAnswer;

  const _MarkingCandidateTile({
    required this.index,
    required this.timeText,
    required this.dwellText,
    required this.nearbyVisitCount,
    required this.answer,
    required this.onShowOnMap,
    required this.onAnswer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF4CAF50).withValues(alpha: 0.1),
            foregroundColor: const Color(0xFF4CAF50),
            child: Text('$index'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$timeText 무렵 · $dwellText 머문 곳',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  nearbyVisitCount > 0
                      ? '근처에 $nearbyVisitCount개의 발자국이 있어요'
                      : '새로운 마킹 스팟이에요',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                TextButton.icon(
                  onPressed: onShowOnMap,
                  icon: const Icon(Icons.place_outlined, size: 16),
                  label: const Text('지도에서 보기'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              ChoiceChip(
                label: const Text('했어요'),
                selected: answer == true,
                onSelected: (_) => onAnswer(true),
              ),
              ChoiceChip(
                label: const Text('아니에요'),
                selected: answer == false,
                onSelected: (_) => onAnswer(false),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
