import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('SharedPreferences must be overridden in ProviderScope'),
);

class SupplyItem {
  final String name;
  final String emoji;
  final int currentGrams;
  final int totalGrams;
  final int dailyGrams;         // 하루 섭취량
  final double kcalPerKg;       // 사료 칼로리 밀도 (kcal/kg)
  final String lastUpdatedDate; // 마지막 차감일 (yyyy-MM-dd)

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

  // 현재 재고로 며칠 남았는지
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

  // 경과 일수만큼 자동 차감
  SupplyItem applyDailyDecrement() {
    if (!hasDailyRate || !isSet) return this;
    final today = _todayStr();
    if (lastUpdatedDate == today) return this;
    if (lastUpdatedDate.isEmpty) return copyWith(lastUpdatedDate: today);

    final last = DateTime.tryParse(lastUpdatedDate);
    if (last == null) return copyWith(lastUpdatedDate: today);

    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final days = todayDate.difference(DateTime(last.year, last.month, last.day)).inDays;
    if (days <= 0) return this;

    final consumed = dailyGrams * days;
    final next = (currentGrams - consumed).clamp(0, totalGrams);
    return copyWith(currentGrams: next, lastUpdatedDate: today);
  }

  static String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
  }

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
        name: json['name'],
        emoji: json['emoji'],
        currentGrams: json['currentGrams'] ?? 0,
        totalGrams: json['totalGrams'] ?? 0,
        dailyGrams: json['dailyGrams'] ?? 0,
        kcalPerKg: (json['kcalPerKg'] as num?)?.toDouble() ?? 0,
        lastUpdatedDate: json['lastUpdatedDate'] ?? '',
      );
}

class SupplyInventoryNotifier extends StateNotifier<List<SupplyItem>> {
  static const _key = 'supply_inventory';
  final SharedPreferences _prefs;

  SupplyInventoryNotifier(this._prefs) : super(_loadSync(_prefs));

  static List<SupplyItem> _loadSync(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    List<SupplyItem> items;
    if (raw == null) {
      items = const [
        SupplyItem(name: '사료', emoji: '🍖'),
        SupplyItem(name: '간식', emoji: '🦴'),
      ];
    } else {
      try {
        items = (jsonDecode(raw) as List)
            .map((e) => SupplyItem.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        items = const [
          SupplyItem(name: '사료', emoji: '🍖'),
          SupplyItem(name: '간식', emoji: '🦴'),
        ];
      }
    }
    // 앱 실행 시 경과 일수 자동 차감
    return items.map((e) => e.applyDailyDecrement()).toList();
  }

  Future<void> update(int index, int currentGrams, int totalGrams, int dailyGrams, double kcalPerKg) async {
    final today = SupplyItem._todayStr();
    final updated = [...state];
    updated[index] = updated[index].copyWith(
      currentGrams: currentGrams.clamp(0, totalGrams),
      totalGrams: totalGrams,
      dailyGrams: dailyGrams,
      kcalPerKg: kcalPerKg,
      lastUpdatedDate: today,
    );
    state = updated;
    await _save();
  }

  Future<void> _save() async {
    await _prefs.setString(_key, jsonEncode(state.map((e) => e.toJson()).toList()));
  }
}

final supplyInventoryProvider =
    StateNotifierProvider<SupplyInventoryNotifier, List<SupplyItem>>((ref) {
  return SupplyInventoryNotifier(ref.watch(sharedPreferencesProvider));
});
