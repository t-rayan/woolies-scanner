import 'dart:convert';

/// Status flags that are critical for Tuesday night setups.
enum ItemStatus { normal, added, removed }

/// Represents a single product/item in an FGE section.
class FgeItem {
  final String name;
  final String ref;
  final String
      position; // e.g., "left_vertical", "right_vertical", "top", "bottom"
  final ItemStatus status;

  const FgeItem({
    required this.name,
    required this.ref,
    this.position = 'default',
    this.status = ItemStatus.normal,
  });

  bool get isRemoved => status == ItemStatus.removed;
  bool get isAdded => status == ItemStatus.added;

  Map<String, dynamic> toMap() => {
        'name': name,
        'ref': ref,
        'position': position,
        'status': status.name,
      };

  factory FgeItem.fromMap(Map<String, dynamic> map) => FgeItem(
        name: map['name'] as String? ?? 'Unknown',
        ref: map['ref'] as String? ?? '',
        position: map['position'] as String? ?? 'default',
        status: switch (map['status'] as String? ?? 'normal') {
          'added' => ItemStatus.added,
          'removed' => ItemStatus.removed,
          _ => ItemStatus.normal,
        },
      );
}

/// A shelf within a standard shelved FGE section.
class FgeShelf {
  final int level;
  final List<FgeItem> items;

  const FgeShelf({required this.level, required this.items});

  Map<String, dynamic> toMap() => {
        'level': level,
        'items': items.map((i) => i.toMap()).toList(),
      };

  factory FgeShelf.fromMap(Map<String, dynamic> map) => FgeShelf(
        level: map['level'] as int? ?? 1,
        items: (map['items'] as List<dynamic>?)
                ?.map((e) => FgeItem.fromMap(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

/// Layout type determines how the UI renders this section.
enum FgeLayoutType {
  standardShelved, // Regular 5-6 horizontal shelves (most FGE boxes)
  verticalBulk, // Single full-height column (e.g., FGE007 Bulk End)
  sideStack, // Side stack display
  entranceBin, // Front of Store Bin
  unknown;

  static FgeLayoutType fromString(String value) {
    switch (value.toLowerCase().trim()) {
      case 'standard_shelved':
      case 'standard':
      case 'standardshelved':
        return FgeLayoutType.standardShelved;
      case 'vertical_bulk':
      case 'bulk':
      case 'verticalbulk':
        return FgeLayoutType.verticalBulk;
      case 'side_stack':
      case 'sidestack':
        return FgeLayoutType.sideStack;
      case 'entrance_bin':
      case 'entrancebin':
        return FgeLayoutType.entranceBin;
      default:
        return FgeLayoutType.unknown;
    }
  }
}

/// One section in the FGE sheet — could be FGE001–FGE012, ENT001, or Front of Store Bin.
class FgeSection {
  final String id;
  final FgeLayoutType layoutType;
  final String header; // e.g., "HEADER - 1/2 PRICE", "HEADER - 40% OFF"
  final String notes; // e.g., "BULK END ONLY - shelves to be removed"
  final List<FgeItem> items; // Used for vertical_bulk and side_stack layouts
  final List<FgeShelf> shelves; // Used for standard_shelved layout

  const FgeSection({
    required this.id,
    required this.layoutType,
    this.header = '',
    this.notes = '',
    this.items = const [],
    this.shelves = const [],
  });

  /// Total number of products across all items/shelves.
  int get totalProducts {
    if (items.isNotEmpty) return items.length;
    return shelves.fold(0, (sum, s) => sum + s.items.length);
  }

  /// All items flattened regardless of layout type (for global search).
  List<FgeItem> get allItems {
    if (items.isNotEmpty) return items;
    return shelves.expand((s) => s.items).toList();
  }

  /// All ref numbers across this section.
  List<String> get allRefs =>
      allItems.map((i) => i.ref).where((r) => r.isNotEmpty).toList();

  bool get hasRemovedItems => allItems.any((i) => i.isRemoved);
  bool get hasAddedItems => allItems.any((i) => i.isAdded);

  Map<String, dynamic> toMap() => {
        'id': id,
        'layout_type': layoutType.name,
        'header': header,
        'notes': notes,
        if (items.isNotEmpty) 'items': items.map((i) => i.toMap()).toList(),
        if (shelves.isNotEmpty)
          'shelves': shelves.map((s) => s.toMap()).toList(),
      };

  factory FgeSection.fromMap(Map<String, dynamic> map) {
    final layout =
        FgeLayoutType.fromString(map['layout_type'] as String? ?? '');
    return FgeSection(
      id: map['id'] as String? ?? '',
      layoutType: layout,
      header: map['header'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      items: (map['items'] as List<dynamic>?)
              ?.map((e) => FgeItem.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      shelves: (map['shelves'] as List<dynamic>?)
              ?.map((e) => FgeShelf.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Top-level FGE planogram structure.
class FgePlanogram {
  final String planogramDate;
  final String sheetType;
  final List<FgeSection> sections;

  const FgePlanogram({
    required this.planogramDate,
    required this.sheetType,
    required this.sections,
  });

  int get totalSections => sections.length;
  int get totalProducts => sections.fold(0, (sum, s) => sum + s.totalProducts);

  /// Search all ref numbers across all sections. Returns matching sections.
  List<FgeSection> searchByRef(String query) {
    if (query.isEmpty) return sections;
    final q = query.toLowerCase().trim();
    return sections.where((s) {
      return s.allRefs.any((r) => r.toLowerCase().contains(q));
    }).toList();
  }

  /// Search by product name.
  List<FgeSection> searchByName(String query) {
    if (query.isEmpty) return sections;
    final q = query.toLowerCase().trim();
    return sections.where((s) {
      return s.allItems.any((i) => i.name.toLowerCase().contains(q));
    }).toList();
  }

  Map<String, dynamic> toMap() => {
        'planogram_date': planogramDate,
        'sheet_type': sheetType,
        'sections': sections.map((s) => s.toMap()).toList(),
      };

  factory FgePlanogram.fromMap(Map<String, dynamic> map) => FgePlanogram(
        planogramDate: map['planogram_date'] as String? ?? '',
        sheetType: map['sheet_type'] as String? ??
            'Front Gondola Ends & Entrance Display',
        sections: (map['sections'] as List<dynamic>?)
                ?.map((e) => FgeSection.fromMap(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  String toJson() => json.encode(toMap());

  factory FgePlanogram.fromJson(String source) =>
      FgePlanogram.fromMap(json.decode(source) as Map<String, dynamic>);
}
