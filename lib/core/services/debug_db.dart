import 'package:flutter/material.dart';
import 'local_product_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = LocalProductDatabase.instance;
  
  print('--- DATABASE DEBUG REPORT ---');
  try {
    final count = await db.fetchTotalCount();
    print('Total Products: $count');
    
    final dates = await db.fetchUniqueDates();
    print('Unique Dates: $dates');
    
    if (count > 0) {
      final database = await db.database;
      final rows = await database.query('scanned_products', limit: 10);
      print('First 10 Rows:');
      for (var row in rows) {
        print(' - ID: ${row['id']}, Name: ${row['name']}, Date: ${row['planogram_date']}, Sheet: ${row['sheet_name']}');
      }
    } else {
      print('Database is empty.');
    }
  } catch (e) {
    print('❌ Database Error: $e');
  }
  print('--- END REPORT ---');
}
