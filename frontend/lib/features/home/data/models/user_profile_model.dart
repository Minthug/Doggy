class UserProfile {
  final int id;
  final String nickname;
  final String? profileImage;
  final bool nicknameChanged;

  UserProfile({
    required this.id,
    required this.nickname,
    this.profileImage,
    this.nicknameChanged = false,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'],
        nickname: json['nickname'],
        profileImage: json['profileImage'],
        nicknameChanged: json['nicknameChanged'] as bool? ?? false,
      );
}
