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
      id: json['id']?.toString() ?? '',
      categoryName: json['category_name']?.toString() ?? 'Unnamed Category',
      createdBy: json['created_by'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
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
      id: json['id']?.toString() ?? '',
      brandName: json['brand_name']?.toString() ?? 'Unnamed Brand',
      createdBy: json['created_by'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'brand_name': brandName,
      'created_by': createdBy,
    };
  }
}
