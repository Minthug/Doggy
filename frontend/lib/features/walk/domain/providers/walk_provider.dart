import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/walk_model.dart';
import '../../data/repositories/walk_repository.dart';

final walkHistoryProvider = FutureProvider<List<WalkSession>>((ref) async {
  return ref.watch(walkRepositoryProvider).getHistory();
});

// 오늘 산책 통계만 추출
final todayWalkStatsProvider = FutureProvider<TodayWalkStats>((ref) async {
  final history = await ref.watch(walkHistoryProvider.future);
  final today = DateTime.now();

  final todaySessions = history.where((s) {
    if (s.startedAt == null) return false;
    final started = DateTime.parse(s.startedAt!);
    return started.year == today.year &&
        started.month == today.month &&
        started.day == today.day &&
        s.status == 'COMPLETED';
  }).toList();

  return TodayWalkStats(
    totalDistanceMeters:
        todaySessions.fold(0, (sum, s) => sum + s.distanceMeters),
    totalDurationSeconds:
        todaySessions.fold(0, (sum, s) => sum + s.durationSeconds),
    walkCount: todaySessions.length,
  );
});
