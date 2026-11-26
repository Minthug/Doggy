import 'package:flutter/material.dart';

({bool rained, bool aged}) _scentConditions(
  String? lastVisitedAt,
  String? lastRainAt,
  DateTime? now,
) {
  DateTime? parse(String? value) {
    if (value == null || value.isEmpty) return null;
    final hasZone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(value);
    return DateTime.tryParse(hasZone ? value : '$value+09:00');
  }

  final visited = parse(lastVisitedAt);
  if (visited == null) return (rained: false, aged: false);
  final current = now ?? DateTime.now();
  final rain = parse(lastRainAt);
  return (
    rained: rain != null && rain.isAfter(visited) && !rain.isAfter(current),
    aged: current.difference(visited) >= const Duration(days: 3),
  );
}

String? markingScentNotice({
  String? lastVisitedAt,
  String? lastRainAt,
  DateTime? now,
}) {
  final conditions = _scentConditions(lastVisitedAt, lastRainAt, now);
  if (conditions.rained && conditions.aged) {
    return '마지막 마킹 후 3일 이상 지났고 비가 관측돼, 냄새가 옅어졌을 수 있어요.';
  }
  if (conditions.rained) return '마지막 마킹 이후 이 지역에 비가 관측돼, 냄새가 옅어졌을 수 있어요.';
  if (conditions.aged) return '마지막 마킹 후 3일 이상 지나, 냄새가 옅어졌을 수 있어요.';
  return null;
}

// These three visual levels do not measure actual scent concentration.
double markingScentOpacity({
  String? lastVisitedAt,
  String? lastRainAt,
  DateTime? now,
}) {
  final conditions = _scentConditions(lastVisitedAt, lastRainAt, now);
  if (conditions.rained && conditions.aged) return 0.35;
  if (conditions.rained || conditions.aged) return 0.65;
  return 1;
}

class MarkingScentNotice extends StatelessWidget {
  final String? lastVisitedAt;
  final String? lastRainAt;
  const MarkingScentNotice({super.key, this.lastVisitedAt, this.lastRainAt});

  @override
  Widget build(BuildContext context) {
    final message = markingScentNotice(
      lastVisitedAt: lastVisitedAt,
      lastRainAt: lastRainAt,
    );
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        message,
        style: const TextStyle(fontSize: 11, color: Color(0xFF8D6E63)),
      ),
    );
  }
}
