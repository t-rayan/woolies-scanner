import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/product_model.dart';
import '../../core/services/local_product_database.dart';
import 'product_database_provider.dart';

final scanSearchQueryProvider = StateProvider<String>((ref) => '');

final searchProductsProvider = FutureProvider<List<Product>>((ref) async {
  final query = ref.watch(scanSearchQueryProvider);
  final db = ref.read(localProductDatabaseProvider);
  if (query.isEmpty) return [];
  return db.searchProducts(query);
});

final totalDatabaseItemsProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(localProductDatabaseProvider);
  return db.fetchTotalCount();
});

final planogramDatesProvider = FutureProvider<List<String>>((ref) async {
  final db = ref.watch(localProductDatabaseProvider);
  return db.fetchUniqueDates();
});

final planogramSheetsProvider = FutureProvider.family<List<String>, String>((ref, date) async {
  final db = ref.watch(localProductDatabaseProvider);
  return db.fetchUniqueSheetsForDate(date);
});

final groupedProductsBySheetProvider = FutureProvider.family<List<AisleProductGroup>, ({String date, String sheet})>((ref, arg) async {
  final db = ref.watch(localProductDatabaseProvider);
  return db.fetchGroupedByAisle(arg.date, arg.sheet);
});

/// One-time fix: migrates any existing ENT products from OGE to FGE.
final fixEntDataProvider = FutureProvider<int>((ref) async {
  final db = ref.read(localProductDatabaseProvider);
  return db.fixExistingEntData();
});
