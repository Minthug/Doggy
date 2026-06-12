class HouseholdMember {
  final int userId;
  final String nickname;
  final String? profileImage;
  final String role;

  HouseholdMember({
    required this.userId,
    required this.nickname,
    this.profileImage,
    required this.role,
  });

  bool get isOwner => role == 'OWNER';

  factory HouseholdMember.fromJson(Map<String, dynamic> json) => HouseholdMember(
        userId: json['userId'],
        nickname: json['nickname'],
        profileImage: json['profileImage'],
        role: json['role'],
      );
}

class Household {
  final int id;
  final String name;
  final String inviteCode;
  final List<HouseholdMember> members;

  Household({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.members,
  });

  factory Household.fromJson(Map<String, dynamic> json) => Household(
        id: json['id'],
        name: json['name'],
        inviteCode: json['inviteCode'],
        members: (json['members'] as List)
            .map((m) => HouseholdMember.fromJson(m))
            .toList(),
      );
}
