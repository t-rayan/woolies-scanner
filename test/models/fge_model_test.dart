import 'package:flutter_test/flutter_test.dart';
import 'package:woolies_scanner/core/models/fge_model.dart';

void main() {
  group('FgeItem', () {
    test('fromMap() creates correct item', () {
      final item = FgeItem.fromMap({
        'name': 'Product A',
        'ref': '123456',
        'position': 'left_vertical',
        'status': 'added',
      });

      expect(item.name, 'Product A');
      expect(item.ref, '123456');
      expect(item.position, 'left_vertical');
      expect(item.status, ItemStatus.added);
      expect(item.isAdded, true);
      expect(item.isRemoved, false);
    });

    test('isRemoved returns true for removed items', () {
      final item = FgeItem(
        name: 'Product',
        ref: '123',
        status: ItemStatus.removed,
      );
      expect(item.isRemoved, true);
      expect(item.isAdded, false);
    });

    test('toMap() and fromMap() round-trip', () {
      final original = FgeItem(
        name: 'Test Item',
        ref: '789012',
        position: 'top',
        status: ItemStatus.normal,
      );

      final map = original.toMap();
      final restored = FgeItem.fromMap(map);

      expect(restored.name, original.name);
      expect(restored.ref, original.ref);
      expect(restored.position, original.position);
      expect(restored.status, original.status);
    });
  });

  group('FgeShelf', () {
    test('fromMap() creates shelf with items', () {
      final shelf = FgeShelf.fromMap({
        'level': 2,
        'items': [
          {'name': 'Item 1', 'ref': '111'},
          {'name': 'Item 2', 'ref': '222'},
        ],
      });

      expect(shelf.level, 2);
      expect(shelf.items.length, 2);
      expect(shelf.items[0].name, 'Item 1');
    });

    test('fromMap() handles empty items', () {
      final shelf = FgeShelf.fromMap({'level': 1});
      expect(shelf.items, []);
    });
  });

  group('FgeSection', () {
    test('calulates totalProducts from items', () {
      final section = FgeSection(
        id: 'FGE003',
        layoutType: FgeLayoutType.verticalBulk,
        items: [
          FgeItem(name: 'A', ref: '111'),
          FgeItem(name: 'B', ref: '222'),
          FgeItem(name: 'C', ref: '333'),
        ],
      );

      expect(section.totalProducts, 3);
    });

    test('calculates totalProducts from shelves', () {
      final section = FgeSection(
        id: 'FGE001',
        layoutType: FgeLayoutType.standardShelved,
        shelves: [
          FgeShelf(level: 1, items: [
            FgeItem(name: 'A', ref: '111'),
          ]),
          FgeShelf(level: 2, items: [
            FgeItem(name: 'B', ref: '222'),
            FgeItem(name: 'C', ref: '333'),
          ]),
        ],
      );

      expect(section.totalProducts, 3);
    });

    test('hasRemovedItems detects removed items', () {
      final section = FgeSection(
        id: 'FGE001',
        layoutType: FgeLayoutType.standardShelved,
        shelves: [
          FgeShelf(level: 1, items: [
            FgeItem(name: 'Removed', ref: '999', status: ItemStatus.removed),
          ]),
        ],
      );

      expect(section.hasRemovedItems, true);
      expect(section.hasAddedItems, false);
    });

    test('hasAddedItems detects added items', () {
      final section = FgeSection(
        id: 'FGE001',
        layoutType: FgeLayoutType.standardShelved,
        items: [
          FgeItem(name: 'New', ref: '888', status: ItemStatus.added),
        ],
      );

      expect(section.hasAddedItems, true);
      expect(section.hasRemovedItems, false);
    });

    test('allRefs returns non-empty refs', () {
      final section = FgeSection(
        id: 'FGE002',
        layoutType: FgeLayoutType.standardShelved,
        shelves: [
          FgeShelf(level: 1, items: [
            FgeItem(name: 'A', ref: '111'),
            FgeItem(name: 'B', ref: ''),
          ]),
        ],
      );

      expect(section.allRefs, ['111']);
    });

    test('toMap() and fromMap() round-trip for standard shelved', () {
      final original = FgeSection(
        id: 'FGE001',
        layoutType: FgeLayoutType.standardShelved,
        header: 'HEADER - 1/2 PRICE',
        notes: 'Some notes',
        shelves: [
          FgeShelf(level: 1, items: [
            FgeItem(name: 'Product', ref: '123456'),
          ]),
        ],
      );

      final map = original.toMap();
      final restored = FgeSection.fromMap(map);

      expect(restored.id, original.id);
      expect(restored.layoutType, original.layoutType);
      expect(restored.header, original.header);
      expect(restored.notes, original.notes);
      expect(restored.totalProducts, original.totalProducts);
    });

    test('toMap() and fromMap() round-trip for vertical bulk', () {
      final original = FgeSection(
        id: 'FGE007',
        layoutType: FgeLayoutType.verticalBulk,
        items: [
          FgeItem(name: 'Bulk Item', ref: '999999'),
        ],
      );

      final map = original.toMap();
      final restored = FgeSection.fromMap(map);

      expect(restored.id, original.id);
      expect(restored.layoutType, original.layoutType);
      expect(restored.totalProducts, 1);
    });
  });

  group('FgeLayoutType', () {
    test('fromString parses correctly', () {
      expect(FgeLayoutType.fromString('standard_shelved'), FgeLayoutType.standardShelved);
      expect(FgeLayoutType.fromString('standard'), FgeLayoutType.standardShelved);
      expect(FgeLayoutType.fromString('vertical_bulk'), FgeLayoutType.verticalBulk);
      expect(FgeLayoutType.fromString('bulk'), FgeLayoutType.verticalBulk);
      expect(FgeLayoutType.fromString('side_stack'), FgeLayoutType.sideStack);
      expect(FgeLayoutType.fromString('entrance_bin'), FgeLayoutType.entranceBin);
      expect(FgeLayoutType.fromString('unknown_type'), FgeLayoutType.unknown);
      expect(FgeLayoutType.fromString(''), FgeLayoutType.unknown);
    });
  });

  group('FgePlanogram', () {
    final samplePlanogram = FgePlanogram(
      planogramDate: '10/04/2025',
      sheetType: 'Front Gondola Ends & Entrance Display',
      sections: [
        FgeSection(
          id: 'BIN',
          layoutType: FgeLayoutType.entranceBin,
          items: [
            FgeItem(name: 'Bin Display', ref: '111111'),
          ],
        ),
        FgeSection(
          id: 'FGE001',
          layoutType: FgeLayoutType.standardShelved,
          shelves: [
            FgeShelf(level: 1, items: [
              FgeItem(name: 'Product A', ref: '222222'),
              FgeItem(name: 'Product B', ref: '333333'),
            ]),
          ],
        ),
        FgeSection(
          id: 'FGE002',
          layoutType: FgeLayoutType.verticalBulk,
          items: [
            FgeItem(name: 'Bulk Item', ref: '444444'),
          ],
        ),
      ],
    );

    test('totalSections and totalProducts are correct', () {
      expect(samplePlanogram.totalSections, 3);
      expect(samplePlanogram.totalProducts, 4);
    });

    test('searchByRef finds matching sections', () {
      final matches = samplePlanogram.searchByRef('222222');
      expect(matches.length, 1);
      expect(matches[0].id, 'FGE001');
    });

    test('searchByRef returns empty for no matches', () {
      expect(samplePlanogram.searchByRef('000000'), []);
    });

    test('searchByRef returns all sections for empty query', () {
      expect(samplePlanogram.searchByRef('').length, 3);
    });

    test('searchByName finds matching sections', () {
      final matches = samplePlanogram.searchByName('Bin Display');
      expect(matches.length, 1);
      expect(matches[0].id, 'BIN');
    });

    test('searchByName is case-insensitive', () {
      final matches = samplePlanogram.searchByName('bin display');
      expect(matches.length, 1);
    });

    test('searchByName returns empty for no matches', () {
      expect(samplePlanogram.searchByName('Nonexistent'), []);
    });

    test('toMap() and fromMap() round-trip', () {
      final map = samplePlanogram.toMap();
      final restored = FgePlanogram.fromMap(map);

      expect(restored.planogramDate, samplePlanogram.planogramDate);
      expect(restored.sheetType, samplePlanogram.sheetType);
      expect(restored.totalSections, samplePlanogram.totalSections);
      expect(restored.totalProducts, samplePlanogram.totalProducts);
      expect(restored.sections[0].id, 'BIN');
      expect(restored.sections[1].id, 'FGE001');
    });

    test('toJson() and fromJson() round-trip', () {
      final json = samplePlanogram.toJson();
      final restored = FgePlanogram.fromJson(json);

      expect(restored.planogramDate, '10/04/2025');
      expect(restored.totalSections, 3);
    });
  });
}
