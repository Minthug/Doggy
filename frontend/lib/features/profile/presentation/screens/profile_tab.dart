import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/domain/providers/auth_provider.dart';
import '../../../dog/data/models/dog_model.dart';
import '../../../dog/domain/providers/dog_provider.dart';
import '../../../dog/presentation/screens/dog_register_screen.dart';
import '../../../home/domain/providers/home_provider.dart';
import '../../../walk/data/models/walk_model.dart';
import '../../../walk/domain/providers/walk_provider.dart';

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final dogsAsync = ref.watch(myDogsProvider);
    final statsAsync = ref.watch(monthlyWalkStatsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('프로필',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 프로필 헤더
            profileAsync.when(
              data: (profile) => _ProfileHeader(
                nickname: profile.nickname,
                profileImage: profile.profileImage,
              ),
              loading: () => const _ProfileHeader(nickname: '...', profileImage: null),
              error: (_, __) => const _ProfileHeader(nickname: '사용자', profileImage: null),
            ),

            const SizedBox(height: 12),

            // 이번 달 산책 통계
            statsAsync.when(
              data: (stats) => _MonthlyStatsCard(stats: stats),
              loading: () => const _LoadingCard(height: 130),
              error: (_, __) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 12),

            // 내 반려견
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('내 반려견',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const DogRegisterScreen()),
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('추가'),
                    style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF4CAF50)),
                  ),
                ],
              ),
            ),

            dogsAsync.when(
              data: (dogs) => dogs.isEmpty
                  ? _EmptyDogs(
                      onAdd: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const DogRegisterScreen()),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: dogs.length,
                      itemBuilder: (context, index) =>
                          _DogCard(dog: dogs[index]),
                    ),
              loading: () => const _LoadingCard(height: 100),
              error: (_, __) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 24),

            // 로그아웃
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('로그아웃'),
                        content: const Text('로그아웃 하시겠습니까?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('취소')),
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('로그아웃',
                                  style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (confirmed == true && context.mounted) {
                      await ref.read(authActionProvider).logout();
                    }
                  },
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text('로그아웃',
                      style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String nickname;
  final String? profileImage;

  const _ProfileHeader({required this.nickname, required this.profileImage});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: const Color(0xFFE8F5E9),
            backgroundImage:
                profileImage != null ? NetworkImage(profileImage!) : null,
            child: profileImage == null
                ? const Icon(Icons.person, size: 40, color: Color(0xFF4CAF50))
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            nickname,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _MonthlyStatsCard extends StatelessWidget {
  final MonthlyWalkStats stats;

  const _MonthlyStatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${stats.month}월 산책 기록',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  icon: Icons.directions_walk,
                  color: const Color(0xFF4CAF50),
                  value: '${stats.walkCount}회',
                  label: '산책 횟수',
                ),
                _StatItem(
                  icon: Icons.straighten,
                  color: Colors.blue,
                  value: stats.distanceText,
                  label: '총 거리',
                ),
                _StatItem(
                  icon: Icons.timer,
                  color: Colors.orange,
                  value: stats.durationText,
                  label: '총 시간',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

class _DogCard extends StatelessWidget {
  final Dog dog;

  const _DogCard({required this.dog});

  @override
  Widget build(BuildContext context) {
    final calories = dog.dailyCalories;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          // 프로필 이미지
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFFE8F5E9),
            backgroundImage: dog.profileImage != null
                ? NetworkImage(dog.profileImage!)
                : null,
            child: dog.profileImage == null
                ? const Text('🐶', style: TextStyle(fontSize: 22))
                : null,
          ),
          const SizedBox(width: 14),

          // 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(dog.name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    if (dog.genderLabel.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: dog.gender == 'MALE'
                              ? Colors.blue.withValues(alpha: 0.1)
                              : Colors.pink.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          dog.genderLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: dog.gender == 'MALE'
                                ? Colors.blue
                                : Colors.pink,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    if (dog.isNeutered) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('중성화',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.purple,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                if (dog.breed != null) ...[
                  const SizedBox(height: 3),
                  Text(dog.breed!,
                      style: const TextStyle(
                          fontSize: 13, color: Colors.grey)),
                ],
                if (dog.weightKg != null) ...[
                  const SizedBox(height: 3),
                  Text('${dog.weightKg!.toStringAsFixed(1)}kg',
                      style: const TextStyle(
                          fontSize: 13, color: Colors.grey)),
                ],
              ],
            ),
          ),

          // 칼로리
          if (calories != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('하루 권장 칼로리',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(
                  '$calories kcal',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4CAF50),
                  ),
                ),
                Text(
                  dog.isNeutered ? '(중성화 기준)' : '(일반 기준)',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _EmptyDogs extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyDogs({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: onAdd,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                style: BorderStyle.solid),
          ),
          child: const Column(
            children: [
              Icon(Icons.add_circle_outline,
                  size: 40, color: Color(0xFF4CAF50)),
              SizedBox(height: 8),
              Text('반려견을 등록해주세요',
                  style: TextStyle(color: Colors.grey, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  final double height;

  const _LoadingCard({required this.height});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
