import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../dog/domain/providers/dog_provider.dart';
import '../../data/models/walk_model.dart';
import '../../domain/breed_walk_guide.dart';
import '../../domain/providers/walk_provider.dart';
import 'public_routes_screen.dart';
import 'walk_detail_screen.dart';

class WalkHistoryScreen extends ConsumerWidget {
  const WalkHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(walkHistoryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '산책 기록',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.explore_outlined),
            tooltip: '인기 경로',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PublicRoutesScreen()),
            ),
          ),
        ],
      ),
      body: historyAsync.when(
        data: (history) {
          final completed =
              history.where((s) => s.status == 'COMPLETED').toList();

          return RefreshIndicator(
            onRefresh: () => ref.refresh(walkHistoryProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 월간 통계 카드
                _MonthlyStatsCard(history: completed),
                const SizedBox(height: 16),

                if (completed.isEmpty) ...[
                  const SizedBox(height: 48),
                  const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.directions_walk,
                            size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          '아직 완료된 산책이 없어요',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '반려견과 첫 산책을 시작해보세요!',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  ...completed.asMap().entries.map((entry) {
                    final index = entry.key;
                    final session = entry.value;
                    return Padding(
                      padding: EdgeInsets.only(
                          bottom: index < completed.length - 1 ? 12 : 0),
                      child: _WalkHistoryItem(
                        session: session,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                WalkDetailScreen(sessionId: session.id),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('불러오기 실패')),
      ),
    );
  }
}

class _MonthlyStatsCard extends ConsumerWidget {
  final List<WalkSession> history;
  const _MonthlyStatsCard({required this.history});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
    final daysPassed = now.day;

    // 이번 달 세션 필터
    final monthSessions = history.where((s) {
      if (s.startedAt == null) return false;
      final d = DateTime.parse(s.startedAt!);
      return d.year == now.year && d.month == now.month;
    }).toList();

    final totalMeters =
        monthSessions.fold(0, (sum, s) => sum + s.distanceMeters);
    final totalKm = totalMeters / 1000;
    final walkCount = monthSessions.length;
    final totalMinutes =
        monthSessions.fold(0, (sum, s) => sum + s.durationSeconds) ~/ 60;

    // 일평균 & 예상 월말 총계
    final avgKmPerDay = daysPassed > 0 ? totalKm / daysPassed : 0.0;
    final projectedKm = avgKmPerDay * daysInMonth;

    // 강아지 견종 기반 월간 목표
    final dogsAsync = ref.watch(myDogsProvider);
    final firstDog = dogsAsync.valueOrNull?.isNotEmpty == true
        ? dogsAsync.value!.first
        : null;
    final guide = getWalkGuide(
      breed: firstDog?.breed,
      weightKg: firstDog?.weightKg,
    );

    final monthTargetMinKm = guide.minDistanceKm * daysInMonth;
    final monthTargetMaxKm = guide.maxDistanceKm * daysInMonth;
    final progress = (totalKm / monthTargetMaxKm).clamp(0.0, 1.0);
    final achieved = totalKm >= monthTargetMinKm;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06), blurRadius: 12),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${now.month}월 산책 현황',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (firstDog != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      guide.sizeLabel,
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF4CAF50),
                          fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // 총 거리 + 횟수 + 시간
            Row(
              children: [
                Expanded(
                  child: _StatCell(
                    label: '총 거리',
                    value: totalKm >= 10
                        ? '${totalKm.toStringAsFixed(1)}km'
                        : '${totalKm.toStringAsFixed(2)}km',
                    icon: Icons.route,
                  ),
                ),
                _verticalDivider(),
                Expanded(
                  child: _StatCell(
                    label: '산책 횟수',
                    value: '$walkCount회',
                    icon: Icons.directions_walk,
                  ),
                ),
                _verticalDivider(),
                Expanded(
                  child: _StatCell(
                    label: '총 시간',
                    value: totalMinutes >= 60
                        ? '${totalMinutes ~/ 60}h ${totalMinutes % 60}m'
                        : '$totalMinutes분',
                    icon: Icons.timer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 목표 진행률
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '월간 목표 달성률',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500),
                ),
                Text(
                  '${monthTargetMinKm.toStringAsFixed(0)}~${monthTargetMaxKm.toStringAsFixed(0)}km 목표',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: const Color(0xFFEEEEEE),
                valueColor: AlwaysStoppedAnimation<Color>(
                  achieved ? const Color(0xFF4CAF50) : const Color(0xFFFF9800),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 진행률 텍스트 + 예상
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  achieved
                      ? '최소 목표 달성! 🎉'
                      : '목표까지 ${(monthTargetMinKm - totalKm).toStringAsFixed(1)}km 남았어요',
                  style: TextStyle(
                    fontSize: 12,
                    color: achieved
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFFF9800),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '일평균 ${avgKmPerDay.toStringAsFixed(1)}km · 예상 ${projectedKm.toStringAsFixed(0)}km',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),

            // 남은 날 표시
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '이번 달 $daysPassed일 경과 · ${daysInMonth - daysPassed}일 남음',
                style:
                    const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _verticalDivider() =>
      Container(width: 1, height: 40, color: const Color(0xFFEEEEEE));
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatCell(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF4CAF50)),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF212121))),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

class _WalkHistoryItem extends StatelessWidget {
  final WalkSession session;
  final VoidCallback onTap;

  const _WalkHistoryItem({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final date = session.startedAtDate;
    final dateText = date != null
        ? '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}'
        : '-';
    final timeText = date != null
        ? '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
        : '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
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
            // 아이콘
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.directions_walk,
                  color: Color(0xFF4CAF50), size: 24),
            ),
            const SizedBox(width: 16),

            // 날짜 + 통계
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$dateText $timeText',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _chip(Icons.straighten, session.distanceText),
                      const SizedBox(width: 12),
                      _chip(Icons.timer, session.durationText),
                    ],
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

  Widget _chip(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
      ],
    );
  }
}
