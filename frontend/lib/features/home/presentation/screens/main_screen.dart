import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/notifications/fcm_service.dart';
import '../../../../core/notifications/in_app_banner.dart';
import '../../../place/presentation/screens/map_tab.dart';
import '../../../profile/presentation/screens/profile_tab.dart';
import '../../../walk/presentation/screens/walk_screen.dart';
import 'home_tab.dart';

// 탭 인덱스를 홈 탭에서도 제어할 수 있도록 전역 키 사용
final mainScreenKey = GlobalKey<_MainScreenState>();

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key}) : super();

  static void jumpToTab(BuildContext context, int index) {
    mainScreenKey.currentState?.jumpTo(index);
  }

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(fcmServiceProvider).initialize();
    });
  }

  void jumpTo(int index) {
    setState(() => _currentIndex = index);
  }

  final _tabs = const [
    HomeTab(),
    WalkScreen(),
    MapTab(),
    ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _tabs[_currentIndex],
          const BannerLayer(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF4CAF50),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(
              icon: Icon(Icons.directions_walk), label: '산책'),
          BottomNavigationBarItem(icon: Icon(Icons.place), label: '장소'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '프로필'),
        ],
      ),
    );
  }
}

