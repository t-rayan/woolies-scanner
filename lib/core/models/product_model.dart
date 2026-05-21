import 'dart:convert';

class Product {
  final String? id;
  final String name;
  final String? brand;
  final String? weight;
  final double estimatedPrice;
  final String category;
  final String? barcode;
  final String? aisle;
  final String? planogramDate;
  final String? sheetName;
  final String? imagePath;
  final int quantity;
  final DateTime? scanDate;

  Product({
    this.id,
    required this.name,
    this.brand,
    this.weight,
    this.estimatedPrice = 0.0,
    this.category = 'General',
    this.barcode,
    this.aisle,
    this.planogramDate,
    this.sheetName,
    this.imagePath,
    this.quantity = 1,
    this.scanDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'brand': brand,
      'weight': weight,
      'estimated_price': estimatedPrice,
      'category': category,
      'barcode': barcode,
      'aisle': aisle,
      'planogram_date': planogramDate,
      'sheet_name': sheetName,
      'image_path': imagePath,
      'quantity': quantity,
      'scanned_at':
          scanDate?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id']?.toString(),
      name: map['name'] ?? 'Unknown',
      brand: map['brand'],
      weight: map['weight'],
      estimatedPrice: (map['estimated_price'] as num?)?.toDouble() ?? 0.0,
      category: map['category'] ?? 'General',
      barcode: map['barcode'],
      aisle: map['aisle'],
      planogramDate: map['planogram_date'],
      sheetName: map['sheet_name'],
      imagePath: map['image_path'],
      quantity: map['quantity'] ?? 1,
      scanDate: map['scanned_at'] != null
          ? DateTime.tryParse(map['scanned_at'])
          : null,
    );
  }

  String toJson() => json.encode(toMap());
  factory Product.fromJson(String source) =>
      Product.fromMap(json.decode(source));
}
