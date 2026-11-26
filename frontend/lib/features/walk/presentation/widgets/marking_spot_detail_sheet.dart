import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/walk_model.dart';
import '../../data/repositories/walk_repository.dart';
import 'marking_scent_notice.dart';
import 'trace_affiliation.dart';

final _markingSpotDetailProvider = FutureProvider.autoDispose
    .family<MarkingSpotDetail, int>(
      (ref, spotId) =>
          ref.watch(walkRepositoryProvider).getMarkingSpotDetail(spotId),
    );

Future<void> showMarkingSpotDetail(
  BuildContext context, {
  required int spotId,
  required String title,
  String? lastVisitedAt,
  int? visitCount,
  Color color = familyTraceColor,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return SafeArea(
        child: Consumer(
          builder: (context, ref, _) {
            final snapshot = ref.watch(_markingSpotDetailProvider(spotId));
            final detail = snapshot.valueOrNull;
            final lastVisitedDate = _markingVisitDate(
              detail?.lastVisitedAt ?? lastVisitedAt,
            );
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E0E0),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.pets, color: color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              detail == null
                                  ? visitCount == null
                                        ? '방문 기록을 확인해요'
                                        : '마킹 기록 $visitCount건'
                                  : '마킹 기록 ${detail.visitCount}건',
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 13,
                              ),
                            ),
                            if (lastVisitedDate != null)
                              Text(
                                '마지막 마킹 확인 $lastVisitedDate',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    markingScentNotice(
                          lastVisitedAt: detail?.lastVisitedAt ?? lastVisitedAt,
                          lastRainAt: detail?.lastRainAt,
                        ) ??
                        '마킹한 기록이에요. 현재 냄새가 남아 있는지는 알 수 없어요.',
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  const SizedBox(height: 18),
                  if (snapshot.isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 28),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (snapshot.hasError)
                    const _MarkingSpotDetailMessage(
                      icon: Icons.error_outline,
                      text: '마킹 스팟 정보를 불러오지 못했습니다',
                    )
                  else if (detail == null || detail.visits.isEmpty)
                    const _MarkingSpotDetailMessage(
                      icon: Icons.pets,
                      text: '표시할 마킹 기록이 없어요',
                    )
                  else ...[
                    const Text(
                      '이곳의 마킹 기록',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: detail.visits.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          return _MarkingSpotVisitTile(visit: detail.visits[i]);
                        },
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      );
    },
  );
}

class _MarkingSpotDetailMessage extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MarkingSpotDetailMessage({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF4CAF50), size: 28),
            const SizedBox(height: 8),
            Text(text, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

class _MarkingSpotVisitTile extends StatelessWidget {
  final MarkingSpotVisit visit;

  const _MarkingSpotVisitTile({required this.visit});

  @override
  Widget build(BuildContext context) {
    final color = visit.familyDog ? familyTraceColor : otherTraceColor;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: color.withValues(alpha: 0.12),
            backgroundImage: visit.dog.profileImage != null
                ? NetworkImage(visit.dog.profileImage!)
                : null,
            child: visit.dog.profileImage == null
                ? Icon(Icons.pets, color: color, size: 20)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  visit.dog.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TraceAffiliationBadge(isFamily: visit.familyDog),
                const SizedBox(height: 2),
                Text(
                  [
                    if (visit.dog.breed != null && visit.dog.breed!.isNotEmpty)
                      visit.dog.breed!,
                    if (visit.visitedAt != null)
                      _formatVisitTime(visit.visitedAt!),
                  ].join(' · '),
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatVisitTime(String value) {
  try {
    final dt = DateTime.parse(value);
    return '${dt.month}.${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} 방문';
  } catch (_) {
    return '최근 방문';
  }
}

String? _markingVisitDate(String? value) {
  if (value == null || value.length < 10) return null;
  final date = DateTime.tryParse(value.substring(0, 10));
  if (date == null) return null;
  return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
}
