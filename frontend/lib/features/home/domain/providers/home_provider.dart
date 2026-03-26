import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user_profile_model.dart';
import '../../data/repositories/home_repository.dart';

final userProfileProvider = FutureProvider<UserProfile>((ref) async {
  return ref.watch(homeRepositoryProvider).getMyProfile();
});
