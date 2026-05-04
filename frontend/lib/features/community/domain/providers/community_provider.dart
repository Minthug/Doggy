import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/community_post_model.dart';
import '../../data/repositories/community_repository.dart';

final selectedPostTypeProvider = StateProvider<PostType?>((ref) => null);

final communityPostsProvider = FutureProvider.autoDispose<List<CommunityPost>>((ref) async {
  final type = ref.watch(selectedPostTypeProvider);
  final repo = ref.watch(communityRepositoryProvider);
  return repo.getPosts(type: type);
});
