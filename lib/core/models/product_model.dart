import 'dart:convert';

class Product {
  final String? id;
  final String name;
  final String? brand;
  final String? weight;
  final double estimatedPrice;
  final String category;
  final String? barcode;
  final String? imagePath;
  final String? aisle;
  final String? planogramDate;
  final String? sheetName; // e.g., "OGE", "FGE"
  final int quantity;

  Product({
    this.id,
    required this.name,
    this.brand,
    this.weight,
    required this.estimatedPrice,
    required this.category,
    this.barcode,
    this.imagePath,
    this.aisle,
    this.planogramDate,
    this.sheetName,
    this.quantity = 1,
  });

  Product copyWith({
    int? quantity,
  }) {
    return Product(
      id: id,
      name: name,
      brand: brand,
      weight: weight,
      estimatedPrice: estimatedPrice,
      category: category,
      barcode: barcode,
      imagePath: imagePath,
      aisle: aisle,
      planogramDate: planogramDate,
      sheetName: sheetName,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'brand': brand,
      'weight': weight,
      'estimated_price': estimatedPrice,
      'category': category,
      'barcode': barcode,
      'image_path': imagePath,
      'aisle': aisle,
      'planogram_date': planogramDate,
      'sheet_name': sheetName,
      'quantity': quantity,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id']?.toString(),
      name: map['name'] ?? '',
      brand: map['brand'],
      weight: map['weight'],
      estimatedPrice: (map['estimated_price'] as num).toDouble(),
      category: map['category'] ?? 'General',
      barcode: map['barcode'],
      imagePath: map['image_path'],
      aisle: map['aisle'],
      planogramDate: map['planogram_date'],
      sheetName: map['sheet_name'],
      quantity: map['quantity'] ?? 1,
    );
  }

  String toJson() => json.encode(toMap());

  factory Product.fromJson(String source) => Product.fromMap(json.decode(source));
}
