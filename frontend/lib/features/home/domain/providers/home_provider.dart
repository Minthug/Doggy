import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../data/models/user_profile_model.dart';
import '../../data/repositories/home_repository.dart';

final userProfileProvider = FutureProvider<UserProfile>((ref) async {
  return ref.watch(homeRepositoryProvider).getMyProfile();
});

final walkIndexProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(homeRepositoryProvider);
  try {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return repo.getWalkIndex();
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
    ).timeout(const Duration(seconds: 5));
    return repo.getWalkIndex(lat: pos.latitude, lng: pos.longitude);
  } catch (_) {
    return repo.getWalkIndex();
  }
});

final walkForecastProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final repo = ref.watch(homeRepositoryProvider);
  try {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return repo.getWalkForecast();
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
    ).timeout(const Duration(seconds: 5));
    return repo.getWalkForecast(lat: pos.latitude, lng: pos.longitude);
  } catch (_) {
    return repo.getWalkForecast();
  }
});
