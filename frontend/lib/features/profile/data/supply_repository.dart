import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../domain/supply_inventory_provider.dart';

final supplyRepositoryProvider = Provider<SupplyRepository>((ref) {
  return SupplyRepository(ref.watch(dioProvider));
});

class SupplyRepository {
  final Dio _dio;

  SupplyRepository(this._dio);

  Future<List<SupplyItem>> getInventory() async {
    final response = await _dio.get('/api/supply');
    return (response.data as List)
        .map((e) => SupplyItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SupplyItem> update(String name, {
    required int currentGrams,
    required int totalGrams,
    required int dailyGrams,
    required double kcalPerKg,
  }) async {
    final response = await _dio.put(
      '/api/supply/${Uri.encodeComponent(name)}',
      data: {
        'currentGrams': currentGrams,
        'totalGrams': totalGrams,
        'dailyGrams': dailyGrams,
        'kcalPerKg': kcalPerKg,
      },
    );
    return SupplyItem.fromJson(response.data as Map<String, dynamic>);
  }
}
