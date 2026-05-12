import 'package:invoicehub/models/product_models.dart';

class MasterProduct {
  final String id;
  final String categoryId;
  final String brandId;
  final String productName;
  final String? unit;
  final double defaultGstPercentage;
  final String? createdBy;
  final DateTime createdAt;
  
  // Optional relations
  final ProductCategory? category;
  final ProductBrand? brand;

  MasterProduct({
    required this.id,
    required this.categoryId,
    required this.brandId,
    required this.productName,
    this.unit,
    this.defaultGstPercentage = 18.0,
    this.createdBy,
    required this.createdAt,
    this.category,
    this.brand,
  });

  factory MasterProduct.fromJson(Map<String, dynamic> json) {
    return MasterProduct(
      id: json['id'],
      categoryId: json['category_id'],
      brandId: json['brand_id'],
      productName: json['product_name'],
      unit: json['unit'],
      defaultGstPercentage: (json['default_gst_percentage'] ?? 18.0).toDouble(),
      createdBy: json['created_by'],
      createdAt: DateTime.parse(json['created_at']),
      category: json['product_categories'] != null 
          ? ProductCategory.fromJson(json['product_categories']) 
          : null,
      brand: json['product_brands'] != null 
          ? ProductBrand.fromJson(json['product_brands']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category_id': categoryId,
      'brand_id': brandId,
      'product_name': productName,
      'unit': unit,
      'default_gst_percentage': defaultGstPercentage,
      'created_by': createdBy,
    };
  }
}

class ShopProduct {
  final String id;
  final String shopId;
  final String productId;
  final double customRate;
  final double gstPercentage;
  final bool isActive;
  final DateTime createdAt;
  
  final MasterProduct? product;

  ShopProduct({
    required this.id,
    required this.shopId,
    required this.productId,
    this.customRate = 0.0,
    this.gstPercentage = 18.0,
    this.isActive = true,
    required this.createdAt,
    this.product,
  });

  factory ShopProduct.fromJson(Map<String, dynamic> json) {
    return ShopProduct(
      id: json['id'],
      shopId: json['shop_id'],
      productId: json['product_id'],
      customRate: (json['custom_rate'] ?? 0.0).toDouble(),
      gstPercentage: (json['gst_percentage'] ?? 18.0).toDouble(),
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      product: json['master_products'] != null 
          ? MasterProduct.fromJson(json['master_products']) 
          : null,
    );
  }
}

class Customer {
  final String id;
  final String shopId;
  final String customerName;
  final String? mobile;
  final String? gstNumber;
  final String? address;
  final String? city;
  final DateTime createdAt;

  Customer({
    required this.id,
    required this.shopId,
    required this.customerName,
    this.mobile,
    this.gstNumber,
    this.address,
    this.city,
    required this.createdAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'],
      shopId: json['shop_id'],
      customerName: json['customer_name'],
      mobile: json['mobile'],
      gstNumber: json['gst_number'],
      address: json['address'],
      city: json['city'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shop_id': shopId,
      'customer_name': customerName,
      'mobile': mobile,
      'gst_number': gstNumber,
      'address': address,
      'city': city,
    };
  }
}
