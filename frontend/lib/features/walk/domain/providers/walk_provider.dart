import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../dog/domain/providers/dog_provider.dart';
import '../../data/models/walk_model.dart';
import '../../data/repositories/walk_repository.dart';

final walkHistoryProvider = FutureProvider<List<WalkSession>>((ref) async {
  return ref.watch(walkRepositoryProvider).getHistory(size: 100);
});

// 이번 달 산책 통계
final monthlyWalkStatsProvider = FutureProvider<MonthlyWalkStats>((ref) async {
  final history = await ref.watch(walkHistoryProvider.future);
  final now = DateTime.now();

  final monthlySessions = history.where((s) {
    if (s.startedAt == null) return false;
    final started = DateTime.parse(s.startedAt!);
    return started.year == now.year &&
        started.month == now.month &&
        s.status == 'COMPLETED';
  }).toList();

  return MonthlyWalkStats(
    totalDistanceMeters:
        monthlySessions.fold(0, (sum, s) => sum + s.distanceMeters),
    totalDurationSeconds:
        monthlySessions.fold(0, (sum, s) => sum + s.durationSeconds),
    walkCount: monthlySessions.length,
    month: now.month,
  );
});

// 오늘 만난 강아지들 (오늘 완료된 모든 세션 집계)
final todayMeetsProvider = FutureProvider<List<WalkMeet>>((ref) async {
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

  if (todaySessions.isEmpty) return [];

  final repo = ref.watch(walkRepositoryProvider);
  final results = await Future.wait(
    todaySessions.map((s) => repo.getMeets(s.id)),
  );

  return results.expand((list) => list).toList();
});

// 강아지별 오늘 소모 칼로리 (dogId -> kcal)
// 세션에 dogs가 있으면 참여 강아지에만 귀속, 없으면(구버전) 전체 강아지에 귀속
final todayDogCaloriesProvider = FutureProvider<Map<int, int>>((ref) async {
  final history = await ref.watch(walkHistoryProvider.future);
  final dogs = await ref.watch(myDogsProvider.future);
  final today = DateTime.now();

  final todaySessions = history.where((s) {
    if (s.startedAt == null) return false;
    final started = DateTime.parse(s.startedAt!);
    return started.year == today.year &&
        started.month == today.month &&
        started.day == today.day &&
        s.status == 'COMPLETED';
  }).toList();

  final dogById = {for (final d in dogs) d.id: d};
  final result = <int, int>{};

  void addCalories(int dogId, double weightKg, double minutes) {
    final kcal = (minutes * weightKg * 0.3).round();
    result[dogId] = (result[dogId] ?? 0) + kcal;
  }

  for (final session in todaySessions) {
    final minutes = session.durationSeconds / 60.0;
    if (session.dogs.isNotEmpty) {
      for (final sd in session.dogs) {
        final dog = dogById[sd.id];
        if (dog != null) addCalories(dog.id, dog.weightKg ?? 5.0, minutes);
      }
    } else {
      for (final dog in dogs) {
        addCalories(dog.id, dog.weightKg ?? 5.0, minutes);
      }
    }
  }

  return result;
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
