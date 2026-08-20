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
  final String? productName;
  final int? ratingPercent;
  final String? reviewSummary;
  final String? pros;
  final String? cons;
  final PostStatus status;
  final int? relatedPostId;
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
    this.productName,
    this.ratingPercent,
    this.reviewSummary,
    this.pros,
    this.cons,
    required this.status,
    this.relatedPostId,
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
    lastSeenAt: json['lastSeenAt'] != null
        ? DateTime.parse(json['lastSeenAt'])
        : null,
    lat: (json['lat'] as num?)?.toDouble(),
    lng: (json['lng'] as num?)?.toDouble(),
    contactInfo: json['contactInfo'],
    productName: json['productName'],
    ratingPercent: json['ratingPercent'],
    reviewSummary: json['reviewSummary'],
    pros: json['pros'],
    cons: json['cons'],
    status: PostStatus.values.byName(json['status']),
    relatedPostId: json['relatedPostId'],
    createdAt: DateTime.parse(json['createdAt']),
  );
}

enum PostType {
  LOST,
  FOUND,
  ADOPTION,
  FOOD_REVIEW,
  SUPPLY_REVIEW;

  String get label {
    switch (this) {
      case PostType.LOST:
        return '실종';
      case PostType.FOUND:
        return '목격';
      case PostType.ADOPTION:
        return '분양/입양';
      case PostType.FOOD_REVIEW:
        return '사료 리뷰';
      case PostType.SUPPLY_REVIEW:
        return '용품 리뷰';
    }
  }

  bool get isReview =>
      this == PostType.FOOD_REVIEW || this == PostType.SUPPLY_REVIEW;
}

enum PostStatus { OPEN, RESOLVED }
