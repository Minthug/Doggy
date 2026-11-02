import 'package:doggy/features/dog/data/models/dog_model.dart';
import 'package:doggy/features/dog/presentation/screens/dog_detail_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('사료 열량과 반려견 체중으로 하루 권장 급여량을 계산한다', () {
    final dog = Dog(id: 1, name: '몽이', isNeutered: true, weightKg: 5);

    final result = calculateRecommendedFoodGrams(dog: dog, kcalPerKg: 3500);

    expect(result, 96);
  });

  test('몸무게나 사료 열량이 없으면 급여량을 계산하지 않는다', () {
    final dog = Dog(id: 1, name: '몽이', isNeutered: true);

    expect(calculateRecommendedFoodGrams(dog: dog, kcalPerKg: 3500), isNull);
    expect(calculateRecommendedFoodGrams(dog: dog, kcalPerKg: 0), isNull);
  });
}
