import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../dog/data/models/dog_model.dart';
import '../../../dog/domain/providers/dog_provider.dart';
import '../../data/models/walk_model.dart';
import '../../domain/breed_walk_guide.dart';
import '../../domain/providers/walk_active_provider.dart';
import '../../domain/providers/walk_provider.dart';
import 'walk_detail_screen.dart';
import 'walk_history_screen.dart';

class WalkScreen extends ConsumerStatefulWidget {
  const WalkScreen({super.key});

  @override
  ConsumerState<WalkScreen> createState() => _WalkScreenState();
}

class _WalkScreenState extends ConsumerState<WalkScreen> {
  bool _isStarting = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    final walkState = ref.watch(walkActiveProvider);
    final isPaused = walkState.status == WalkStatus.paused;
    final isActive = walkState.status == WalkStatus.inProgress || isPaused;
    final title = isPaused
        ? '잠시 쉬어가고 있어요'
        : isActive
        ? '함께 걷는 시간을 기록해요'
        : '오늘은 어떤 길이 궁금할까요?';

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F9F5),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 76, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const WalkHistoryScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.history),
                    label: const Text('산책 기록'),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: CircleAvatar(
                    radius: 44,
                    backgroundColor: const Color(0xFFE5F1E2),
                    child: Icon(
                      isPaused ? Icons.pause_rounded : Icons.pets,
                      size: 42,
                      color: const Color(0xFF4CAF50),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isPaused
                      ? '시간과 경로 기록을 잠시 멈췄어요.\n준비되면 다시 걸어볼까요?'
                      : isActive
                      ? '화면을 계속 보지 않아도 괜찮아요.\n걸어온 길은 산책을 마친 뒤 확인해요.'
                      : '강아지가 궁금해하는 길을 함께 걸어요.\n시작을 누르면 시간과 경로를 기록해요.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54, height: 1.6),
                ),
                if (walkState.selectedDogs.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    walkState.selectedDogs.map((dog) => dog.name).join(' · '),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 32),
                if (isActive) ...[
                  _StatsCard(walkState: walkState),
                  const SizedBox(height: 16),
                  Text(
                    isPaused
                        ? '일시정지 중'
                        : walkState.points.isEmpty
                        ? '위치 신호를 기다리고 있어요'
                        : '산책 경로를 기록하고 있어요',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  const SizedBox(height: 32),
                ],
                if (_isStarting)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else
                  _ControlButtons(
                    walkState: walkState,
                    onStart: () => _startWalkWithDogPicker(context),
                    onPause: () =>
                        ref.read(walkActiveProvider.notifier).pauseWalk(),
                    onResume: () =>
                        ref.read(walkActiveProvider.notifier).resumeWalk(),
                    onComplete: () => _confirmComplete(context),
                  ),
                const SizedBox(height: 20),
                const Text(
                  '산책이 끝나면 시간 · 거리 · 예상 칼로리와\n걸어온 경로를 확인할 수 있어요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _startWalkWithDogPicker(BuildContext context) async {
    if (_isStarting) return;
    setState(() => _isStarting = true);
    try {
      final dogs = await ref.read(myDogsProvider.future);
      if (!context.mounted) return;
      List<Dog> selected = dogs;
      if (dogs.length > 1) {
        final picked = await showModalBottomSheet<List<Dog>>(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => _DogPickerSheet(dogs: dogs),
        );
        if (picked == null || picked.isEmpty) return;
        selected = picked;
      }
      if (!mounted) return;
      await ref.read(walkActiveProvider.notifier).startWalk(dogs: selected);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('산책을 시작하지 못했어요. 연결 상태를 확인하고 다시 시도해주세요.')),
      );
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
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
              backgroundColor: const Color(0xFF4CAF50),
            ),
            child: const Text('완료', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final notifier = ref.read(walkActiveProvider.notifier);
      final walkState = ref.read(walkActiveProvider);
      WalkDetail? completedDetail;
      try {
        completedDetail = await notifier.completeWalk();
      } catch (_) {
        if (!context.mounted) return;
        final retry = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('저장 실패'),
            content: const Text(
              '네트워크 문제로 산책 기록 저장에 실패했습니다.\n다시 시도하시겠어요?\n(경로 데이터는 유지됩니다)',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                ),
                child: const Text('재시도', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        if (retry == true && mounted) {
          // ignore: use_build_context_synchronously
          _confirmComplete(context);
        }
        return;
      }
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      final openHistory = await _showWalkResult(context, walkState);
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      await _showMarkingSpotCandidates(context);
      notifier.resetWalk();
      // walkHistoryProvider + 파생 프로바이더 모두 명시적으로 무효화
      // (홈 탭이 트리에 없을 때 cascade가 동작 안 할 수 있으므로 직접 지정)
      ref.invalidate(walkHistoryProvider);
      ref.invalidate(todayWalkStatsProvider);
      ref.invalidate(todayMeetsProvider);
      ref.invalidate(todayDogCaloriesProvider);
      if (openHistory && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => completedDetail != null
                ? WalkDetailScreen(sessionId: completedDetail.id)
                : const WalkHistoryScreen(),
          ),
        );
      }
    }
  }

  Future<bool> _showWalkResult(
    BuildContext context,
    WalkState walkState,
  ) async {
    final distance = walkState.distanceMeters;
    final seconds = walkState.elapsedSeconds;
    final minutes = seconds ~/ 60;
    final distanceKm = distance / 1000;

    final dogs = walkState.selectedDogs;

    // 다견: 가장 운동 제한이 낮은 강아지 기준으로 가이드 (과운동 방지)
    final guide = dogs.isEmpty
        ? getWalkGuide()
        : dogs
              .map((d) => getWalkGuide(breed: d.breed, weightKg: d.weightKg))
              .reduce((a, b) => a.maxDistanceKm < b.maxDistanceKm ? a : b);

    // 칼로리: 모든 강아지 합산
    final calories = dogs.isEmpty
        ? (minutes * 5.0 * 0.3).round()
        : dogs
              .map((d) => (minutes * (d.weightKg ?? 5.0) * 0.3).round())
              .reduce((a, b) => a + b);

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

    final openHistory = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                achieved ? '🎉' : '🐾',
                style: const TextStyle(fontSize: 48),
              ),
              const SizedBox(height: 8),
              Text(
                achieved ? '권장 산책 달성!' : '산책 완료!',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (dogs.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '${dogs.map((d) => d.name).join(', ')} · ${guide.sizeLabel} 기준',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _ResultItem(
                    label: '거리',
                    value: distanceStr,
                    icon: Icons.route,
                  ),
                  _ResultItem(label: '시간', value: timeStr, icon: Icons.timer),
                  _ResultItem(
                    label: '칼로리',
                    value: '${calories}kcal',
                    icon: Icons.local_fire_department,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // 권장 가이드 박스
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
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
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                    if (!achieved) ...[
                      const SizedBox(height: 4),
                      Text(
                        achieved ? '' : '오늘은 조금 부족했어요. 내일 더 함께해요! 💪',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(ctx, true),
                      icon: const Icon(Icons.history),
                      label: const Text('기록 보기'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4CAF50),
                        side: const BorderSide(color: Color(0xFF4CAF50)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        '확인',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return openHistory ?? false;
  }

  Future<void> _showMarkingSpotCandidates(BuildContext context) async {
    final state = ref.read(walkActiveProvider);
    final candidates = state.markingSpotCandidates;
    if (candidates.isEmpty || state.selectedDogs.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
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
                        '마킹 스팟 후보',
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
                  '산책 중 잠시 머문 곳이에요. 맞는 곳만 공유해주세요.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 12),
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
                        dwellText: candidate.dwellText,
                        nearbyVisitCount: candidate.nearbyVisitCount,
                        onShare: () async {
                          try {
                            await ref
                                .read(walkActiveProvider.notifier)
                                .shareMarkingSpot(candidate);
                            if (!itemContext.mounted) return;
                            ScaffoldMessenger.of(itemContext).showSnackBar(
                              const SnackBar(content: Text('발자국을 남겼어요')),
                            );
                          } catch (_) {
                            if (!itemContext.mounted) return;
                            ScaffoldMessenger.of(itemContext).showSnackBar(
                              const SnackBar(content: Text('발자국 저장에 실패했습니다')),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('나중에 할게요'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MarkingCandidateTile extends StatelessWidget {
  final int index;
  final String dwellText;
  final int nearbyVisitCount;
  final Future<void> Function() onShare;

  const _MarkingCandidateTile({
    required this.index,
    required this.dwellText,
    required this.nearbyVisitCount,
    required this.onShare,
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
                  '$dwellText 머문 곳',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  nearbyVisitCount > 0
                      ? '근처에 $nearbyVisitCount개의 발자국이 있어요'
                      : '새로운 마킹 스팟이에요',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onShare,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
            child: const Text('남기기'),
          ),
        ],
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
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(label: '산책 시간', value: walkState.elapsedText),
          _divider(),
          _StatItem(label: '걸은 거리', value: walkState.distanceText),
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
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _bigButton(
              label: '산책 시작',
              icon: Icons.directions_walk,
              color: const Color(0xFF4CAF50),
              onTap: onStart,
            ),
          ],
        );

      case WalkStatus.inProgress:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                    label: '산책 종료',
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
                label: '계속 걷기',
                icon: Icons.play_arrow,
                color: const Color(0xFF4CAF50),
                onTap: onResume,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _bigButton(
                label: '산책 종료',
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
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF4CAF50),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
      ],
    );
  }
}

class _ResultItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _ResultItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF4CAF50), size: 28),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF212121),
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}

class _DogPickerSheet extends StatefulWidget {
  final List<Dog> dogs;
  const _DogPickerSheet({required this.dogs});

  @override
  State<_DogPickerSheet> createState() => _DogPickerSheetState();
}

class _DogPickerSheetState extends State<_DogPickerSheet> {
  late final Set<int> _selected;

  @override
  void initState() {
    super.initState();
    // 강아지가 1마리면 기본 선택
    _selected = widget.dogs.length == 1 ? {widget.dogs.first.id} : {};
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 32 + bottomPadding),
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
            '여러 마리를 동시에 선택할 수 있어요',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 12),
          ...widget.dogs.map((dog) {
            final isSelected = _selected.contains(dog.id);
            return GestureDetector(
              onTap: () => setState(() {
                if (isSelected) {
                  _selected.remove(dog.id);
                } else {
                  _selected.add(dog.id);
                }
              }),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF4CAF50).withValues(alpha: 0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFEEEEEE),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(
                        0xFF4CAF50,
                      ).withValues(alpha: 0.15),
                      child: Text(
                        dog.name.isNotEmpty ? dog.name[0] : '🐶',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4CAF50),
                        ),
                      ),
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
                          Text(
                            dog.breed ?? '견종 미등록',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Checkbox(
                      value: isSelected,
                      activeColor: const Color(0xFF4CAF50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onChanged: (_) => setState(() {
                        if (isSelected) {
                          _selected.remove(dog.id);
                        } else {
                          _selected.add(dog.id);
                        }
                      }),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _selected.isEmpty
                  ? null
                  : () {
                      final picked = widget.dogs
                          .where((d) => _selected.contains(d.id))
                          .toList();
                      Navigator.pop(context, picked);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                disabledBackgroundColor: Colors.grey[300],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                _selected.isEmpty
                    ? '강아지를 선택하세요'
                    : '${_selected.length}마리와 산책 시작',
                style: const TextStyle(
                  fontSize: 16,
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
