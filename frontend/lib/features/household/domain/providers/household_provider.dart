import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/storage/local_cache.dart';
import '../../data/models/household_model.dart';
import '../../data/repositories/household_repository.dart';

const _cacheKey = 'my_household';

final myHouseholdProvider = FutureProvider<Household?>((ref) async {
  var disposed = false;
  ref.onDispose(() => disposed = true);
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
        if (!disposed) ref.invalidateSelf();
      } catch (e) {
        if (disposed) return;
        // 404 = 가구 없음 → 캐시 삭제
        await LocalCache.remove(cacheKey);
        if (!disposed) ref.invalidateSelf();
      }
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
  } catch (_) {
    return null;
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
