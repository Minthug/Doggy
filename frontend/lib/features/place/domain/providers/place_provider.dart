import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/place_model.dart';
import '../../data/repositories/place_repository.dart';

// 선택된 카테고리 필터
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

// 현재 위치 기반 주변 장소
final nearbyPlacesProvider =
    FutureProvider.family<List<Place>, ({double lat, double lng})>(
        (ref, location) async {
  final category = ref.watch(selectedCategoryProvider);
  return ref.watch(placeRepositoryProvider).findNearby(
        lat: location.lat,
        lng: location.lng,
        radiusMeters: 5000,
        category: category,
      );
});
