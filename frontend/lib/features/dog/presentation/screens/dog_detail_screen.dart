import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/dog_model.dart';
import '../../domain/providers/dog_provider.dart';
import 'dog_register_screen.dart';

int? calculateRecommendedFoodGrams({
  required Dog dog,
  required double kcalPerKg,
}) {
  final dailyCalories = dog.dailyCalories;
  if (dailyCalories == null || kcalPerKg <= 0) return null;

  final foodCalories = dailyCalories * 0.9;
  return (foodCalories / (kcalPerKg / 1000)).round();
}

class DogDetailScreen extends ConsumerWidget {
  final Dog dog;

  const DogDetailScreen({super.key, required this.dog});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dogs = ref.watch(myDogsProvider).valueOrNull;
    final currentDog = dogs == null
        ? dog
        : dogs.where((candidate) => candidate.id == dog.id).firstOrNull ?? dog;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          '반려견 상세',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () async {
              final changed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => DogRegisterScreen(dog: currentDog),
                ),
              );
              if (changed == true) {
                final updatedDogs = await ref.refresh(myDogsProvider.future);
                final stillExists = updatedDogs.any(
                  (candidate) => candidate.id == currentDog.id,
                );
                if (!stillExists && context.mounted) {
                  Navigator.pop(context, true);
                }
              }
            },
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('수정'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF4CAF50),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DogSummaryCard(dog: currentDog),
          const SizedBox(height: 12),
          _DogInformationCard(dog: currentDog),
          const SizedBox(height: 12),
          _FeedingCalculatorCard(dog: currentDog),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _DogSummaryCard extends StatelessWidget {
  final Dog dog;

  const _DogSummaryCard({required this.dog});

  ImageProvider? _profileImage() {
    final image = dog.profileImage;
    if (image == null || image.isEmpty) return null;
    if (image.startsWith('data:image')) {
      return MemoryImage(base64Decode(image.split(',').last));
    }
    return NetworkImage(image);
  }

  @override
  Widget build(BuildContext context) {
    final image = _profileImage();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: const Color(0xFFE8F5E9),
            backgroundImage: image,
            child: image == null
                ? const Text('🐶', style: TextStyle(fontSize: 36))
                : null,
          ),
          const SizedBox(height: 14),
          Text(
            dog.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          if (dog.breed != null && dog.breed!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              dog.breed!,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }
}

class _DogInformationCard extends StatelessWidget {
  final Dog dog;

  const _DogInformationCard({required this.dog});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '기본 정보',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _InfoItem(
                  icon: Icons.monitor_weight_outlined,
                  label: '몸무게',
                  value: dog.weightKg == null
                      ? '미등록'
                      : '${dog.weightKg!.toStringAsFixed(1)}kg',
                ),
              ),
              Expanded(
                child: _InfoItem(
                  icon: Icons.pets_outlined,
                  label: '성별',
                  value: dog.genderLabel.isEmpty ? '미등록' : dog.genderLabel,
                ),
              ),
              Expanded(
                child: _InfoItem(
                  icon: Icons.health_and_safety_outlined,
                  label: '중성화',
                  value: dog.isNeutered ? '완료' : '미완료',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 22, color: const Color(0xFF4CAF50)),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _FeedingCalculatorCard extends StatefulWidget {
  final Dog dog;

  const _FeedingCalculatorCard({required this.dog});

  @override
  State<_FeedingCalculatorCard> createState() => _FeedingCalculatorCardState();
}

class _FeedingCalculatorCardState extends State<_FeedingCalculatorCard> {
  final _kcalController = TextEditingController();

  @override
  void dispose() {
    _kcalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dailyCalories = widget.dog.dailyCalories;
    final kcalPerKg = double.tryParse(_kcalController.text.trim()) ?? 0;
    final recommended = calculateRecommendedFoodGrams(
      dog: widget.dog,
      kcalPerKg: kcalPerKg,
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.restaurant_outlined, color: Color(0xFF4CAF50)),
              SizedBox(width: 8),
              Text(
                '권장 급여량 계산',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '사료 포장지의 열량을 입력하면 하루 급여량을 계산해요.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          if (dailyCalories == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '몸무게를 등록하면 권장 급여량을 계산할 수 있어요.',
                style: TextStyle(color: Color(0xFFE65100)),
              ),
            )
          else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '하루 필요 열량',
                    style: TextStyle(fontSize: 13, color: Color(0xFF2E7D32)),
                  ),
                  Text(
                    '$dailyCalories kcal',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('food-kcal-input'),
              controller: _kcalController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: '사료 열량 (kcal/kg)',
                hintText: '예: 3500',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            if (recommended != null) ...[
              const SizedBox(height: 14),
              Container(
                key: const Key('recommended-food-result'),
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      '하루 권장 사료량',
                      style: TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$recommended g',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            const Text(
              '일반 성견 기준 참고값이며, 간식은 하루 필요 열량의 10% 이내로 계산했어요. 건강 상태에 따라 수의사와 상담해 주세요.',
              style: TextStyle(fontSize: 11, height: 1.4, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(16),
  boxShadow: [
    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
  ],
);
