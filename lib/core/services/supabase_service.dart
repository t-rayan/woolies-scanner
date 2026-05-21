import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_model.dart';
import 'package:intl/intl.dart';

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
  Future<void> initialize() async {
    if (_initialized) return;

    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (supabaseUrl == null || supabaseUrl.isEmpty) {
      debugPrint(
          '⚠️ SUPABASE_URL not set — some features will be unavailable.');
    }
    if (supabaseAnonKey == null || supabaseAnonKey.isEmpty) {
      debugPrint(
          '⚠️ SUPABASE_ANON_KEY not set — some features will be unavailable.');
    }

    await Supabase.initialize(
      url: supabaseUrl ?? '',
      anonKey: supabaseAnonKey ?? '',
      debug: kDebugMode,
    );

    _client = Supabase.instance.client;
    _initialized = true;
    debugPrint('✅ Supabase initialized');
  }

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

    await client.from('scanned_products').insert(payload);
  }

  Future<List<String>> fetchUniqueDates() async {
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
  }

  Future<List<String>> fetchUniqueSheetsForDate(String date) async {
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
  }

  Future<List<AisleProductGroup>> fetchGroupedByAisle(
      String date, String sheet) async {
    final cleanDate = normalizeDate(date);
    final cleanSheet = sheet.toUpperCase().trim();

    var query = client
        .from('scanned_products')
        .select()
        .eq('planogram_date', cleanDate);

    // For OGE, filter out ENT/POS/BIN products
    if (cleanSheet == 'OGE') {
      query = query
          .or(
            'sheet_name.eq.$cleanSheet,'
            'aisle.is.null,'
            'aisle.not.like.ENT%,'
            'aisle.not.like.POS%,'
            'aisle.not.like.BIN%,'
            'aisle.not.like.FRONT OF STORE%,'
            'aisle.not.like.FLEXI%',
          )
          .eq('planogram_date', cleanDate);
    } else {
      query = query.eq('sheet_name', cleanSheet);
    }

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
  }

  Future<List<Product>> searchProducts(String query) async {
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
  }

  Future<int> fetchTotalCount() async {
    final rows = await client.from('scanned_products').select('id');
    return rows.length;
  }

  Future<List<SheetCategorySummary>> fetchGroupedCountsByDate(
      String date) async {
    final cleanDate = normalizeDate(date);

    // Count OGE products

    final ogeRows = await client
        .from('scanned_products')
        .select('id')
        .eq('planogram_date', cleanDate)
        .eq('sheet_name', 'OGE');

    final ogeCount = ogeRows.length;

    // Count FGE products

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

  Future<void> clearAllData() async {
    await client.from('scanned_products').delete().neq('id', 0);
  }
}

// ------- Shared domain types (ported from local_product_database) -------

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

// ------- PostgreSQL schema migration SQL (for reference / Supabase SQL Editor) -------

/// Run this SQL in your Supabase project's SQL Editor to create the table:
///
/// ```sql
/// CREATE TABLE scanned_products (
///   id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
///   name TEXT NOT NULL,
///   brand TEXT,
///   weight TEXT,
///   estimated_price REAL NOT NULL DEFAULT 0,
///   category TEXT NOT NULL DEFAULT 'General',
///   barcode TEXT,
///   aisle TEXT,
///   planogram_date TEXT NOT NULL,
///   sheet_name TEXT NOT NULL DEFAULT 'OGE',
///   image_path TEXT,
///   quantity INTEGER NOT NULL DEFAULT 1,
///   scanned_at TEXT NOT NULL,
///   user_id UUID REFERENCES auth.users(id) DEFAULT auth.uid(),
///   created_at TIMESTAMPTZ DEFAULT NOW()
/// );
///
/// -- Enable Row Level Security
/// ALTER TABLE scanned_products ENABLE ROW LEVEL SECURITY;
///
/// -- RLS: users can only see their own data
/// CREATE POLICY "Users can view their own products"
///   ON scanned_products FOR SELECT
///   USING (auth.uid() = user_id);
///
/// -- RLS: users can insert their own data
/// CREATE POLICY "Users can insert their own products"
///   ON scanned_products FOR INSERT
///   WITH CHECK (auth.uid() = user_id);
///
/// -- RLS: users can update their own data
/// CREATE POLICY "Users can update their own products"
///   ON scanned_products FOR UPDATE
///   USING (auth.uid() = user_id);
///
/// -- RLS: users can delete their own data
/// CREATE POLICY "Users can delete their own products"
///   ON scanned_products FOR DELETE
///   USING (auth.uid() = user_id);
///
/// -- Indexes for common queries
/// CREATE INDEX idx_scanned_products_planogram_date
///   ON scanned_products (planogram_date DESC);
/// CREATE INDEX idx_scanned_products_sheet_name
///   ON scanned_products (sheet_name);
/// CREATE INDEX idx_scanned_products_user_id
///   ON scanned_products (user_id);
/// ```
class SupabaseSchema {
  /// This class exists only as documentation — run the SQL above manually.
  SupabaseSchema._();
}
