import 'package:flutter_riverpod/flutter_riverpod.dart';

// Related reads wait until caches from the previous household have been cleared.
final householdChangeProvider = StateProvider<Future<void>?>((ref) => null);
