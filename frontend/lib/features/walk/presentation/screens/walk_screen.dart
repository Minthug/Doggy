import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers/walk_active_provider.dart';

class WalkScreen extends ConsumerStatefulWidget {
  const WalkScreen({super.key});

  @override
  ConsumerState<WalkScreen> createState() => _WalkScreenState();
}

class _WalkScreenState extends ConsumerState<WalkScreen> {
  NaverMapController? _mapController;

  @override
  Widget build(BuildContext context) {
    final walkState = ref.watch(walkActiveProvider);

    // 위치 업데이트 시 지도 카메라 이동
    ref.listen(walkActiveProvider, (prev, next) {
      if (next.currentPosition != null && _mapController != null) {
        final pos = next.currentPosition!;
        _mapController!.updateCamera(
          NCameraUpdate.scrollAndZoomTo(
            target: NLatLng(pos.latitude, pos.longitude),
            zoom: 17,
          ),
        );
        _updateRoute(next);
      }
    });

    return Scaffold(
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
          ),

          // 상단 통계
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: _StatsCard(walkState: walkState),
          ),

          // 하단 버튼
          Positioned(
            bottom: 32,
            left: 16,
            right: 16,
            child: _ControlButtons(
              walkState: walkState,
              onStart: () => ref.read(walkActiveProvider.notifier).startWalk(),
              onPause: () => ref.read(walkActiveProvider.notifier).pauseWalk(),
              onResume: () =>
                  ref.read(walkActiveProvider.notifier).resumeWalk(),
              onComplete: () => _confirmComplete(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _moveToCurrentLocation() async {
    // 초기 위치로 카메라 이동
    _mapController?.updateCamera(
      NCameraUpdate.scrollAndZoomTo(
        target: const NLatLng(37.5665, 126.9780),
        zoom: 15,
      ),
    );
  }

  void _updateRoute(WalkState state) {
    if (state.points.length < 2 || _mapController == null) return;

    // 경로 폴리라인 그리기
    final coords =
        state.points.map((p) => NLatLng(p.lat, p.lng)).toList();

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
      await notifier.completeWalk();
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('산책이 완료됐습니다! 🐾')),
      );
      notifier.resetWalk();
    }
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
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onComplete;

  const _ControlButtons({
    required this.walkState,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    switch (walkState.status) {
      case WalkStatus.idle:
        return _bigButton(
          label: '산책 시작',
          icon: Icons.directions_walk,
          color: const Color(0xFF4CAF50),
          onTap: onStart,
        );

      case WalkStatus.inProgress:
        return Row(
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
