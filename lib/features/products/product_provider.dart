import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/product_model.dart';
import '../../core/services/supabase_service.dart';
import 'product_database_provider.dart';

final scanSearchQueryProvider = StateProvider<String>((ref) => '');

final searchProductsProvider = FutureProvider<List<Product>>((ref) async {
  final query = ref.watch(scanSearchQueryProvider);
  final svc = ref.read(supabaseServiceProvider);
  if (query.isEmpty) return [];
  return svc.searchProducts(query);
});

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
