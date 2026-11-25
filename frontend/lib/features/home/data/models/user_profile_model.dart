class UserProfile {
  final int id;
  final String nickname;
  final String? profileImage;
  final bool nicknameChanged;
  final String? address;
  final double? homeLat;
  final double? homeLng;
  bool get hasNeighborhood =>
      address != null &&
      address!.trim().isNotEmpty &&
      homeLat != null &&
      homeLng != null;

  UserProfile({
    required this.id,
    required this.nickname,
    this.profileImage,
    this.nicknameChanged = false,
    this.address,
    this.homeLat,
    this.homeLng,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'],
    address: json['address'],
    homeLat: (json['homeLat'] as num?)?.toDouble(),
    homeLng: (json['homeLng'] as num?)?.toDouble(),
    nickname: json['nickname'],
    profileImage: json['profileImage'],
    nicknameChanged: json['nicknameChanged'] as bool? ?? false,
  );
}
