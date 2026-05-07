import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/product_model.dart';

class AisleProductGroup {
  final String aisle;
  final List<Product> products;

  const AisleProductGroup({
    required this.aisle,
    required this.products,
  });
}

class LocalProductDatabase {
  LocalProductDatabase._();

  static final LocalProductDatabase instance = LocalProductDatabase._();
  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dbPath, 'woolies_products.db'),
      version: 3,
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
            planogram_date TEXT,
            sheet_name TEXT,
            image_path TEXT,
            quantity INTEGER NOT NULL DEFAULT 1,
            scanned_at TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE scanned_products ADD COLUMN planogram_date TEXT');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE scanned_products ADD COLUMN sheet_name TEXT');
        }
      },
    );
    return _db!;
  }

  Future<void> insertProducts(List<Product> products) async {
    if (products.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();

    try {
      for (final product in products) {
        batch.insert('scanned_products', {
          'name': product.name,
          'brand': product.brand,
          'weight': product.weight,
          'estimated_price': product.estimatedPrice,
          'category': product.category,
          'barcode': product.barcode,
          'aisle': product.aisle,
          'planogram_date': product.planogramDate,
          'sheet_name': product.sheetName,
          'image_path': product.imagePath,
          'quantity': product.quantity,
          'scanned_at': now,
        });
      }
      await batch.commit(noResult: true);
      debugPrint('DB: Successfully inserted ${products.length} products');
    } catch (e) {
      debugPrint('DB Error inserting products: $e');
      rethrow;
    }
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('scanned_products');
  }

  Future<void> deleteByDate(String date) async {
    final db = await database;
    if (date == 'No Date') {
      await db.delete('scanned_products', where: 'planogram_date IS NULL OR planogram_date = ?', whereArgs: ['']);
    } else {
      await db.delete('scanned_products', where: 'planogram_date = ?', whereArgs: [date]);
    }
  }

  Future<List<String>> fetchUniqueDates() async {
    final db = await database;
    final rows = await db.query(
      'scanned_products',
      columns: ['planogram_date'],
      distinct: true,
      orderBy: 'planogram_date DESC',
    );
    return rows
        .map((e) => (e['planogram_date'] as String?) ?? 'No Date')
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<List<String>> fetchUniqueSheetsForDate(String date) async {
    final db = await database;
    final rows = await db.query(
      'scanned_products',
      columns: ['sheet_name'],
      where: 'planogram_date = ?',
      whereArgs: [date],
      distinct: true,
      orderBy: 'sheet_name ASC',
    );
    return rows
        .map((e) => (e['sheet_name'] as String?) ?? 'General')
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<List<AisleProductGroup>> fetchGroupedByAisleForDateAndSheet(String date, String sheet) async {
    final db = await database;
    final rows = await db.query(
      'scanned_products',
      where: 'planogram_date = ? AND sheet_name = ?',
      whereArgs: [date, sheet],
      orderBy: "COALESCE(NULLIF(aisle, ''), 'UNKNOWN') ASC, name COLLATE NOCASE ASC",
    );

    final grouped = <String, List<Product>>{};
    for (final row in rows) {
      final aisle = ((row['aisle'] as String?)?.trim().isNotEmpty ?? false)
          ? (row['aisle'] as String).trim()
          : 'Unknown';
      grouped.putIfAbsent(aisle, () => []).add(_fromRow(row));
    }

    return grouped.entries
        .map((e) => AisleProductGroup(aisle: e.key, products: e.value))
        .toList();
  }

  Future<List<Product>> searchProducts(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return [];

    final db = await database;
    final rows = await db.query(
      'scanned_products',
      where: 'LOWER(name) LIKE ? OR LOWER(brand) LIKE ? OR LOWER(aisle) LIKE ?',
      whereArgs: [
        '%${normalized.toLowerCase()}%',
        '%${normalized.toLowerCase()}%',
        '%${normalized.toLowerCase()}%'
      ],
      orderBy: 'name COLLATE NOCASE ASC',
      limit: 50,
    );

    return rows.map(_fromRow).toList();
  }

  Future<int> fetchTotalCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM scanned_products');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Product _fromRow(Map<String, Object?> row) {
    return Product(
      id: (row['id'] as int).toString(),
      name: row['name'] as String,
      brand: row['brand'] as String?,
      weight: row['weight'] as String?,
      estimatedPrice: (row['estimated_price'] as num).toDouble(),
      category: row['category'] as String,
      barcode: row['barcode'] as String?,
      aisle: row['aisle'] as String?,
      planogramDate: row['planogram_date'] as String?,
      sheetName: row['sheet_name'] as String?,
      imagePath: row['image_path'] as String?,
      quantity: row['quantity'] as int? ?? 1,
    );
  }
}
