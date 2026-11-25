import 'package:flutter_test/flutter_test.dart';
import '../lib/features/home/data/models/user_profile_model.dart';

void main() {
  test('주소와 집 좌표가 있어야 내 동네 설정을 완료한다', () {
    final base = <String, dynamic>{'id': 1, 'nickname': '보호자'};
    expect(UserProfile.fromJson(base).hasNeighborhood, isFalse);
    expect(
      UserProfile.fromJson({...base, 'address': '서울 강남구'}).hasNeighborhood,
      isFalse,
    );
    expect(
      UserProfile.fromJson({
        ...base,
        'address': '서울 강남구',
        'homeLat': 37.5,
        'homeLng': 127,
      }).hasNeighborhood,
      isTrue,
    );
  });
}
