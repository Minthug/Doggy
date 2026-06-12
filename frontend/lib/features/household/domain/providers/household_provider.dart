import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/household_model.dart';
import '../../data/repositories/household_repository.dart';

final myHouseholdProvider = FutureProvider<Household?>((ref) async {
  try {
    return await ref.watch(householdRepositoryProvider).getMyHousehold();
  } catch (e) {
    return null;
  }
});
