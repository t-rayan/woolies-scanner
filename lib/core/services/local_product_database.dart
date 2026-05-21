import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/product_model.dart';
import 'package:intl/intl.dart';

class AisleProductGroup {
  final String aisle;
  final List<Product> products;
  const AisleProductGroup({required this.aisle, required this.products});
}

/// Summary of one sheet/category for the two-folder view.
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

class LocalProductDatabase {
  LocalProductDatabase._();
  static final LocalProductDatabase instance = LocalProductDatabase._();
  static Database? _db;

  String normalizeDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty || rawDate == 'No Date') {
      return DateFormat('dd/MM/yyyy').format(DateTime.now());
    }
    try {
      final clean = rawDate.replaceAll(RegExp(r'[^0-9/-]'), '').trim();
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

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'woolies_products_v5_final.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE scanned_products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            brand TEXT,
            weight TEXT,
            estimated_price REAL NOT NULL,
            category TEXT NOT NULL,
            barcode TEXT,
            aisle TEXT,
            planogram_date TEXT NOT NULL,
            sheet_name TEXT NOT NULL,
            image_path TEXT,
            quantity INTEGER NOT NULL DEFAULT 1,
            scanned_at TEXT NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  /// Determines the correct sheet category from aisle/section ID.
  /// Rules:
  ///   OGE = ONLY boxes labeled OGE001 through OGE012
  ///   FGE = Everything else: FGE boxes, ENT (Entrance),
  ///         POS (Front of Store Flexi Stand), BIN (Front of Store BIN)
  String categorizeSheet(String? sheetName, String? aisle) {
    final sheet = (sheetName ?? '').toUpperCase().trim();
    final aisleId = (aisle ?? '').toUpperCase().trim();

    // FGE ROUTES: anything that belongs to Front-of-Store
    final fgePatterns = ['FGE', 'ENT', 'POS', 'BIN', 'FRONT OF STORE', 'FLEXI'];

    // If sheet or aisle starts with any FGE pattern, route to FGE
    for (final pattern in fgePatterns) {
      if (aisleId.startsWith(pattern) || sheet.startsWith(pattern)) {
        return 'FGE';
      }
    }

    // OGE ROUTE: ONLY boxes labeled OGE001-OGE012
    if (aisleId.contains('OGE') || sheet.contains('OGE')) {
      return 'OGE';
    }

    // Default fallback: if sheet is specified, use it; otherwise OGE
    if (sheet.isNotEmpty) return sheet;
    return 'OGE';
  }

  /// Fixes existing data: updates any ENT/POS/BIN products stored as OGE to FGE.
  Future<int> fixExistingEntData() async {
    final db = await database;
    final count = await db.update(
      'scanned_products',
      {'sheet_name': 'FGE'},
      where: "UPPER(sheet_name) = 'OGE' AND ("
          "UPPER(aisle) LIKE 'ENT%' OR "
          "UPPER(aisle) LIKE 'POS%' OR "
          "UPPER(aisle) LIKE 'BIN%' OR "
          "UPPER(aisle) LIKE 'FRONT OF STORE%' OR "
          "UPPER(aisle) LIKE 'FLEXI%'"
          ")",
    );
    return count;
  }

  Future<void> insertProducts(List<Product> products) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final product in products) {
        final cleanDate = normalizeDate(product.planogramDate);
        final correctedSheet = categorizeSheet(
          product.sheetName,
          product.aisle,
        );
        final map = product.toMap();
        map['planogram_date'] = cleanDate;
        map['sheet_name'] = correctedSheet;
        await txn.insert('scanned_products', map);
      }
    });
  }

  Future<List<String>> fetchUniqueDates() async {
    final db = await database;
    final rows = await db.rawQuery(
        'SELECT DISTINCT planogram_date FROM scanned_products ORDER BY planogram_date DESC');
    return rows.map((e) => e['planogram_date'] as String).toList();
  }

  Future<List<String>> fetchUniqueSheetsForDate(String date) async {
    final db = await database;
    final cleanDate = normalizeDate(date);
    final rows = await db.query('scanned_products',
        columns: ['sheet_name'],
        where: 'planogram_date = ?',
        whereArgs: [cleanDate],
        distinct: true);
    return rows.map((e) => e['sheet_name'] as String).toList();
  }

  Future<List<AisleProductGroup>> fetchGroupedByAisle(
      String date, String sheet) async {
    final db = await database;
    final cleanDate = normalizeDate(date);
    final cleanSheet = sheet.toUpperCase().trim();

    String whereClause = 'planogram_date = ? AND UPPER(sheet_name) = ?';
    List<dynamic> whereArgs = [cleanDate, cleanSheet];

    // When querying OGE, exclude ENT/POS/BIN products (they belong to FGE)
    if (cleanSheet == 'OGE') {
      whereClause += " AND (aisle IS NULL OR "
          "(UPPER(aisle) NOT LIKE 'ENT%' AND "
          "UPPER(aisle) NOT LIKE 'POS%' AND "
          "UPPER(aisle) NOT LIKE 'BIN%' AND "
          "UPPER(aisle) NOT LIKE 'FRONT OF STORE%' AND "
          "UPPER(aisle) NOT LIKE 'FLEXI%'"
          "))";
    }

    final rows = await db.query('scanned_products',
        where: whereClause, whereArgs: whereArgs, orderBy: 'aisle ASC');

    final Map<String, List<Product>> grouped = {};
    for (var row in rows) {
      final p = Product.fromMap(row);
      final aisle = (p.aisle ?? 'GENERAL').toUpperCase();
      grouped.putIfAbsent(aisle, () => []).add(p);
    }

    return grouped.entries
        .map((e) => AisleProductGroup(aisle: e.key, products: e.value))
        .toList();
  }

  Future<List<Product>> searchProducts(String query) async {
    final db = await database;
    final searchTerm = '%$query%';
    final rows = await db.query(
      'scanned_products',
      where:
          'name LIKE ? OR barcode LIKE ? OR aisle LIKE ? OR sheet_name LIKE ?',
      whereArgs: [searchTerm, searchTerm, searchTerm, searchTerm],
      orderBy: 'name ASC',
    );
    return rows.map((row) => Product.fromMap(row)).toList();
  }

  Future<int> fetchTotalCount() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM scanned_products');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Fetches grouped product counts per sheet category for a given date.
  /// ENT/POS/BIN products are always counted under FGE, never OGE.
  Future<List<SheetCategorySummary>> fetchGroupedCountsByDate(
      String date) async {
    final db = await database;
    final cleanDate = normalizeDate(date);

    // Count OGE products (excluding ENT/POS/BIN/FRONT/FLEXI)
    final ogeResult = await db.rawQuery(
      "SELECT COUNT(*) as count FROM scanned_products "
      "WHERE planogram_date = ? AND UPPER(sheet_name) = 'OGE' "
      "AND (aisle IS NULL OR "
      "(UPPER(aisle) NOT LIKE 'ENT%' AND "
      "UPPER(aisle) NOT LIKE 'POS%' AND "
      "UPPER(aisle) NOT LIKE 'BIN%' AND "
      "UPPER(aisle) NOT LIKE 'FRONT OF STORE%' AND "
      "UPPER(aisle) NOT LIKE 'FLEXI%'"
      "))",
      [cleanDate],
    );
    final ogeCount = Sqflite.firstIntValue(ogeResult) ?? 0;

    // Count FGE products (including ENT/POS/BIN)
    final fgeResult = await db.rawQuery(
      "SELECT COUNT(*) as count FROM scanned_products "
      "WHERE planogram_date = ? AND "
      "(UPPER(sheet_name) = 'FGE' OR "
      "UPPER(aisle) LIKE 'ENT%' OR "
      "UPPER(aisle) LIKE 'POS%' OR "
      "UPPER(aisle) LIKE 'BIN%' OR "
      "UPPER(aisle) LIKE 'FRONT OF STORE%' OR "
      "UPPER(aisle) LIKE 'FLEXI%')",
      [cleanDate],
    );
    final fgeCount = Sqflite.firstIntValue(fgeResult) ?? 0;

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
    final db = await database;
    final cleanDate = normalizeDate(date);
    await db.delete('scanned_products',
        where: 'planogram_date = ?', whereArgs: [cleanDate]);
  }

  /// Deletes all products for a specific date AND sheet category.
  Future<int> deleteByDateAndSheet(String date, String sheet) async {
    final db = await database;
    final cleanDate = normalizeDate(date);
    final cleanSheet = sheet.toUpperCase().trim();
    return await db.delete(
      'scanned_products',
      where: 'planogram_date = ? AND sheet_name = ?',
      whereArgs: [cleanDate, cleanSheet],
    );
  }

  /// Deletes all entries where sheet_name starts with 'FGE' or 'ENT'.
  /// Keeps OGE and any other data intact.
  Future<int> deleteFgeAndEntData() async {
    final db = await database;
    final count = await db.delete(
      'scanned_products',
      where: "UPPER(sheet_name) LIKE 'FGE%' OR UPPER(sheet_name) LIKE 'ENT%'",
    );
    return count;
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('scanned_products');
  }
}
