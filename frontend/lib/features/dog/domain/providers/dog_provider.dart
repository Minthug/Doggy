import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/dog_model.dart';
import '../../data/repositories/dog_repository.dart';

final myDogsProvider = FutureProvider<List<Dog>>((ref) async {
  return ref.watch(dogRepositoryProvider).getMyDogs();
});
