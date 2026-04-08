/// 견종/체중 기반 권장 산책 거리·시간 가이드
class BreedWalkGuide {
  final String sizeLabel; // 소형견 / 중형견 / 대형견
  final double minDistanceKm;
  final double maxDistanceKm;
  final int minMinutes;
  final int maxMinutes;

  const BreedWalkGuide({
    required this.sizeLabel,
    required this.minDistanceKm,
    required this.maxDistanceKm,
    required this.minMinutes,
    required this.maxMinutes,
  });

  String get distanceRange =>
      '${minDistanceKm.toStringAsFixed(1)}~${maxDistanceKm.toStringAsFixed(1)}km';
  String get timeRange => '$minMinutes~$maxMinutes분';
}

// 소형견 (체중 ~10kg)
const _small = BreedWalkGuide(
  sizeLabel: '소형견',
  minDistanceKm: 1.5,
  maxDistanceKm: 3.0,
  minMinutes: 30,
  maxMinutes: 60,
);

// 중형견 (체중 10~25kg)
const _medium = BreedWalkGuide(
  sizeLabel: '중형견',
  minDistanceKm: 3.0,
  maxDistanceKm: 5.0,
  minMinutes: 45,
  maxMinutes: 75,
);

// 대형견 (체중 25kg~)
const _large = BreedWalkGuide(
  sizeLabel: '대형견',
  minDistanceKm: 5.0,
  maxDistanceKm: 8.0,
  minMinutes: 60,
  maxMinutes: 120,
);

// 고강도 견종 (보더콜리, 도베르만 등)
const _highEnergy = BreedWalkGuide(
  sizeLabel: '고에너지 견종',
  minDistanceKm: 8.0,
  maxDistanceKm: 12.0,
  minMinutes: 90,
  maxMinutes: 150,
);

// 저강도 견종 (단두종: 프렌치 불도그, 퍼그, 시추 등)
const _lowEnergy = BreedWalkGuide(
  sizeLabel: '단두종',
  minDistanceKm: 1.0,
  maxDistanceKm: 3.0,
  minMinutes: 20,
  maxMinutes: 40,
);

/// 견종명 → BreedWalkGuide
/// 매핑 없으면 체중으로 폴백
const Map<String, BreedWalkGuide> _breedMap = {
  // 소형견
  '치와와': _small,
  '포메라니안': _small,
  '말티즈': _small,
  '말티푸': _small,
  '요크셔테리어': _small,
  '닥스훈트': _small,
  '파피용': _small,
  '토이푸들': _small,
  '미니어처푸들': _small,
  '스피츠': _small,
  '페키니즈': _lowEnergy,

  // 단두종 (호흡기 약함)
  '프렌치불도그': _lowEnergy,
  '프렌치 불도그': _lowEnergy,
  '불도그': _lowEnergy,
  '퍼그': _lowEnergy,
  '시추': _lowEnergy,
  '보스턴테리어': _lowEnergy,
  '보스턴 테리어': _lowEnergy,

  // 중형견
  '비글': _medium,
  '웰시코기': _medium,
  '웰시 코기': _medium,
  '코카스파니엘': _medium,
  '코카 스파니엘': _medium,
  '샤페이': _medium,
  '바센지': _medium,
  '시베리안허스키': _large,
  '시베리안 허스키': _large,
  '아키타': _large,
  '샤모예드': _large,
  '삽살개': _medium,
  '진돗개': _medium,
  '풍산개': _large,

  // 대형견
  '골든리트리버': _large,
  '골든 리트리버': _large,
  '래브라도리트리버': _large,
  '래브라도 리트리버': _large,
  '저먼셰퍼드': _large,
  '저먼 셰퍼드': _large,
  '로트와일러': _large,
  '복서': _large,
  '그레이트데인': _large,
  '그레이트 데인': _large,
  '세인트버나드': _large,
  '세인트 버나드': _large,
  '말라뮤트': _large,
  '알래스칸말라뮤트': _large,
  '알래스칸 말라뮤트': _large,
  '도베르만': _highEnergy,
  '도베르만 핀셔': _highEnergy,
  '보더콜리': _highEnergy,
  '보더 콜리': _highEnergy,
  '달마시안': _highEnergy,
  '비즐라': _highEnergy,
  '와이마라너': _highEnergy,
};

/// 견종명과 체중(kg)으로 권장 가이드 반환
/// 매핑 없으면 체중 기준으로 폴백
BreedWalkGuide getWalkGuide({String? breed, double? weightKg}) {
  if (breed != null && breed.isNotEmpty) {
    final key = breed.trim();
    if (_breedMap.containsKey(key)) return _breedMap[key]!;
  }

  // 체중 폴백
  if (weightKg != null) {
    if (weightKg <= 10) return _small;
    if (weightKg <= 25) return _medium;
    return _large;
  }

  return _medium; // 기본값
}
