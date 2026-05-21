import 'dart:convert';

/// Represents a single product on a shelf
class PlanogramProduct {
  final String name;
  final List<String> ref;

  const PlanogramProduct({
    required this.name,
    required this.ref,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'ref': ref,
      };

  factory PlanogramProduct.fromMap(Map<String, dynamic> map) => PlanogramProduct(
        name: map['name'] as String? ?? 'Unknown',
        ref: (map['ref'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );
}

/// Represents a single shelf level within an aisle
class PlanogramShelf {
  final int level;
  final List<PlanogramProduct> products;

  const PlanogramShelf({
    required this.level,
    required this.products,
  });

  Map<String, dynamic> toMap() => {
        'level': level,
        'products': products.map((p) => p.toMap()).toList(),
      };

  factory PlanogramShelf.fromMap(Map<String, dynamic> map) => PlanogramShelf(
        level: map['level'] as int? ?? 1,
        products: (map['products'] as List<dynamic>?)
                ?.map((e) =>
                    PlanogramProduct.fromMap(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

/// Represents one gondola end / aisle (OGE001 - OGE012)
class PlanogramAisle {
  final String id;
  final String promoType;
  final List<PlanogramShelf> shelves;

  const PlanogramAisle({
    required this.id,
    required this.promoType,
    required this.shelves,
  });

  int get totalProducts =>
      shelves.fold(0, (sum, shelf) => sum + shelf.products.length);

  Map<String, dynamic> toMap() => {
        'id': id,
        'promo_type': promoType,
        'shelves': shelves.map((s) => s.toMap()).toList(),
      };

  factory PlanogramAisle.fromMap(Map<String, dynamic> map) => PlanogramAisle(
        id: map['id'] as String? ?? '',
        promoType: map['promo_type'] as String? ?? '',
        shelves: (map['shelves'] as List<dynamic>?)
                ?.map((e) =>
                    PlanogramShelf.fromMap(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

/// Top-level planogram structure
class Planogram {
  final String planogramDate;
  final String category;
  final List<PlanogramAisle> aisles;

  const Planogram({
    required this.planogramDate,
    required this.category,
    required this.aisles,
  });

  int get totalAisles => aisles.length;
  int get totalProducts =>
      aisles.fold(0, (sum, aisle) => sum + aisle.totalProducts);

  Map<String, dynamic> toMap() => {
        'planogram_date': planogramDate,
        'category': category,
        'aisles': aisles.map((a) => a.toMap()).toList(),
      };

  factory Planogram.fromMap(Map<String, dynamic> map) => Planogram(
        planogramDate: map['planogram_date'] as String? ?? '',
        category: map['category'] as String? ?? '',
        aisles: (map['aisles'] as List<dynamic>?)
                ?.map((e) =>
                    PlanogramAisle.fromMap(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  String toJson() => json.encode(toMap());

  factory Planogram.fromJson(String source) =>
      Planogram.fromMap(json.decode(source) as Map<String, dynamic>);
}
