import '../../../../core/providers/household_change_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/storage/local_cache.dart';
import '../../data/models/dog_model.dart';
import '../../data/repositories/dog_repository.dart';

const _cacheKey = 'my_dogs';

final myDogsProvider = FutureProvider<List<Dog>>((ref) async {
  var disposed = false;
  ref.onDispose(() => disposed = true);
  final change = ref.watch(householdChangeProvider);
  if (change != null) {
    // Riverpod otherwise retains the previous household's data on errors.
    ref.state = const AsyncData(<Dog>[]);
    ref.state = const AsyncLoading();
    await change;
  }
  if (disposed) return [];
  final cacheKey = await LocalCache.currentUserKey(_cacheKey);
  if (cacheKey == null || disposed) return [];
  // 1. 캐시에서 즉시 반환
  final cached = await LocalCache.read(cacheKey);
  if (cached != null) {
    // 백그라운드에서 갱신 (stale-while-revalidate)
    Future.microtask(() async {
      try {
        final fresh = await ref.read(dogRepositoryProvider).getMyDogs();
        if (!disposed) {
          await LocalCache.write(cacheKey, fresh.map(_dogToJson).toList());
        }
      } catch (_) {}
    });
    return (cached as List)
        .map((e) => Dog.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // 2. 캐시 없으면 서버에서 가져와서 저장
  final dogs = await ref.read(dogRepositoryProvider).getMyDogs();
  if (!disposed) {
    await LocalCache.write(cacheKey, dogs.map(_dogToJson).toList());
  }
  return dogs;
});

Map<String, dynamic> _dogToJson(Dog d) => {
  'id': d.id,
  'name': d.name,
  'breed': d.breed,
  'profileImage': d.profileImage,
  'gender': d.gender,
  'isNeutered': d.isNeutered,
  'weightKg': d.weightKg,
  'birthDate': d.birthDate?.toIso8601String().split('T').first,
  'warnings': d.warnings,
  'isFavorited': d.isFavorited,
};

Future<void> clearDogsCache() async {
  final key = await LocalCache.currentUserKey(_cacheKey);
  if (key != null) await LocalCache.remove(key);
  await LocalCache.remove(_cacheKey);
}
