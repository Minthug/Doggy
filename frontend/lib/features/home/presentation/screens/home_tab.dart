import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/domain/providers/auth_provider.dart';
import '../../../dog/data/models/dog_model.dart';
import '../../../dog/domain/providers/dog_provider.dart';
import '../../../dog/presentation/screens/dog_register_screen.dart';
import '../../../walk/data/models/walk_model.dart';
import '../../../walk/domain/providers/walk_provider.dart';
import '../../domain/providers/home_provider.dart';
import '../../../walk/presentation/screens/walk_history_screen.dart';
import 'main_screen.dart';

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '🐶 Doggy',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.grey),
            onPressed: () => ref.read(authActionProvider).logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(userProfileProvider);
          ref.invalidate(myDogsProvider);
          ref.invalidate(todayWalkStatsProvider);
          ref.invalidate(walkIndexProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 인사말
            profileAsync.when(
              data: (p) => _GreetingCard(nickname: p.nickname),
              loading: () => const _GreetingCard(nickname: '...'),
              error: (e, _) => const _GreetingCard(nickname: '사용자'),
            ),
            const SizedBox(height: 16),

            // 반려견 카드
            Consumer(
              builder: (context, ref, _) {
                final dogsAsync = ref.watch(myDogsProvider);
                return dogsAsync.when(
                  data: (dogs) => dogs.isEmpty
                      ? _EmptyDogCard()
                      : _DogListCard(dogs: dogs),
                  loading: () => _DogCardSkeleton(),
                  error: (e, _) => _EmptyDogCard(),
                );
              },
            ),
            const SizedBox(height: 16),

            // 산책 지수
            Consumer(
              builder: (context, ref, _) {
                final walkIndexAsync = ref.watch(walkIndexProvider);
                return walkIndexAsync.when(
                  data: (data) => _WalkIndexCard(data: data),
                  loading: () => const SizedBox.shrink(),
                  error: (e, s) => const SizedBox.shrink(),
                );
              },
            ),
            const SizedBox(height: 16),

            // 오늘 산책 통계
            Consumer(
              builder: (context, ref, _) {
                final statsAsync = ref.watch(todayWalkStatsProvider);
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const WalkHistoryScreen()),
                  ),
                  child: statsAsync.when(
                    data: (stats) => _TodayWalkCard(stats: stats),
                    loading: () => _TodayWalkCard(stats: null),
                    error: (e, _) => _TodayWalkCard(stats: null),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // 산책 시작 버튼
            _StartWalkButton(),
          ],
        ),
      ),
    );
  }
}

// 인사말 카드
class _GreetingCard extends StatelessWidget {
  final String nickname;
  const _GreetingCard({required this.nickname});

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting =
        hour < 12 ? '좋은 아침이에요' : hour < 18 ? '안녕하세요' : '좋은 저녁이에요';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$greeting, $nickname님!',
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            '오늘도 반려견과 즐거운 산책 하세요 🌿',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// 강아지 없을 때
class _EmptyDogCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final registered = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const DogRegisterScreen()),
        );
        if (registered == true) {
          // dog_provider 새로고침은 DogRegisterScreen에서 invalidate 처리
        }
      },
      child: _card(
        child: Row(
          children: [
            _dogIcon(),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('반려견을 등록해주세요',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 4),
                  Text('반려견 정보를 등록하고 함께 산책을 기록해요',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

// 강아지 목록
class _DogListCard extends StatelessWidget {
  final List<Dog> dogs;
  const _DogListCard({required this.dogs});

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('내 반려견',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          ...dogs.map((dog) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    _dogIcon(size: 40),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(dog.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        if (dog.breed != null)
                          Text(dog.breed!,
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// 강아지 카드 스켈레톤
class _DogCardSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _card(
      child: Row(
        children: [
          _dogIcon(),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 120, height: 16, color: Colors.grey[200]),
              const SizedBox(height: 8),
              Container(width: 80, height: 13, color: Colors.grey[200]),
            ],
          ),
        ],
      ),
    );
  }
}

// 오늘 산책 카드
class _TodayWalkCard extends StatelessWidget {
  final TodayWalkStats? stats;
  const _TodayWalkCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('오늘의 산책',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(
                  label: '거리', value: stats?.distanceText ?? '0m'),
              _divider(),
              _StatItem(
                  label: '시간', value: stats?.durationText ?? '0분'),
              _divider(),
              _StatItem(
                  label: '횟수', value: '${stats?.walkCount ?? 0}회'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider() =>
      Container(height: 40, width: 1, color: const Color(0xFFEEEEEE));
}

// 산책 시작 버튼
class _StartWalkButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: () => MainScreen.jumpToTab(context, 1),
        icon: const Icon(Icons.directions_walk),
        label: const Text('산책 시작',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4CAF50),
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

// 산책 지수 카드
class _WalkIndexCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _WalkIndexCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final index = data['index'] as String? ?? 'CAUTION';
    final label = data['label'] as String? ?? '산책 주의';
    final emoji = data['emoji'] as String? ?? '🟡';
    final description = data['description'] as String? ?? '';
    final tmp = data['temperature'] as int? ?? 0;
    final pop = data['precipitationProbability'] as int? ?? 0;
    final pm10Grade = data['pm10Grade'] as String? ?? '보통';
    final pm25Grade = data['pm25Grade'] as String? ?? '보통';
    final precipitation = data['precipitationType'] as String? ?? '없음';

    final Color indexColor = switch (index) {
      'GOOD' => const Color(0xFF4CAF50),
      'AVOID' => const Color(0xFFE53935),
      _ => const Color(0xFFFFA726),
    };

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('오늘의 산책 지수',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: indexColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$emoji $label',
                  style: TextStyle(
                    color: indexColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(description,
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _WeatherItem(icon: Icons.thermostat, label: '기온', value: '$tmp°C'),
              _WeatherItem(icon: Icons.umbrella, label: '강수확률', value: '$pop%'),
              _WeatherItem(icon: Icons.water_drop_outlined, label: '날씨', value: precipitation),
              _WeatherItem(icon: Icons.air, label: '미세먼지', value: pm10Grade),
              _WeatherItem(icon: Icons.grain, label: '초미세먼지', value: pm25Grade),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeatherItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _WeatherItem({required this.icon, required this.label, required this.value});

  Color _valueColor() {
    if (value == '나쁨' || value == '매우나쁨') return const Color(0xFFE53935);
    if (value == '보통') return const Color(0xFFFFA726);
    return Colors.black87;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _valueColor())),
        Text(label,
            style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}

// 공통 카드 위젯
Widget _card({required Widget child}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
      ],
    ),
    child: child,
  );
}

Widget _dogIcon({double size = 56}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: const Color(0xFFE8F5E9),
      borderRadius: BorderRadius.circular(size / 2),
    ),
    child: Icon(Icons.pets,
        color: const Color(0xFF4CAF50), size: size * 0.5),
  );
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4CAF50))),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(color: Colors.grey, fontSize: 13)),
      ],
    );
  }
}
