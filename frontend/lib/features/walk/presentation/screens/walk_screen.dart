import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../dog/data/models/dog_model.dart';
import '../../../dog/domain/providers/dog_provider.dart';
import '../../domain/breed_walk_guide.dart';
import '../../domain/providers/walk_active_provider.dart';
import '../../domain/providers/walk_provider.dart';

class WalkScreen extends ConsumerStatefulWidget {
  const WalkScreen({super.key});

  @override
  ConsumerState<WalkScreen> createState() => _WalkScreenState();
}

class _WalkScreenState extends ConsumerState<WalkScreen> {
  NaverMapController? _mapController;
  int _lastDrawnPointCount = 0;
  bool _followCamera = true;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  @override
  void dispose() {
    _mapController = null;
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final notifier = ref.read(walkActiveProvider.notifier);
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowUp:
        notifier.moveByKey(WalkActiveNotifier.stepLat, 0);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        notifier.moveByKey(-WalkActiveNotifier.stepLat, 0);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        notifier.moveByKey(0, -WalkActiveNotifier.stepLng);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        notifier.moveByKey(0, WalkActiveNotifier.stepLng);
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  Future<void> _requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
  }

  @override
  Widget build(BuildContext context) {
    final walkState = ref.watch(walkActiveProvider);

    // 위치 업데이트 시: 폴리라인은 항상 갱신, 카메라는 팔로우 모드일 때만 이동
    ref.listen(walkActiveProvider, (prev, next) {
      if (!mounted || _mapController == null) return;
      if (next.currentPosition != null) {
        _updateRoute(next);
        if (_followCamera) {
          final pos = next.currentPosition!;
          _mapController!.updateCamera(
            NCameraUpdate.scrollAndZoomTo(
              target: NLatLng(pos.latitude, pos.longitude),
              zoom: 17,
            ),
          );
        }
      }
    });

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 지도
          NaverMap(
            options: const NaverMapViewOptions(
              locationButtonEnable: true,
              consumeSymbolTapEvents: false,
            ),
            onMapReady: (controller) {
              _mapController = controller;
              _moveToCurrentLocation();
            },
            // 사용자가 직접 지도를 움직이면(animated=false) 팔로우 모드 해제
            onCameraChange: (position, animated) {
              if (!animated && _followCamera) {
                setState(() => _followCamera = false);
              }
            },
          ),

          // 상단 통계
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: _StatsCard(walkState: walkState),
          ),

          // 내 위치 버튼 (팔로우 모드 아닐 때 강조 표시)
          Positioned(
            bottom: 120,
            right: 16,
            child: FloatingActionButton.small(
              onPressed: _moveToCurrentLocation,
              backgroundColor: _followCamera ? const Color(0xFF4CAF50) : Colors.white,
              child: Icon(
                _followCamera ? Icons.my_location : Icons.location_searching,
                color: _followCamera ? Colors.white : const Color(0xFF4CAF50),
              ),
            ),
          ),

          // 하단 버튼
          Positioned(
            bottom: 32,
            left: 16,
            right: 16,
            child: _ControlButtons(
              walkState: walkState,
              onStart: () => _startWalkWithDogPicker(context),
              onSimulate: () => _startSimulatedWalkWithDogPicker(context),
              onPause: () => ref.read(walkActiveProvider.notifier).pauseWalk(),
              onResume: () =>
                  ref.read(walkActiveProvider.notifier).resumeWalk(),
              onComplete: () => _confirmComplete(context),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Future<void> _startWalkWithDogPicker(BuildContext context) async {
    final dogs = await ref.read(myDogsProvider.future).catchError((_) => <Dog>[]);

    if (!mounted) return;

    Dog? selected;
    if (dogs.isEmpty) {
      // 강아지 없으면 바로 시작
      ref.read(walkActiveProvider.notifier).startWalk();
      return;
    } else if (dogs.length == 1) {
      selected = dogs.first;
    } else {
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      selected = await showModalBottomSheet<Dog>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => _DogPickerSheet(dogs: dogs),
      );
      if (selected == null) return; // 취소
    }

    ref.read(walkActiveProvider.notifier).startWalk(dog: selected);
  }

  Future<void> _startSimulatedWalkWithDogPicker(BuildContext context) async {
    final dogs = await ref.read(myDogsProvider.future).catchError((_) => <Dog>[]);

    if (!mounted) return;

    Dog? selected;
    if (dogs.isEmpty) {
      ref.read(walkActiveProvider.notifier).startSimulatedWalk();
      return;
    } else if (dogs.length == 1) {
      selected = dogs.first;
    } else {
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      selected = await showModalBottomSheet<Dog>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => _DogPickerSheet(dogs: dogs),
      );
      if (selected == null) return;
    }

    ref.read(walkActiveProvider.notifier).startSimulatedWalk(dog: selected);
  }

  Future<void> _moveToCurrentLocation() async {
    setState(() => _followCamera = true); // 팔로우 모드 복구
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted || _mapController == null) return;
      _mapController!.updateCamera(
        NCameraUpdate.scrollAndZoomTo(
          target: NLatLng(position.latitude, position.longitude),
          zoom: 17,
        ),
      );
    } catch (_) {
      if (!mounted || _mapController == null) return;
      _mapController!.updateCamera(
        NCameraUpdate.scrollAndZoomTo(
          target: const NLatLng(37.218392, 126.944858),
          zoom: 15,
        ),
      );
    }
  }

  void _updateRoute(WalkState state) {
    if (state.points.length < 2 || _mapController == null) return;

    // 5포인트마다 한 번씩만 폴리라인 갱신 (매 업데이트마다 전체 좌표 재생성 방지)
    if (state.points.length - _lastDrawnPointCount < 5) return;
    _lastDrawnPointCount = state.points.length;

    final coords = state.points.map((p) => NLatLng(p.lat, p.lng)).toList();
    final polyline = NPolylineOverlay(
      id: 'walk_route',
      coords: coords,
      color: const Color(0xFF4CAF50),
      width: 5,
    );
    _mapController!.addOverlay(polyline);
  }

  Future<void> _confirmComplete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('산책 완료'),
        content: const Text('산책을 완료할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50)),
            child:
                const Text('완료', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final notifier = ref.read(walkActiveProvider.notifier);
      final walkState = ref.read(walkActiveProvider);
      try {
        await notifier.completeWalk();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('산책 저장에 실패했습니다. 다시 시도해주세요.')),
          );
        }
        return;
      }
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      await _showWalkResult(context, walkState);
      notifier.resetWalk();
      // walkHistoryProvider + 파생 프로바이더 모두 명시적으로 무효화
      // (홈 탭이 트리에 없을 때 cascade가 동작 안 할 수 있으므로 직접 지정)
      ref.invalidate(walkHistoryProvider);
      ref.invalidate(todayWalkStatsProvider);
      ref.invalidate(todayMeetsProvider);
    }
  }

  Future<void> _showWalkResult(BuildContext context, WalkState walkState) async {
    final distance = walkState.distanceMeters;
    final seconds = walkState.elapsedSeconds;
    final minutes = seconds ~/ 60;
    final distanceKm = distance / 1000;

    final dog = walkState.selectedDog;
    final guide = getWalkGuide(
      breed: dog?.breed,
      weightKg: dog?.weightKg,
    );

    // 칼로리: 체중 기반 (없으면 5kg 기준)
    final weightKg = dog?.weightKg ?? 5.0;
    final calories = (minutes * weightKg * 0.3).round();

    final distanceStr = distance >= 1000
        ? '${distanceKm.toStringAsFixed(2)} km'
        : '${distance.toStringAsFixed(0)} m';

    final timeStr = minutes >= 60
        ? '${minutes ~/ 60}시간 ${minutes % 60}분'
        : '$minutes분 ${seconds % 60}초';

    // 권장 달성 여부
    final metDistance = distanceKm >= guide.minDistanceKm;
    final metTime = minutes >= guide.minMinutes;
    final achieved = metDistance && metTime;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(achieved ? '🎉' : '🐾',
                  style: const TextStyle(fontSize: 48)),
              const SizedBox(height: 8),
              Text(
                achieved ? '권장 산책 달성!' : '산책 완료!',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              if (dog != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${dog.name} · ${guide.sizeLabel}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _ResultItem(
                      label: '거리', value: distanceStr, icon: Icons.route),
                  _ResultItem(
                      label: '시간', value: timeStr, icon: Icons.timer),
                  _ResultItem(
                      label: '칼로리',
                      value: '${calories}kcal',
                      icon: Icons.local_fire_department),
                ],
              ),
              const SizedBox(height: 20),
              // 권장 가이드 박스
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: achieved
                      ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${guide.sizeLabel} 일일 권장',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: achieved
                            ? const Color(0xFF4CAF50)
                            : Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '거리 ${guide.distanceRange}  ·  시간 ${guide.timeRange}',
                      style: const TextStyle(
                          fontSize: 13, color: Colors.black87),
                    ),
                    if (!achieved) ...[
                      const SizedBox(height: 4),
                      Text(
                        achieved
                            ? ''
                            : '오늘은 조금 부족했어요. 내일 더 함께해요! 💪',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.orange),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('확인',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 상단 통계 카드
class _StatsCard extends StatelessWidget {
  final WalkState walkState;
  const _StatsCard({required this.walkState});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.1), blurRadius: 10),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(label: '거리', value: walkState.distanceText),
          _divider(),
          _StatItem(label: '시간', value: walkState.elapsedText),
        ],
      ),
    );
  }

  Widget _divider() =>
      Container(height: 40, width: 1, color: const Color(0xFFEEEEEE));
}

// 하단 컨트롤 버튼
class _ControlButtons extends StatelessWidget {
  final WalkState walkState;
  final VoidCallback onStart;
  final VoidCallback onSimulate;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onComplete;

  const _ControlButtons({
    required this.walkState,
    required this.onStart,
    required this.onSimulate,
    required this.onPause,
    required this.onResume,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    switch (walkState.status) {
      case WalkStatus.idle:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _bigButton(
              label: '산책 시작',
              icon: Icons.directions_walk,
              color: const Color(0xFF4CAF50),
              onTap: onStart,
            ),
            // TODO(test): 시뮬레이션 버튼 — 필요 시 주석 해제
            // const SizedBox(height: 8),
            // SizedBox(
            //   width: double.infinity,
            //   height: 44,
            //   child: OutlinedButton.icon(
            //     onPressed: onSimulate,
            //     icon: const Icon(Icons.route, size: 18),
            //     label: const Text('시뮬레이션 테스트',
            //         style: TextStyle(fontSize: 14)),
            //     style: OutlinedButton.styleFrom(
            //       foregroundColor: Colors.grey[600],
            //       side: BorderSide(color: Colors.grey[350]!),
            //       shape: RoundedRectangleBorder(
            //           borderRadius: BorderRadius.circular(12)),
            //     ),
            //   ),
            // ),
          ],
        );

      case WalkStatus.inProgress:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // if (walkState.isSimulating)
            //   Padding(
            //     padding: const EdgeInsets.only(bottom: 8),
            //     child: Row(
            //       mainAxisAlignment: MainAxisAlignment.center,
            //       children: [
            //         Icon(Icons.route, size: 14, color: Colors.orange[700]),
            //         const SizedBox(width: 4),
            //         Text('시뮬레이션 모드',
            //             style: TextStyle(
            //                 fontSize: 12,
            //                 color: Colors.orange[700],
            //                 fontWeight: FontWeight.bold)),
            //       ],
            //     ),
            //   ),
            Row(
              children: [
                Expanded(
                  child: _bigButton(
                    label: '일시정지',
                    icon: Icons.pause,
                    color: Colors.orange,
                    onTap: onPause,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _bigButton(
                    label: '완료',
                    icon: Icons.stop,
                    color: Colors.redAccent,
                    onTap: onComplete,
                  ),
                ),
              ],
            ),
          ],
        );

      case WalkStatus.paused:
        return Row(
          children: [
            Expanded(
              child: _bigButton(
                label: '재개',
                icon: Icons.play_arrow,
                color: const Color(0xFF4CAF50),
                onTap: onResume,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _bigButton(
                label: '완료',
                icon: Icons.stop,
                color: Colors.redAccent,
                onTap: onComplete,
              ),
            ),
          ],
        );

      case WalkStatus.completed:
        return _bigButton(
          label: '새 산책 시작',
          icon: Icons.refresh,
          color: const Color(0xFF4CAF50),
          onTap: onStart,
        );
    }
  }

  Widget _bigButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 60,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label,
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4CAF50))),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(color: Colors.grey, fontSize: 13)),
      ],
    );
  }
}

class _ResultItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _ResultItem({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF4CAF50), size: 28),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF212121))),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}

class _DogPickerSheet extends StatelessWidget {
  final List<Dog> dogs;
  const _DogPickerSheet({required this.dogs});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '누구와 산책할까요?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            '강아지를 선택하면 맞춤 권장 거리를 알려드려요',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ...dogs.map((dog) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                  child: Text(
                    dog.name.isNotEmpty ? dog.name[0] : '🐶',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4CAF50)),
                  ),
                ),
                title: Text(dog.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(dog.breed ?? '견종 미등록',
                    style: const TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(context, dog),
              )),
        ],
      ),
    );
  }
}
