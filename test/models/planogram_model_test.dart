import 'package:flutter_test/flutter_test.dart';
import 'package:woolies_scanner/core/models/planogram_model.dart';

void main() {
  group('Planogram', () {
    test('fromMap() parses full planogram correctly', () {
      final json = {
        'planogram_date': '10/04/2025',
        'category': 'Back Gondola Ends',
        'aisles': [
          {
            'id': 'OGE001',
            'promo_type': '1/2 PRICE',
            'shelves': [
              {
                'level': 1,
                'products': [
                  {
                    'name': 'Coca Cola 1.25L',
                    'ref': ['9300633555032']
                  },
                  {
                    'name': 'Sprite 1.25L',
                    'ref': ['9300633555033']
                  },
                ],
              },
              {
                'level': 2,
                'products': [
                  {
                    'name': 'Fanta 1.25L',
                    'ref': ['9300633555034']
                  },
                ],
              },
            ],
          },
          {
            'id': 'OGE002',
            'promo_type': 'WEEKLY SPECIAL',
            'shelves': [
              {
                'level': 1,
                'products': [
                  {
                    'name': 'Smiths Chips',
                    'ref': ['9310054123456']
                  },
                ],
              },
            ],
          },
        ],
      };

      final planogram = Planogram.fromMap(json);

      expect(planogram.planogramDate, '10/04/2025');
      expect(planogram.category, 'Back Gondola Ends');
      expect(planogram.totalAisles, 2);
      expect(planogram.totalProducts, 4);

      // Check first aisle
      final aisle1 = planogram.aisles[0];
      expect(aisle1.id, 'OGE001');
      expect(aisle1.promoType, '1/2 PRICE');
      expect(aisle1.shelves.length, 2);
      expect(aisle1.totalProducts, 3);

      // Check first shelf
      final shelf1 = aisle1.shelves[0];
      expect(shelf1.level, 1);
      expect(shelf1.products.length, 2);
      expect(shelf1.products[0].name, 'Coca Cola 1.25L');
      expect(shelf1.products[0].ref, ['9300633555032']);
    });

    test('toMap() and fromMap() round-trip correctly', () {
      final original = Planogram(
        planogramDate: '10/04/2025',
        category: 'Back Gondola Ends',
        aisles: [
          PlanogramAisle(
            id: 'OGE005',
            promoType: '1/2 PRICE',
            shelves: [
              PlanogramShelf(
                level: 1,
                products: [
                  PlanogramProduct(
                    name: 'Test Product',
                    ref: ['123456', '789012'],
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      final map = original.toMap();
      final restored = Planogram.fromMap(map);

      expect(restored.planogramDate, original.planogramDate);
      expect(restored.category, original.category);
      expect(restored.totalAisles, 1);
      expect(restored.totalProducts, 1);
      expect(restored.aisles[0].id, 'OGE005');
      expect(restored.aisles[0].shelves[0].products[0].name, 'Test Product');
      expect(
          restored.aisles[0].shelves[0].products[0].ref, ['123456', '789012']);
    });

    test('fromMap() handles empty/missing fields', () {
      final planogram = Planogram.fromMap({});
      expect(planogram.planogramDate, '');
      expect(planogram.category, '');
      expect(planogram.totalAisles, 0);
      expect(planogram.totalProducts, 0);
    });

    test('PlanogramProduct handles ref as list of dynamic', () {
      final product = PlanogramProduct.fromMap({
        'name': 'Test',
        'ref': [123, 456],
      });
      expect(product.name, 'Test');
      expect(product.ref, ['123', '456']);
    });
  });
}
