import '../../../../core/providers/household_change_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/storage/local_cache.dart';
import '../../data/models/household_model.dart';
import '../../data/repositories/household_repository.dart';

const _cacheKey = 'my_household';

final myHouseholdProvider = FutureProvider<Household?>((ref) async {
  var disposed = false;
  ref.onDispose(() => disposed = true);
  final change = ref.watch(householdChangeProvider);
  if (change != null) {
    // Riverpod otherwise retains the previous household's data on errors.
    ref.state = const AsyncData(null);
    ref.state = const AsyncLoading();
    await change;
  }
  if (disposed) return null;
  final cacheKey = await LocalCache.currentUserKey(_cacheKey);
  if (cacheKey == null || disposed) return null;
  // 1. 캐시에서 즉시 반환
  final cached = await LocalCache.read(cacheKey);
  if (cached != null) {
    // 백그라운드에서 갱신 (stale-while-revalidate)
    Future.microtask(() async {
      try {
        final fresh = await ref
            .read(householdRepositoryProvider)
            .getMyHousehold();
        if (disposed) return;
        await LocalCache.write(cacheKey, _householdToJson(fresh));
        if (!disposed) ref.state = AsyncData(fresh);
      } on DioException catch (e) {
        if (disposed) return;
        if (e.response?.statusCode == 404) {
          await LocalCache.remove(cacheKey);
          if (!disposed) ref.state = const AsyncData(null);
        }
      } catch (_) {}
    });
    return Household.fromJson(cached as Map<String, dynamic>);
  }

  // 2. 캐시 없으면 서버에서 가져와서 저장
  try {
    final household = await ref
        .read(householdRepositoryProvider)
        .getMyHousehold();
    if (!disposed) {
      await LocalCache.write(cacheKey, _householdToJson(household));
    }
    return household;
  } on DioException catch (error) {
    if (error.response?.statusCode == 404) return null;
    rethrow;
  }
});

Map<String, dynamic> _householdToJson(Household h) => {
  'id': h.id,
  'name': h.name,
  'inviteCode': h.inviteCode,
  'members': h.members
      .map(
        (m) => {
          'userId': m.userId,
          'nickname': m.nickname,
          'profileImage': m.profileImage,
          'role': m.role,
        },
      )
      .toList(),
};

Future<void> clearHouseholdCache() async {
  final key = await LocalCache.currentUserKey(_cacheKey);
  if (key != null) await LocalCache.remove(key);
  await LocalCache.remove(_cacheKey);
}
