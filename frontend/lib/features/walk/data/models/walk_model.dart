class WalkSession {
  final int id;
  final String? startedAt;
  final String? endedAt;
  final int distanceMeters;
  final int durationSeconds;
  final String status;

  WalkSession({
    required this.id,
    this.startedAt,
    this.endedAt,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.status,
  });

  factory WalkSession.fromJson(Map<String, dynamic> json) => WalkSession(
        id: json['id'],
        startedAt: json['startedAt'],
        endedAt: json['endedAt'],
        distanceMeters: json['distanceMeters'] ?? 0,
        durationSeconds: json['durationSeconds'] ?? 0,
        status: json['status'] ?? '',
      );
}

class TodayWalkStats {
  final int totalDistanceMeters;
  final int totalDurationSeconds;
  final int walkCount;

  TodayWalkStats({
    required this.totalDistanceMeters,
    required this.totalDurationSeconds,
    required this.walkCount,
  });

  String get distanceText {
    if (totalDistanceMeters >= 1000) {
      return '${(totalDistanceMeters / 1000).toStringAsFixed(1)}km';
    }
    return '$totalDistanceMeters m';
  }

  String get durationText {
    final minutes = totalDurationSeconds ~/ 60;
    return '$minutes분';
  }
}
