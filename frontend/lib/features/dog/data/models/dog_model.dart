class Dog {
  final int id;
  final String name;
  final String? breed;
  final String? profileImage;
  final String? gender;
  final bool isNeutered;

  Dog({
    required this.id,
    required this.name,
    this.breed,
    this.profileImage,
    this.gender,
    required this.isNeutered,
  });

  factory Dog.fromJson(Map<String, dynamic> json) => Dog(
        id: json['id'],
        name: json['name'],
        breed: json['breed'],
        profileImage: json['profileImage'],
        gender: json['gender'],
        isNeutered: json['isNeutered'] ?? false,
      );
}
