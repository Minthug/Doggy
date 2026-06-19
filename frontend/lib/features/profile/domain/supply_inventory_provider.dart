import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/supply_repository.dart';

class SupplyItem {
  final String name;
  final String emoji;
  final int currentGrams;
  final int totalGrams;
  final int dailyGrams;
  final double kcalPerKg;
  final String lastUpdatedDate;

  const SupplyItem({
    required this.name,
    required this.emoji,
    this.currentGrams = 0,
    this.totalGrams = 0,
    this.dailyGrams = 0,
    this.kcalPerKg = 0,
    this.lastUpdatedDate = '',
  });

  bool get isSet => totalGrams > 0;
  bool get hasDailyRate => dailyGrams > 0;
  bool get hasKcal => kcalPerKg > 0;
  double get percentage =>
      (!isSet || currentGrams <= 0) ? 0 : (currentGrams / totalGrams).clamp(0.0, 1.0);
  bool get isLow => isSet && percentage < 0.2;
  bool get isEmpty => isSet && currentGrams <= 0;

  int? get daysLeft =>
      (hasDailyRate && currentGrams > 0) ? (currentGrams / dailyGrams).floor() : null;

  String _fmt(int grams) =>
      grams >= 1000 ? '${(grams / 1000).toStringAsFixed(1)}kg' : '${grams}g';

  String get displayCurrent => _fmt(currentGrams);
  String get displayTotal => _fmt(totalGrams);
  String get displayDaily => _fmt(dailyGrams);

  SupplyItem copyWith({
    int? currentGrams,
    int? totalGrams,
    int? dailyGrams,
    double? kcalPerKg,
    String? lastUpdatedDate,
  }) =>
      SupplyItem(
        name: name,
        emoji: emoji,
        currentGrams: currentGrams ?? this.currentGrams,
        totalGrams: totalGrams ?? this.totalGrams,
        dailyGrams: dailyGrams ?? this.dailyGrams,
        kcalPerKg: kcalPerKg ?? this.kcalPerKg,
        lastUpdatedDate: lastUpdatedDate ?? this.lastUpdatedDate,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'emoji': emoji,
        'currentGrams': currentGrams,
        'totalGrams': totalGrams,
        'dailyGrams': dailyGrams,
        'kcalPerKg': kcalPerKg,
        'lastUpdatedDate': lastUpdatedDate,
      };

  factory SupplyItem.fromJson(Map<String, dynamic> json) => SupplyItem(
        name: json['name'] as String,
        emoji: json['emoji'] as String,
        currentGrams: (json['currentGrams'] as num?)?.toInt() ?? 0,
        totalGrams: (json['totalGrams'] as num?)?.toInt() ?? 0,
        dailyGrams: (json['dailyGrams'] as num?)?.toInt() ?? 0,
        kcalPerKg: (json['kcalPerKg'] as num?)?.toDouble() ?? 0,
        lastUpdatedDate: json['lastUpdatedDate'] as String? ?? '',
      );
}

class SupplyInventoryNotifier extends AsyncNotifier<List<SupplyItem>> {
  @override
  Future<List<SupplyItem>> build() async {
    return ref.read(supplyRepositoryProvider).getInventory();
  }

  Future<void> updateItem(int index, int currentGrams, int totalGrams, int dailyGrams, double kcalPerKg) async {
    final current = state.valueOrNull ?? [];
    if (index < 0 || index >= current.length) return;

    final item = current[index];

    // 낙관적 업데이트
    final optimistic = [...current];
    optimistic[index] = item.copyWith(
      currentGrams: currentGrams.clamp(0, totalGrams),
      totalGrams: totalGrams,
      dailyGrams: dailyGrams,
      kcalPerKg: kcalPerKg,
    );
    state = AsyncData(optimistic);

    try {
      final updated = await ref.read(supplyRepositoryProvider).update(
        item.name,
        currentGrams: currentGrams,
        totalGrams: totalGrams,
        dailyGrams: dailyGrams,
        kcalPerKg: kcalPerKg,
      );
      final confirmed = [...current];
      confirmed[index] = updated;
      state = AsyncData(confirmed);
    } catch (e) {
      // 실패 시 롤백
      state = AsyncData(current);
      rethrow;
    }
  }
}

final supplyInventoryProvider =
    AsyncNotifierProvider<SupplyInventoryNotifier, List<SupplyItem>>(
  SupplyInventoryNotifier.new,
);
