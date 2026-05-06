import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/notifications/fcm_service.dart';
import '../../../../core/notifications/in_app_banner.dart';
import '../../../community/presentation/screens/community_tab.dart';
import '../../../profile/presentation/screens/profile_tab.dart';
import 'home_tab.dart';
import 'walk_place_tab.dart';

final _currentTabIndexProvider = StateProvider<int>((ref) => 0);

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  static void jumpToTab(BuildContext context, int index) {
    ProviderScope.containerOf(context)
        .read(_currentTabIndexProvider.notifier)
        .state = index;
  }

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(fcmServiceProvider).initialize();
    });
  }

  final _tabs = const [
    HomeTab(),
    WalkPlaceTab(),
    CommunityTab(),
    ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(_currentTabIndexProvider);
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: currentIndex,
            children: _tabs,
          ),
          const BannerLayer(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) =>
            ref.read(_currentTabIndexProvider.notifier).state = index,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF4CAF50),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: '지도'),
          BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: '커뮤니티'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '프로필'),
        ],
      ),
    );
  }
}

