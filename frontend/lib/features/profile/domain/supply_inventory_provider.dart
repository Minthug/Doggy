import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  String _fmt(int grams) => grams >= 1000
      ? '${(grams / 1000).toStringAsFixed(1)}kg'
      : '${grams}g';

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

  SupplyInventoryNotifier()
      : super(const [
          SupplyItem(name: '사료', emoji: '🍖'),
          SupplyItem(name: '간식', emoji: '🦴'),
        ]) {
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => SupplyItem.fromJson(e as Map<String, dynamic>))
          .toList();
      state = list;
    } catch (_) {}
  }

  Future<void> update(int index, int currentGrams, int totalGrams) async {
    final updated = [...state];
    updated[index] = updated[index].copyWith(
      currentGrams: currentGrams,
      totalGrams: totalGrams,
    );
    state = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(updated.map((e) => e.toJson()).toList()));
  }
}

final supplyInventoryProvider =
    StateNotifierProvider<SupplyInventoryNotifier, List<SupplyItem>>(
  (_) => SupplyInventoryNotifier(),
);
