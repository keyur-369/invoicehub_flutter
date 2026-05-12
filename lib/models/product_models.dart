class ProductCategory {
  final String id;
  final String categoryName;
  final String? createdBy;
  final DateTime createdAt;

  ProductCategory({
    required this.id,
    required this.categoryName,
    this.createdBy,
    required this.createdAt,
  });

  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    return ProductCategory(
      id: json['id'],
      categoryName: json['category_name'],
      createdBy: json['created_by'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category_name': categoryName,
      'created_by': createdBy,
    };
  }
}

class ProductBrand {
  final String id;
  final String brandName;
  final String? createdBy;
  final DateTime createdAt;

  ProductBrand({
    required this.id,
    required this.brandName,
    this.createdBy,
    required this.createdAt,
  });

  factory ProductBrand.fromJson(Map<String, dynamic> json) {
    return ProductBrand(
      id: json['id'],
      brandName: json['brand_name'],
      createdBy: json['created_by'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'brand_name': brandName,
      'created_by': createdBy,
    };
  }
}
