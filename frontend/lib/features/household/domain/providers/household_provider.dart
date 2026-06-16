import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/storage/local_cache.dart';
import '../../data/models/household_model.dart';
import '../../data/repositories/household_repository.dart';

const _cacheKey = 'my_household';

final myHouseholdProvider = FutureProvider<Household?>((ref) async {
  // 1. 캐시에서 즉시 반환
  final cached = await LocalCache.read(_cacheKey);
  if (cached != null) {
    // 백그라운드에서 갱신 (stale-while-revalidate)
    Future.microtask(() async {
      try {
        final fresh = await ref.read(householdRepositoryProvider).getMyHousehold();
        await LocalCache.write(_cacheKey, _householdToJson(fresh));
        ref.invalidateSelf();
      } catch (e) {
        // 404 = 가구 없음 → 캐시 삭제
        await clearHouseholdCache();
        ref.invalidateSelf();
      }
    });
    return Household.fromJson(cached as Map<String, dynamic>);
  }

  // 2. 캐시 없으면 서버에서 가져와서 저장
  try {
    final household = await ref.read(householdRepositoryProvider).getMyHousehold();
    await LocalCache.write(_cacheKey, _householdToJson(household));
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
          .map((m) => {
                'userId': m.userId,
                'nickname': m.nickname,
                'profileImage': m.profileImage,
                'role': m.role,
              })
          .toList(),
    };

Future<void> clearHouseholdCache() => LocalCache.remove(_cacheKey);
