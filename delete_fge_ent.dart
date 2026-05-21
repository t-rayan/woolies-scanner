import 'package:flutter/material.dart';
import 'lib/core/services/local_product_database.dart';

/// Run this file to delete all FGE and ENT entries from the database.
/// Keeps all OGE data intact.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('=' * 50);
  print('DELETING FGE & ENT DATA...');
  print('=' * 50);

  final db = LocalProductDatabase.instance;
  
  try {
    // Check current count
    final before = await db.fetchTotalCount();
    print('Total products BEFORE: $before');

    // Perform deletion
    final deleted = await db.deleteFgeAndEntData();
    print('Deleted: $deleted FGE/ENT entries');

    // Check remaining count
    final after = await db.fetchTotalCount();
    print('Total products AFTER: $after');

    // Show what's left
    final dates = await db.fetchUniqueDates();
    print('Remaining dates: $dates');
    
    for (final date in dates) {
      final sheets = await db.fetchUniqueSheetsForDate(date);
      print('  $date → sheets: $sheets');
    }

    print('\n✅ Done! OGE data preserved.');
  } catch (e) {
    print('❌ Error: $e');
  }
}
