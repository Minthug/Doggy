import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// main()에서 초기화 후 ProviderScope override로 주입
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('SharedPreferences must be overridden in ProviderScope'),
);

class SupplyItem {
  final String name;
  final String emoji;
  final int currentGrams;
  final int totalGrams;

  const SupplyItem({
    required this.name,
    required this.emoji,
    this.currentGrams = 0,
    this.totalGrams = 0,
  });

  bool get isSet => totalGrams > 0;
  double get percentage =>
      (!isSet || currentGrams <= 0) ? 0 : (currentGrams / totalGrams).clamp(0.0, 1.0);
  bool get isLow => isSet && percentage < 0.2;
  bool get isEmpty => isSet && currentGrams <= 0;

  String _fmt(int grams) =>
      grams >= 1000 ? '${(grams / 1000).toStringAsFixed(1)}kg' : '${grams}g';

  String get displayCurrent => _fmt(currentGrams);
  String get displayTotal => _fmt(totalGrams);

  SupplyItem copyWith({int? currentGrams, int? totalGrams}) => SupplyItem(
        name: name,
        emoji: emoji,
        currentGrams: currentGrams ?? this.currentGrams,
        totalGrams: totalGrams ?? this.totalGrams,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'emoji': emoji,
        'currentGrams': currentGrams,
        'totalGrams': totalGrams,
      };

  factory SupplyItem.fromJson(Map<String, dynamic> json) => SupplyItem(
        name: json['name'],
        emoji: json['emoji'],
        currentGrams: json['currentGrams'] ?? 0,
        totalGrams: json['totalGrams'] ?? 0,
      );
}

class SupplyInventoryNotifier extends StateNotifier<List<SupplyItem>> {
  static const _key = 'supply_inventory';
  final SharedPreferences _prefs;

  // SharedPreferences가 이미 초기화되어 있으므로 동기 로드 가능 — 타이밍 충돌 없음
  SupplyInventoryNotifier(this._prefs) : super(_loadSync(_prefs));

  static List<SupplyItem> _loadSync(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null) {
      return const [
        SupplyItem(name: '사료', emoji: '🍖'),
        SupplyItem(name: '간식', emoji: '🦴'),
      ];
    }
    try {
      return (jsonDecode(raw) as List)
          .map((e) => SupplyItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [
        SupplyItem(name: '사료', emoji: '🍖'),
        SupplyItem(name: '간식', emoji: '🦴'),
      ];
    }
  }

  Future<void> update(int index, int currentGrams, int totalGrams) async {
    final updated = [...state];
    updated[index] = updated[index].copyWith(
      currentGrams: currentGrams,
      totalGrams: totalGrams,
    );
    state = updated;
    await _prefs.setString(
        _key, jsonEncode(updated.map((e) => e.toJson()).toList()));
  }
}

final supplyInventoryProvider =
    StateNotifierProvider<SupplyInventoryNotifier, List<SupplyItem>>((ref) {
  return SupplyInventoryNotifier(ref.watch(sharedPreferencesProvider));
});
