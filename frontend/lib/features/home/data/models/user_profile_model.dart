class UserProfile {
  final int id;
  final String nickname;
  final String? profileImage;

  UserProfile({
    required this.id,
    required this.nickname,
    this.profileImage,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'],
        nickname: json['nickname'],
        profileImage: json['profileImage'],
      );
}
