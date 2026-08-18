import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
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
          ref.invalidate(walkHistoryProvider);
          ref.invalidate(todayWalkStatsProvider);
          ref.invalidate(todayDogCaloriesProvider);
          ref.invalidate(walkIndexProvider);
          ref.invalidate(walkForecastProvider);
          ref.invalidate(todayMeetsProvider);
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
                  data: (dogs) =>
                      dogs.isEmpty ? _EmptyDogCard() : _DogListCard(dogs: dogs),
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
                      builder: (_) => const WalkHistoryScreen(),
                    ),
                  ),
                  child: statsAsync.when(
                    data: (stats) => _TodayWalkCard(
                      stats: stats,
                      onViewAll: () => _openWalkHistory(context),
                    ),
                    loading: () => _TodayWalkCard(
                      stats: null,
                      onViewAll: () => _openWalkHistory(context),
                    ),
                    error: (e, _) => _TodayWalkCard(
                      stats: null,
                      onViewAll: () => _openWalkHistory(context),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // 오늘 만난 강아지들
            Consumer(
              builder: (context, ref, _) {
                final meetsAsync = ref.watch(todayMeetsProvider);
                return meetsAsync.when(
                  data: (meets) => _TodayMeetsCard(meets: meets),
                  loading: () => const SizedBox.shrink(),
                  error: (error, stackTrace) => const SizedBox.shrink(),
                );
              },
            ),
            const SizedBox(height: 16),

            // 쇼핑 카테고리 숏컷
            const _ShoppingShortcutsCard(),
            const SizedBox(height: 16),

            // 산책 시작 버튼
            const _WalkActionButtons(),
          ],
        ),
      ),
    );
  }

  static void _openWalkHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WalkHistoryScreen()),
    );
  }
}

// 인사말 카드
class _GreetingCard extends StatelessWidget {
  final String nickname;
  const _GreetingCard({required this.nickname});

  @override
  Widget build(BuildContext context) {
    const greeting = '산책가기 좋은 날이에요';

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
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
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
                  Text(
                    '반려견을 등록해주세요',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '반려견 정보를 등록하고 함께 산책을 기록해요',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
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

// 강아지 목록 — 가로 슬라이더
class _DogListCard extends ConsumerWidget {
  final List<Dog> dogs;
  const _DogListCard({required this.dogs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caloriesAsync = ref.watch(todayDogCaloriesProvider);
    final caloriesMap = caloriesAsync.valueOrNull ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              const Text(
                '내 반려견',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(width: 6),
              Text(
                '${dogs.length}마리',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: dogs.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final dog = dogs[i];
              final burned = caloriesMap[dog.id] ?? 0;
              final recommended = dog.dailyCalories;
              return _DogSliderItem(
                dog: dog,
                burned: burned,
                recommended: recommended,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DogSliderItem extends StatelessWidget {
  final Dog dog;
  final int burned;
  final int? recommended;

  const _DogSliderItem({
    required this.dog,
    required this.burned,
    required this.recommended,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = recommended != null && burned >= recommended!;
    final barColor = isDone ? const Color(0xFF4CAF50) : const Color(0xFFFFA726);
    final ratio = recommended != null
        ? (burned / recommended!).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _dogIcon(size: 36, profileImage: dog.profileImage),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dog.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (dog.breed != null)
                      Text(
                        dog.breed!,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          if (recommended != null) ...[
            Row(
              children: [
                Text(
                  '🔥 ${burned}kcal',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: burned > 0 ? barColor : Colors.grey,
                  ),
                ),
                if (isDone)
                  const Text(
                    ' ✓',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '목표 ${recommended}kcal',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 5,
                backgroundColor: const Color(0xFFEEEEEE),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ] else ...[
            const Text(
              '칼로리 정보 없음',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
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
  final VoidCallback onViewAll;

  const _TodayWalkCard({required this.stats, required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '오늘의 산책',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              TextButton.icon(
                onPressed: onViewAll,
                icon: const Icon(Icons.history, size: 18),
                label: const Text('전체 보기'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF4CAF50),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(label: '거리', value: stats?.distanceText ?? '0m'),
              _divider(),
              _StatItem(label: '시간', value: stats?.durationText ?? '0분'),
              _divider(),
              _StatItem(label: '횟수', value: '${stats?.walkCount ?? 0}회'),
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
class _WalkActionButtons extends StatelessWidget {
  const _WalkActionButtons();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 56,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WalkHistoryScreen()),
              ),
              icon: const Icon(Icons.history),
              label: const Text(
                '산책 기록',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4CAF50),
                side: const BorderSide(color: Color(0xFF4CAF50)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () => MainScreen.jumpToTab(context, 1),
              icon: const Icon(Icons.directions_walk),
              label: const Text(
                '산책 시작',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// 산책 지수 카드
class _WalkIndexCard extends ConsumerWidget {
  final Map<String, dynamic> data;
  const _WalkIndexCard({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = data['index'] as String? ?? 'CAUTION';
    final label = data['label'] as String? ?? '산책 주의';
    final emoji = data['emoji'] as String? ?? '🟡';
    final description = data['description'] as String? ?? '';
    final tmp = data['temperature'] as int? ?? 0;
    final pm10Grade = data['pm10Grade'] as String? ?? '보통';
    final pm25Grade = data['pm25Grade'] as String? ?? '보통';
    final precipitation = data['precipitationType'] as String? ?? '없음';

    final Color indexColor = switch (index) {
      'GOOD' => const Color(0xFF4CAF50),
      'AVOID' => const Color(0xFFE53935),
      _ => const Color(0xFFFFA726),
    };

    final forecastAsync = ref.watch(walkForecastProvider);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '오늘의 산책 지수',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
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
          Text(
            description,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _WeatherItem(
                icon: Icons.thermostat,
                label: '기온',
                value: '$tmp°C',
              ),
              _WeatherItem(
                icon: Icons.water_drop_outlined,
                label: '날씨',
                value: precipitation,
              ),
              _WeatherItem(icon: Icons.air, label: '미세먼지', value: pm10Grade),
              _WeatherItem(icon: Icons.grain, label: '초미세먼지', value: pm25Grade),
            ],
          ),
          forecastAsync.when(
            data: (slots) => slots.isEmpty
                ? const SizedBox.shrink()
                : _ForecastTimeline(slots: slots),
            loading: () => const SizedBox.shrink(),
            error: (error, stackTrace) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _ForecastTimeline extends StatelessWidget {
  final List<dynamic> slots;
  const _ForecastTimeline({required this.slots});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 14, bottom: 10),
          child: Divider(height: 1, color: Color(0xFFEEEEEE)),
        ),
        const Text(
          '앞으로 2시간',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: slots.map<Widget>((slot) {
              return _ForecastSlot(slot: slot as Map<String, dynamic>);
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _ForecastSlot extends StatelessWidget {
  final Map<String, dynamic> slot;
  const _ForecastSlot({required this.slot});

  @override
  Widget build(BuildContext context) {
    final timeLabel = slot['timeLabel'] as String? ?? '';
    final index = slot['index'] as String? ?? 'GOOD';
    final tmp = slot['temperature'] as int? ?? 0;
    final isRaining = slot['isRaining'] as bool? ?? false;
    final precipType = slot['precipitationType'] as String? ?? '없음';
    final isNight = slot['isNight'] as bool? ?? false;

    final Color dotColor = switch (index) {
      'GOOD' => const Color(0xFF4CAF50),
      'AVOID' => const Color(0xFFE53935),
      _ => const Color(0xFFFFA726),
    };

    final bool isSnow = precipType == '눈' || precipType == '비/눈';

    return Container(
      width: 72,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: dotColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dotColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              timeLabel,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(height: 6),
          Text(
            '$tmp°',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: dotColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isRaining ? (isSnow ? '❄️' : '☂️') : (isNight ? '🌙' : '☀️'),
            style: const TextStyle(fontSize: 16),
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
  const _WeatherItem({
    required this.icon,
    required this.label,
    required this.value,
  });

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
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: _valueColor(),
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
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
        BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
      ],
    ),
    child: child,
  );
}

Widget _dogIcon({double size = 56, String? profileImage}) {
  Widget child;

  if (profileImage != null && profileImage.startsWith('data:image')) {
    final bytes = base64Decode(profileImage.split(',').last);
    child = ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: Image.memory(bytes, width: size, height: size, fit: BoxFit.cover),
    );
  } else {
    child = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Icon(Icons.pets, color: const Color(0xFF4CAF50), size: size * 0.5),
    );
  }

  return child;
}

// 쇼핑 카테고리 숏컷 카드
class _ShoppingShortcutsCard extends StatelessWidget {
  const _ShoppingShortcutsCard();

  static const _categories = [
    (emoji: '🍖', label: '사료', query: '강아지 사료'),
    (emoji: '🦴', label: '간식', query: '강아지 간식'),
    (emoji: '✂️', label: '미용', query: '강아지 미용 용품'),
    (emoji: '🎾', label: '장난감', query: '강아지 장난감'),
    (emoji: '👕', label: '의류', query: '강아지 옷'),
    (emoji: '💊', label: '건강', query: '강아지 영양제'),
  ];

  Future<void> _open(String query) async {
    final encoded = Uri.encodeComponent(query);
    final uri = Uri.parse(
      'https://search.shopping.naver.com/search/all?query=$encoded',
    );
    if (await canLaunchUrl(uri)) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text(
                '반려견 쇼핑',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(width: 6),
              Text('네이버쇼핑', style: TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _categories
                .map(
                  (c) => _CategoryItem(
                    emoji: c.emoji,
                    label: c.label,
                    onTap: () => _open(c.query),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _CategoryItem extends StatelessWidget {
  final String emoji;
  final String label;
  final VoidCallback onTap;
  const _CategoryItem({
    required this.emoji,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F8E9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF4CAF50),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
      ],
    );
  }
}

// 오늘 만난 강아지들 카드
class _TodayMeetsCard extends StatelessWidget {
  final List<WalkMeet> meets;
  const _TodayMeetsCard({required this.meets});

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '오늘 만난 강아지들',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          if (meets.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '오늘은 아직 만난 강아지가 없어요 🐾',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
            )
          else
            ...meets.map((meet) => _MeetItem(meet: meet)),
        ],
      ),
    );
  }
}

class _MeetItem extends StatelessWidget {
  final WalkMeet meet;
  const _MeetItem({required this.meet});

  @override
  Widget build(BuildContext context) {
    final dogNames = meet.dogs.map((d) => d.name).join(', ');
    final hasWarnings = meet.dogs.any((d) => d.warnings.isNotEmpty);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          _dogIcon(size: 40, profileImage: meet.user.profileImage),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meet.user.nickname,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  dogNames.isEmpty ? '강아지 정보 없음' : dogNames,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
          if (hasWarnings)
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
              size: 18,
            ),
        ],
      ),
    );
  }
}
