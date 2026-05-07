import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/product_model.dart';
import '../../core/services/local_product_database.dart';
import 'product_database_provider.dart';

// State for search query
final scanSearchQueryProvider = StateProvider<String>((ref) => '');

// Fetches unique dates for home screen folders
final planogramDatesProvider = FutureProvider<List<String>>((ref) async {
  final db = ref.watch(localProductDatabaseProvider);
  return db.fetchUniqueDates();
});

// Fetches total item count for home screen
final totalDatabaseItemsProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(localProductDatabaseProvider);
  return db.fetchTotalCount();
});

// Fetches available sheet tabs (OGE, FGE) for a date
final planogramSheetsProvider = FutureProvider.family<List<String>, String>((ref, date) async {
  final db = ref.watch(localProductDatabaseProvider);
  return db.fetchUniqueSheetsForDate(date);
});

// Fetches products for a specific tab (date + sheet)
final groupedProductsBySheetProvider = FutureProvider.family<List<AisleProductGroup>, ({String date, String sheet})>((ref, arg) async {
  final db = ref.watch(localProductDatabaseProvider);
  return db.fetchGroupedByAisleForDateAndSheet(arg.date, arg.sheet);
});

// Search results provider
final searchProductsProvider = FutureProvider<List<Product>>((ref) async {
  final query = ref.watch(scanSearchQueryProvider);
  if (query.isEmpty) return [];
  final db = ref.watch(localProductDatabaseProvider);
  return db.searchProducts(query);
});

// Global/Legacy provider support
final groupedProductsProvider = FutureProvider<List<AisleProductGroup>>((ref) async {
  final db = ref.watch(localProductDatabaseProvider);
  final dates = await db.fetchUniqueDates();
  if (dates.isEmpty) return [];
  final sheets = await db.fetchUniqueSheetsForDate(dates.first);
  if (sheets.isEmpty) return [];
  return db.fetchGroupedByAisleForDateAndSheet(dates.first, sheets.first);
});
