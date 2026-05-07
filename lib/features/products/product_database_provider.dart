import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/local_product_database.dart';

final localProductDatabaseProvider = Provider<LocalProductDatabase>((ref) {
  return LocalProductDatabase.instance;
});
