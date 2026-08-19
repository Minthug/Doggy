int _nonNegativeInt(dynamic value) {
  final parsed = value is num ? value.toInt() : 0;
  return parsed < 0 ? 0 : parsed;
}

class WalkSessionDog {
  final int id;
  final String name;
  final String? breed;
  final String? profileImage;

  const WalkSessionDog({
    required this.id,
    required this.name,
    this.breed,
    this.profileImage,
  });

  factory WalkSessionDog.fromJson(Map<String, dynamic> json) => WalkSessionDog(
    id: json['id'],
    name: json['name'] ?? '',
    breed: json['breed'],
    profileImage: json['profileImage'],
  );
}

class WalkSession {
  final int id;
  final String? startedAt;
  final String? endedAt;
  final int distanceMeters;
  final int durationSeconds;
  final String status;
  final List<WalkSessionDog> dogs;

  WalkSession({
    required this.id,
    this.startedAt,
    this.endedAt,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.status,
    this.dogs = const [],
  });

  factory WalkSession.fromJson(Map<String, dynamic> json) => WalkSession(
    id: json['id'],
    startedAt: json['startedAt'],
    endedAt: json['endedAt'],
    distanceMeters: _nonNegativeInt(json['distanceMeters']),
    durationSeconds: _nonNegativeInt(json['durationSeconds']),
    status: json['status'] ?? '',
    dogs:
        (json['dogs'] as List<dynamic>?)
            ?.map((e) => WalkSessionDog.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
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
  final List<MarkingSpotCandidate> markingSpotCandidates;
  final List<MarkingSpot> markingSpots;

  WalkDetail({
    required this.id,
    this.startedAt,
    this.endedAt,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.status,
    this.routeGeoJson,
    this.markingSpotCandidates = const [],
    this.markingSpots = const [],
  });

  factory WalkDetail.fromJson(Map<String, dynamic> json) => WalkDetail(
    id: json['id'],
    startedAt: json['startedAt'],
    endedAt: json['endedAt'],
    distanceMeters: _nonNegativeInt(json['distanceMeters']),
    durationSeconds: _nonNegativeInt(json['durationSeconds']),
    status: json['status'] ?? '',
    routeGeoJson: json['routeGeoJson'],
    markingSpotCandidates:
        (json['markingSpotCandidates'] as List<dynamic>?)
            ?.map(
              (e) => MarkingSpotCandidate.fromJson(e as Map<String, dynamic>),
            )
            .toList() ??
        [],
    markingSpots:
        (json['markingSpots'] as List<dynamic>?)
            ?.map((e) => MarkingSpot.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
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

class MarkingSpotCandidate {
  final String candidateKey;
  final double lat;
  final double lng;
  final String? detectedAt;
  final int dwellSeconds;
  final int nearbyVisitCount;

  const MarkingSpotCandidate({
    required this.candidateKey,
    required this.lat,
    required this.lng,
    this.detectedAt,
    required this.dwellSeconds,
    required this.nearbyVisitCount,
  });

  factory MarkingSpotCandidate.fromJson(Map<String, dynamic> json) {
    return MarkingSpotCandidate(
      candidateKey: json['candidateKey'] ?? '',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      detectedAt: json['detectedAt'],
      dwellSeconds: json['dwellSeconds'] ?? 0,
      nearbyVisitCount: json['nearbyVisitCount'] ?? 0,
    );
  }

  String get dwellText {
    if (dwellSeconds >= 60) {
      return '${dwellSeconds ~/ 60}분 ${dwellSeconds % 60}초';
    }
    return '$dwellSeconds초';
  }
}

class MarkingSpot {
  final int id;
  final double lat;
  final double lng;
  final int visitCount;
  final String? lastVisitedAt;

  const MarkingSpot({
    required this.id,
    required this.lat,
    required this.lng,
    required this.visitCount,
    this.lastVisitedAt,
  });

  factory MarkingSpot.fromJson(Map<String, dynamic> json) {
    return MarkingSpot(
      id: json['id'],
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      visitCount: json['visitCount'] ?? 0,
      lastVisitedAt: json['lastVisitedAt'],
    );
  }
}

class MarkingSpotDetail {
  final int id;
  final double lat;
  final double lng;
  final int visitCount;
  final String? lastVisitedAt;
  final List<MarkingSpotVisit> visits;

  const MarkingSpotDetail({
    required this.id,
    required this.lat,
    required this.lng,
    required this.visitCount,
    this.lastVisitedAt,
    this.visits = const [],
  });

  factory MarkingSpotDetail.fromJson(Map<String, dynamic> json) {
    return MarkingSpotDetail(
      id: json['id'],
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      visitCount: json['visitCount'] ?? 0,
      lastVisitedAt: json['lastVisitedAt'],
      visits:
          (json['visits'] as List<dynamic>?)
              ?.map((e) => MarkingSpotVisit.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class MarkingSpotVisit {
  final int id;
  final String? visitedAt;
  final MarkingSpotVisitDog dog;

  const MarkingSpotVisit({required this.id, this.visitedAt, required this.dog});

  factory MarkingSpotVisit.fromJson(Map<String, dynamic> json) {
    return MarkingSpotVisit(
      id: json['id'],
      visitedAt: json['visitedAt'],
      dog: MarkingSpotVisitDog.fromJson(json['dog'] as Map<String, dynamic>),
    );
  }
}

class MarkingSpotVisitDog {
  final int id;
  final String name;
  final String? breed;
  final String? profileImage;

  const MarkingSpotVisitDog({
    required this.id,
    required this.name,
    this.breed,
    this.profileImage,
  });

  factory MarkingSpotVisitDog.fromJson(Map<String, dynamic> json) {
    return MarkingSpotVisitDog(
      id: json['id'],
      name: json['name'] ?? '이름 없는 강아지',
      breed: json['breed'],
      profileImage: json['profileImage'],
    );
  }
}

class PublicRoute {
  final int sessionId;
  final String title;
  final String dogName;
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
    required this.dogName,
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
    dogName: json['dogName'] ?? '댕댕이',
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

  WalkMeetUser({required this.id, required this.nickname, this.profileImage});

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
  final bool isFavorited;

  WalkMeetDog({
    required this.id,
    required this.name,
    this.breed,
    this.profileImage,
    required this.warnings,
    this.isFavorited = false,
  });

  factory WalkMeetDog.fromJson(Map<String, dynamic> json) => WalkMeetDog(
    id: json['id'],
    name: json['name'] ?? '',
    breed: json['breed'],
    profileImage: json['profileImage'],
    warnings: (json['warnings'] as List? ?? [])
        .map((w) => w.toString())
        .toList(),
    isFavorited: json['isFavorited'] ?? false,
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
