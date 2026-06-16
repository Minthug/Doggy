import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/storage/local_cache.dart';
import '../../data/models/dog_model.dart';
import '../../data/repositories/dog_repository.dart';

const _cacheKey = 'my_dogs';

final myDogsProvider = FutureProvider<List<Dog>>((ref) async {
  // 1. 캐시에서 즉시 반환
  final cached = await LocalCache.read(_cacheKey);
  if (cached != null) {
    // 백그라운드에서 갱신 (stale-while-revalidate)
    Future.microtask(() async {
      try {
        final fresh = await ref.read(dogRepositoryProvider).getMyDogs();
        await LocalCache.write(_cacheKey, fresh.map(_dogToJson).toList());
        ref.invalidateSelf();
      } catch (_) {}
    });
    return (cached as List).map((e) => Dog.fromJson(e as Map<String, dynamic>)).toList();
  }

  // 2. 캐시 없으면 서버에서 가져와서 저장
  final dogs = await ref.read(dogRepositoryProvider).getMyDogs();
  await LocalCache.write(_cacheKey, dogs.map(_dogToJson).toList());
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

Future<void> clearDogsCache() => LocalCache.remove(_cacheKey);
