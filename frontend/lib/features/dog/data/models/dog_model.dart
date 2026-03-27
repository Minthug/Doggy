import 'dart:math';

class Dog {
  final int id;
  final String name;
  final String? breed;
  final String? profileImage;
  final String? gender;
  final bool isNeutered;
  final double? weightKg;

  Dog({
    required this.id,
    required this.name,
    this.breed,
    this.profileImage,
    this.gender,
    required this.isNeutered,
    this.weightKg,
  });

  factory Dog.fromJson(Map<String, dynamic> json) => Dog(
        id: json['id'],
        name: json['name'],
        breed: json['breed'],
        profileImage: json['profileImage'],
        gender: json['gender'],
        isNeutered: json['isNeutered'] ?? false,
        weightKg: json['weightKg'] != null
            ? (json['weightKg'] as num).toDouble()
            : null,
      );

  /// RER = 70 × (체중kg ^ 0.75)
  /// DER = RER × 계수 (중성화 성견: 1.6 / 일반 성견: 1.4)
  int? get dailyCalories {
    if (weightKg == null || weightKg! <= 0) return null;
    final rer = 70 * pow(weightKg!, 0.75);
    final factor = isNeutered ? 1.6 : 1.4;
    return (rer * factor).round();
  }

  String get genderLabel {
    if (gender == 'MALE') return '남아';
    if (gender == 'FEMALE') return '여아';
    return '';
  }
}
