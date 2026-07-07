import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_model.dart';
import 'package:intl/intl.dart';

/// Always-visible console logger (works on web + native).
void _dbLog(Object? message) {
  // ignore: avoid_print
  print('[SUPABASE] $message');
}

/// Wraps Supabase client and provides all CRUD operations
/// previously handled by sqflite's LocalProductDatabase.
class SupabaseService {
  static SupabaseService? _instance;
  late final SupabaseClient _client;
  bool _initialized = false;

  SupabaseService._();

  static SupabaseService get instance {
    _instance ??= SupabaseService._();
    return _instance!;
  }

  /// Must be called once before any DB operations (e.g. in main()).
  ///
  /// [supabaseUrl] and [supabaseAnonKey] are now passed explicitly.
  /// In production, the caller should use `const String.fromEnvironment()`
  /// (injected via `--dart-define` in the CI build).
  // Future<void> initialize({
  //   String supabaseUrl = '',
  //   String supabaseAnonKey = '',
  // }) async {
  //   if (_initialized) return;

  //   if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
  //     debugPrint(
  //       '⚠️ Supabase credentials missing (url empty=${supabaseUrl.isEmpty}, '
  //       'key empty=${supabaseAnonKey.isEmpty}) — DB features unavailable.',
  //     );
  //     return;
  //   }

  //   debugPrint('🔌 Initializing Supabase with URL: $supabaseUrl');

  //   await Supabase.initialize(
  //     url: supabaseUrl,
  //     anonKey: supabaseAnonKey,
  //     debug: kDebugMode,
  //   );

  //   _client = Supabase.instance.client;
  //   _initialized = true;
  //   debugPrint('✅ Supabase initialized successfully');
  // }

  // my custom code

  /// Must be called once before any DB operations (e.g. in main()).
  ///
  /// Forces Web builds to grab keys directly from compile-time terminal environment variables.
  Future<void> initialize({
    String supabaseUrl = '',
    String supabaseAnonKey = '',
  }) async {
    if (_initialized) return;

    // 1. Declare explicit compile-time constants (removed 'static')
    const String _webUrl = String.fromEnvironment('SUPABASE_URL');
    const String _webKey = String.fromEnvironment('SUPABASE_ANON_KEY');

    // 2. Intercept and override if running on Web browser
    String finalUrl = supabaseUrl;
    String finalKey = supabaseAnonKey;

    if (kIsWeb) {
      finalUrl = _webUrl;
      finalKey = _webKey;
    }

    if (finalUrl.isEmpty || finalKey.isEmpty) {
      debugPrint(
        '⚠️ Supabase credentials missing (url empty=${finalUrl.isEmpty}, '
        'key empty=${finalKey.isEmpty}) — DB features unavailable.',
      );
      return;
    }

    debugPrint('🔌 Initializing Supabase with URL: $finalUrl');

    await Supabase.initialize(
      url: finalUrl,
      anonKey: finalKey,
      debug: kDebugMode,
    );

    _client = Supabase.instance.client;
    _initialized = true;
    debugPrint('✅ Supabase initialized successfully');
  }
  // my code ends here

  SupabaseClient get client {
    if (!_initialized) {
      throw StateError(
        'SupabaseService not initialized. Call initialize() first.',
      );
    }
    return _client;
  }

  // ------- Date helpers (mirrors LocalProductDatabase) -------

  static String normalizeDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty || rawDate == 'No Date') {
      return DateFormat('dd/MM/yyyy').format(DateTime.now());
    }
    try {
      final clean = rawDate
          .replaceAll(RegExp(r'[^0-9/-]'), '')
          .trim()
          .replaceAll('-', '/');
      DateTime parsed;
      if (clean.contains('/')) {
        final parts = clean.split('/');
        if (parts.length == 3) {
          int day = int.parse(parts[0]);
          int month = int.parse(parts[1]);
          int year = int.parse(parts[2]);
          if (year < 100) year += 2000;
          parsed = DateTime(year, month, day);
        } else {
          throw Exception();
        }
      } else {
        parsed = DateTime.parse(clean);
      }
      return DateFormat('dd/MM/yyyy').format(parsed);
    } catch (e) {
      return DateFormat('dd/MM/yyyy').format(DateTime.now());
    }
  }

  /// Determines the correct sheet category from aisle/section ID.
  static String categorizeSheet(String? sheetName, String? aisle) {
    final sheet = (sheetName ?? '').toUpperCase().trim();
    final aisleId = (aisle ?? '').toUpperCase().trim();

    final fgePatterns = ['FGE', 'ENT', 'POS', 'BIN', 'FRONT OF STORE', 'FLEXI'];
    for (final pattern in fgePatterns) {
      if (aisleId.startsWith(pattern) || sheet.startsWith(pattern)) {
        return 'FGE';
      }
    }
    if (aisleId.contains('OGE') || sheet.contains('OGE')) {
      return 'OGE';
    }
    if (sheet.isNotEmpty) return sheet;
    return 'OGE';
  }

  /// Helper: log a database error with full context.
  void _logError(String operation, Object error) {
    _dbLog('❌ $operation failed: $error');
    if (error is PostgrestException) {
      _dbLog('   Code: ${error.code}');
      _dbLog('   Message: ${error.message}');
      _dbLog('   Details: ${error.details}');
      _dbLog('   Hint: ${error.hint}');
    }
  }

  /// Check that the client is ready — returns false if not initialized.
  bool get isReady => _initialized;

  // ------- CRUD Operations -------

  Future<void> insertProducts(List<Product> products) async {
    final payload = products.map((product) {
      final cleanDate = normalizeDate(product.planogramDate);
      final correctedSheet = categorizeSheet(product.sheetName, product.aisle);
      final map = product.toMap();
      map['planogram_date'] = cleanDate;
      map['sheet_name'] = correctedSheet;
      map['created_at'] = DateTime.now().toUtc().toIso8601String();
      return map;
    }).toList();

    try {
      await client.from('scanned_products').insert(payload);
    } catch (e) {
      _logError('insertProducts', e);
      rethrow;
    }
  }

  Future<List<String>> fetchUniqueDates() async {
    try {
      final response = await client
          .from('scanned_products')
          .select('planogram_date')
          .order('planogram_date', ascending: false);

      final dates = <String>{};
      for (final row in response) {
        final d = row['planogram_date'] as String?;
        if (d != null && d.isNotEmpty) dates.add(d);
      }
      return dates.toList();
    } catch (e) {
      _logError('fetchUniqueDates', e);
      return [];
    }
  }

  Future<List<String>> fetchUniqueSheetsForDate(String date) async {
    try {
      final cleanDate = normalizeDate(date);
      final response = await client
          .from('scanned_products')
          .select('sheet_name')
          .eq('planogram_date', cleanDate);

      final sheets = <String>{};
      for (final row in response) {
        final s = row['sheet_name'] as String?;
        if (s != null && s.isNotEmpty) sheets.add(s);
      }
      return sheets.toList();
    } catch (e) {
      _logError('fetchUniqueSheetsForDate', e);
      return [];
    }
  }

  Future<List<AisleProductGroup>> fetchGroupedByAisle(
      String date, String sheet) async {
    try {
      final cleanDate = normalizeDate(date);
      final cleanSheet = sheet.toUpperCase().trim();

      var query = client
          .from('scanned_products')
          .select()
          .eq('planogram_date', cleanDate);

      // Simple filter by sheet_name — already corrected during insertion
      query = query.eq('sheet_name', cleanSheet);

      final response = await query.order('aisle', ascending: true);
      final rows = (response as List).cast<Map<String, dynamic>>();
      final parsed = rows.map((r) => Product.fromMap(r)).toList();

      final Map<String, List<Product>> grouped = {};
      for (final p in parsed) {
        final aisle = (p.aisle ?? 'GENERAL').toUpperCase();
        grouped.putIfAbsent(aisle, () => []).add(p);
      }

      return grouped.entries
          .map((e) => AisleProductGroup(aisle: e.key, products: e.value))
          .toList();
    } catch (e) {
      _logError('fetchGroupedByAisle', e);
      return [];
    }
  }

  /// Fetches EVERY row from scanned_products (dataset is ~24KB).
  /// Used for offline-first local caching — called once at app init.
  Future<List<Product>> fetchAllProducts() async {
    try {
      final response = await client
          .from('scanned_products')
          .select()
          .order('name', ascending: true);

      final rows = (response as List).cast<Map<String, dynamic>>();
      final products = rows.map((r) => Product.fromMap(r)).toList();
      _dbLog('Fetched ${products.length} products into local cache');
      return products;
    } catch (e) {
      _logError('fetchAllProducts', e);
      return [];
    }
  }

  /// Legacy search — no longer called from UI (kept for reference / direct use).
  /// Use [fetchAllProducts] + local filtering instead.
  Future<List<Product>> searchProducts(String query) async {
    try {
      final searchTerm = '%$query%';
      final response = await client
          .from('scanned_products')
          .select()
          .or(
            'name.ilike.$searchTerm,'
            'barcode.ilike.$searchTerm,'
            'aisle.ilike.$searchTerm,'
            'sheet_name.ilike.$searchTerm',
          )
          .order('name', ascending: true);

      final rows = (response as List).cast<Map<String, dynamic>>();
      return rows.map((r) => Product.fromMap(r)).toList();
    } catch (e) {
      _logError('searchProducts', e);
      return [];
    }
  }

  Future<int> fetchTotalCount() async {
    try {
      final rows = await client.from('scanned_products').select('id');
      return rows.length;
    } catch (e) {
      _logError('fetchTotalCount', e);
      return 0;
    }
  }

  Future<List<SheetCategorySummary>> fetchGroupedCountsByDate(
      String date) async {
    try {
      final cleanDate = normalizeDate(date);

      final ogeRows = await client
          .from('scanned_products')
          .select('id')
          .eq('planogram_date', cleanDate)
          .eq('sheet_name', 'OGE');
      final ogeCount = ogeRows.length;

      final fgeRows = await client
          .from('scanned_products')
          .select('id')
          .eq('planogram_date', cleanDate)
          .eq('sheet_name', 'FGE');
      final fgeCount = fgeRows.length;

      final summaries = <SheetCategorySummary>[];
      if (ogeCount > 0) {
        summaries.add(SheetCategorySummary(
          sheetName: 'OGE',
          displayLabel: 'OGE - Back Ends',
          productCount: ogeCount,
        ));
      }
      if (fgeCount > 0) {
        summaries.add(SheetCategorySummary(
          sheetName: 'FGE',
          displayLabel: 'FGE - Front & Entrance',
          productCount: fgeCount,
        ));
      }
      return summaries;
    } catch (e) {
      _logError('fetchGroupedCountsByDate', e);
      return [];
    }
  }

  Future<void> deleteByDate(String date) async {
    final cleanDate = normalizeDate(date);
    await client
        .from('scanned_products')
        .delete()
        .eq('planogram_date', cleanDate);
  }

  Future<int> deleteByDateAndSheet(String date, String sheet) async {
    final cleanDate = normalizeDate(date);
    final cleanSheet = sheet.toUpperCase().trim();
    final response = await client
        .from('scanned_products')
        .delete()
        .eq('planogram_date', cleanDate)
        .eq('sheet_name', cleanSheet);
    return response.count ?? 0;
  }

  /// Fetches all products grouped by aisle for a given sheet type (FGE/OGE) across all dates.
  Future<List<AisleProductGroup>> fetchGroupedByAisleForSheet(
      String sheet) async {
    try {
      final cleanSheet = sheet.toUpperCase().trim();
      final response = await client
          .from('scanned_products')
          .select()
          .eq('sheet_name', cleanSheet)
          .order('aisle', ascending: true);

      final rows = (response as List).cast<Map<String, dynamic>>();
      final parsed = rows.map((r) => Product.fromMap(r)).toList();

      final Map<String, List<Product>> grouped = {};
      for (final p in parsed) {
        final aisle = (p.aisle ?? 'GENERAL').toUpperCase();
        grouped.putIfAbsent(aisle, () => []).add(p);
      }

      return grouped.entries
          .map((e) => AisleProductGroup(aisle: e.key, products: e.value))
          .toList();
    } catch (e) {
      _logError('fetchGroupedByAisleForSheet', e);
      return [];
    }
  }

  /// Counts total products for a given sheet type (FGE/OGE) across all dates.
  Future<int> fetchCountBySheet(String sheet) async {
    try {
      final cleanSheet = sheet.toUpperCase().trim();
      final rows = await client
          .from('scanned_products')
          .select('id')
          .eq('sheet_name', cleanSheet);
      return rows.length;
    } catch (e) {
      _logError('fetchCountBySheet', e);
      return 0;
    }
  }

  /// Deletes all products for a given sheet type (FGE/OGE) across all dates.
  Future<void> deleteBySheet(String sheet) async {
    final cleanSheet = sheet.toUpperCase().trim();
    await client.from('scanned_products').delete().eq('sheet_name', cleanSheet);
  }

  Future<void> clearAllData() async {
    await client.from('scanned_products').delete().neq('id', 0);
  }
}

class AisleProductGroup {
  final String aisle;
  final List<Product> products;
  const AisleProductGroup({required this.aisle, required this.products});
}

class SheetCategorySummary {
  final String sheetName;
  final String displayLabel;
  final int productCount;
  const SheetCategorySummary({
    required this.sheetName,
    required this.displayLabel,
    required this.productCount,
  });
}

class SupabaseSchema {
  /// This class exists only as documentation — run the SQL above manually.
  SupabaseSchema._();
}
