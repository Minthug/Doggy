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

  String get distanceText {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(2)}km';
    }
    return '${distanceMeters}m';
  }

  String get durationText {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  DateTime? get startedAtDate =>
      startedAt != null ? DateTime.parse(startedAt!) : null;
}

class WalkDetail {
  final int id;
  final String? startedAt;
  final String? endedAt;
  final int distanceMeters;
  final int durationSeconds;
  final String status;
  final String? routeGeoJson;

  WalkDetail({
    required this.id,
    this.startedAt,
    this.endedAt,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.status,
    this.routeGeoJson,
  });

  factory WalkDetail.fromJson(Map<String, dynamic> json) => WalkDetail(
        id: json['id'],
        startedAt: json['startedAt'],
        endedAt: json['endedAt'],
        distanceMeters: json['distanceMeters'] ?? 0,
        durationSeconds: json['durationSeconds'] ?? 0,
        status: json['status'] ?? '',
        routeGeoJson: json['routeGeoJson'],
      );

  String get distanceText {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(2)}km';
    }
    return '${distanceMeters}m';
  }

  String get durationText {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class PublicRoute {
  final int sessionId;
  final String title;
  final String authorNickname;
  final int distanceMeters;
  final int durationSeconds;
  final String? startedAt;
  final int likeCount;
  final bool likedByMe;
  final bool bookmarkedByMe;
  final String? routeGeoJson;

  PublicRoute({
    required this.sessionId,
    required this.title,
    required this.authorNickname,
    required this.distanceMeters,
    required this.durationSeconds,
    this.startedAt,
    required this.likeCount,
    required this.likedByMe,
    required this.bookmarkedByMe,
    this.routeGeoJson,
  });

  factory PublicRoute.fromJson(Map<String, dynamic> json) => PublicRoute(
        sessionId: json['sessionId'],
        title: json['title'] ?? '',
        authorNickname: json['authorNickname'] ?? '',
        distanceMeters: json['distanceMeters'] ?? 0,
        durationSeconds: json['durationSeconds'] ?? 0,
        startedAt: json['startedAt'],
        likeCount: json['likeCount'] ?? 0,
        likedByMe: json['likedByMe'] ?? false,
        bookmarkedByMe: json['bookmarkedByMe'] ?? false,
        routeGeoJson: json['routeGeoJson'],
      );

  String get distanceText {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)}km';
    }
    return '${distanceMeters}m';
  }

  String get durationText {
    final m = durationSeconds ~/ 60;
    return '$m분';
  }
}

class WalkMeet {
  final String metAt;
  final WalkMeetUser user;
  final List<WalkMeetDog> dogs;

  WalkMeet({required this.metAt, required this.user, required this.dogs});

  factory WalkMeet.fromJson(Map<String, dynamic> json) => WalkMeet(
        metAt: json['metAt'] ?? '',
        user: WalkMeetUser.fromJson(json['user']),
        dogs: (json['dogs'] as List? ?? [])
            .map((d) => WalkMeetDog.fromJson(d))
            .toList(),
      );
}

class WalkMeetUser {
  final int id;
  final String nickname;
  final String? profileImage;

  WalkMeetUser(
      {required this.id, required this.nickname, this.profileImage});

  factory WalkMeetUser.fromJson(Map<String, dynamic> json) => WalkMeetUser(
        id: json['id'],
        nickname: json['nickname'] ?? '',
        profileImage: json['profileImage'],
      );
}

class WalkMeetDog {
  final int id;
  final String name;
  final String? breed;
  final String? profileImage;
  final List<String> warnings;

  WalkMeetDog(
      {required this.id,
      required this.name,
      this.breed,
      this.profileImage,
      required this.warnings});

  factory WalkMeetDog.fromJson(Map<String, dynamic> json) => WalkMeetDog(
        id: json['id'],
        name: json['name'] ?? '',
        breed: json['breed'],
        profileImage: json['profileImage'],
        warnings: (json['warnings'] as List? ?? [])
            .map((w) => w.toString())
            .toList(),
      );
}

class MonthlyWalkStats {
  final int totalDistanceMeters;
  final int totalDurationSeconds;
  final int walkCount;
  final int month;

  MonthlyWalkStats({
    required this.totalDistanceMeters,
    required this.totalDurationSeconds,
    required this.walkCount,
    required this.month,
  });

  String get distanceText {
    if (totalDistanceMeters >= 1000) {
      return '${(totalDistanceMeters / 1000).toStringAsFixed(1)}km';
    }
    return '${totalDistanceMeters}m';
  }

  String get durationText {
    final minutes = totalDurationSeconds ~/ 60;
    if (minutes >= 60) {
      return '${minutes ~/ 60}시간 ${minutes % 60}분';
    }
    return '$minutes분';
  }
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
    return '${totalDistanceMeters}m';
  }

  String get durationText {
    final minutes = totalDurationSeconds ~/ 60;
    return '$minutes분';
  }
}
