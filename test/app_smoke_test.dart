import 'package:flutter_test/flutter_test.dart';
import 'package:woolies_scanner/core/models/product_model.dart';
import 'package:woolies_scanner/core/models/planogram_model.dart';
import 'package:woolies_scanner/core/models/fge_model.dart';

/// Smoke test — verifies that all model files can be imported and basic
/// constructors work without throwing.
void main() {
  test('Product can be constructed with minimal params', () {
    final product = Product(name: 'Test');
    expect(product.name, 'Test');
    expect(product.quantity, 1);
    expect(product.category, 'General');
  });

  test('Planogram can be constructed', () {
    final planogram = Planogram(
      planogramDate: '10/04/2025',
      category: 'Back Gondola Ends',
      aisles: [],
    );
    expect(planogram.totalAisles, 0);
    expect(planogram.totalProducts, 0);
  });

  test('FgePlanogram can be constructed', () {
    final fge = FgePlanogram(
      planogramDate: '10/04/2025',
      sheetType: 'FGE',
      sections: [],
    );
    expect(fge.totalSections, 0);
    expect(fge.totalProducts, 0);
  });

  test('ItemStatus enum values exist', () {
    expect(ItemStatus.normal.index, 0);
    expect(ItemStatus.added.index, 1);
    expect(ItemStatus.removed.index, 2);
  });
}
