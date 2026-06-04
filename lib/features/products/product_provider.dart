import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/product_model.dart';
import '../../core/services/supabase_service.dart';
import 'product_database_provider.dart';

// ─── Local Search Cache ──────────────────────────────────────

/// Holds ALL products in memory (fetched once from Supabase, ~24KB).
/// Every search filters from this list — zero network requests.
final allProductsProvider = FutureProvider<List<Product>>((ref) async {
  final svc = ref.read(supabaseServiceProvider);
  return svc.fetchAllProducts();
});

/// Triggered on every keystroke — filters the local cache instantly.
final searchProductsProvider = FutureProvider<List<Product>>((ref) async {
  final query = ref.watch(scanSearchQueryProvider);
  if (query.isEmpty) return [];

  // Await the cached list (only blocks on very first search while fetching)
  final allProducts = await ref.watch(allProductsProvider.future);
  if (allProducts.isEmpty) return [];

  // Local synchronous filter — sub-millisecond on 24KB
  final lowerQuery = query.toLowerCase();
  return allProducts.where((p) {
    return p.name.toLowerCase().contains(lowerQuery) ||
        (p.barcode?.toLowerCase().contains(lowerQuery) ?? false) ||
        (p.aisle?.toLowerCase().contains(lowerQuery) ?? false) ||
        (p.sheetName?.toLowerCase().contains(lowerQuery) ?? false);
  }).toList();
});

final scanSearchQueryProvider = StateProvider<String>((ref) => '');

final totalDatabaseItemsProvider = FutureProvider<int>((ref) async {
  final svc = ref.watch(supabaseServiceProvider);
  return svc.fetchTotalCount();
});

final planogramDatesProvider = FutureProvider<List<String>>((ref) async {
  final svc = ref.watch(supabaseServiceProvider);
  return svc.fetchUniqueDates();
});

final planogramSheetsProvider =
    FutureProvider.family<List<String>, String>((ref, date) async {
  final svc = ref.watch(supabaseServiceProvider);
  return svc.fetchUniqueSheetsForDate(date);
});

final groupedProductsBySheetProvider = FutureProvider.family<
    List<AisleProductGroup>, ({String date, String sheet})>((ref, arg) async {
  final svc = ref.watch(supabaseServiceProvider);
  return svc.fetchGroupedByAisle(arg.date, arg.sheet);
});

/// One-time fix: migrates any existing ENT products from OGE to FGE.
/// No-op on Supabase since the schema already enforces correct routing.
final fixEntDataProvider = FutureProvider<int>((ref) async {
  return 0;
});
