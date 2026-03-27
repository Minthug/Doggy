class Place {
  final int id;
  final String name;
  final String category;
  final String? address;
  final double lat;
  final double lng;
  final String? phone;
  final bool isOpen24h;
  final bool isEmergency;
  final bool allowsDogs;
  final String source;
  final bool isVerified;
  final int helpfulCount;

  Place({
    required this.id,
    required this.name,
    required this.category,
    this.address,
    required this.lat,
    required this.lng,
    this.phone,
    required this.isOpen24h,
    required this.isEmergency,
    required this.allowsDogs,
    required this.source,
    required this.isVerified,
    required this.helpfulCount,
  });

  factory Place.fromJson(Map<String, dynamic> json) => Place(
        id: json['id'],
        name: json['name'],
        category: json['category'],
        address: json['address'],
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        phone: json['phone'],
        isOpen24h: json['isOpen24h'] ?? false,
        isEmergency: json['isEmergency'] ?? false,
        allowsDogs: json['allowsDogs'] ?? true,
        source: json['source'] ?? '',
        isVerified: json['isVerified'] ?? false,
        helpfulCount: json['helpfulCount'] ?? 0,
      );

  String get categoryLabel {
    switch (category) {
      case 'HOSPITAL':      return '동물병원';
      case 'PARK':          return '공원';
      case 'CAFE':          return '반려견 카페';
      case 'PET_SHOP':      return '펫샵';
      case 'PET_HOTEL':     return '펫호텔';
      case 'CONVENIENCE':   return '편의점';
      case 'UNMANNED_STORE': return '무인 스토어';
      case 'RESTAURANT':    return '동반 식당';
      case 'GROOMING':      return '미용실';
      default:              return category;
    }
  }

  String get categoryEmoji {
    switch (category) {
      case 'HOSPITAL':      return '🏥';
      case 'PARK':          return '🌳';
      case 'CAFE':          return '☕';
      case 'PET_SHOP':      return '🛍️';
      case 'PET_HOTEL':     return '🏨';
      case 'CONVENIENCE':   return '🏪';
      case 'UNMANNED_STORE': return '🤖';
      case 'RESTAURANT':    return '🍽️';
      case 'GROOMING':      return '✂️';
      default:              return '📍';
    }
  }
}
