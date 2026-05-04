class CommunityPost {
  final int id;
  final int userId;
  final String nickname;
  final String? profileImage;
  final PostType type;
  final String title;
  final String content;
  final String? dogName;
  final String? breed;
  final String? lastSeenArea;
  final DateTime? lastSeenAt;
  final double? lat;
  final double? lng;
  final String? contactInfo;
  final PostStatus status;
  final DateTime createdAt;

  const CommunityPost({
    required this.id,
    required this.userId,
    required this.nickname,
    this.profileImage,
    required this.type,
    required this.title,
    required this.content,
    this.dogName,
    this.breed,
    this.lastSeenArea,
    this.lastSeenAt,
    this.lat,
    this.lng,
    this.contactInfo,
    required this.status,
    required this.createdAt,
  });

  factory CommunityPost.fromJson(Map<String, dynamic> json) => CommunityPost(
        id: json['id'],
        userId: json['userId'],
        nickname: json['nickname'],
        profileImage: json['profileImage'],
        type: PostType.values.byName(json['type']),
        title: json['title'],
        content: json['content'],
        dogName: json['dogName'],
        breed: json['breed'],
        lastSeenArea: json['lastSeenArea'],
        lastSeenAt: json['lastSeenAt'] != null ? DateTime.parse(json['lastSeenAt']) : null,
        lat: (json['lat'] as num?)?.toDouble(),
        lng: (json['lng'] as num?)?.toDouble(),
        contactInfo: json['contactInfo'],
        status: PostStatus.values.byName(json['status']),
        createdAt: DateTime.parse(json['createdAt']),
      );
}

enum PostType {
  LOST,
  FOUND,
  GENERAL;

  String get label {
    switch (this) {
      case PostType.LOST:    return '실종';
      case PostType.FOUND:   return '목격';
      case PostType.GENERAL: return '일반';
    }
  }
}

enum PostStatus { OPEN, RESOLVED }
