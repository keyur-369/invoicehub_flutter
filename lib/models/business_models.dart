import 'package:invoicehub/models/product_models.dart';

class MasterProduct {
  final String id;
  final String? categoryId;
  final String? brandId;
  final String productName;
  final String? unit;
  final double defaultGstPercentage;
  final String? imageUrl;
  final String? createdBy;
  final DateTime createdAt;
  
  // Optional relations
  final ProductCategory? category;
  final ProductBrand? brand;

  MasterProduct({
    required this.id,
    this.categoryId,
    this.brandId,
    required this.productName,
    this.unit,
    this.defaultGstPercentage = 0.0,
    this.imageUrl,
    this.createdBy,
    required this.createdAt,
    this.category,
    this.brand,
  });

  factory MasterProduct.fromJson(Map<String, dynamic> json) {
    return MasterProduct(
      id: json['id']?.toString() ?? '',
      categoryId: json['category_id']?.toString(),
      brandId: json['brand_id']?.toString(),
      productName: json['product_name']?.toString() ?? 'Unnamed Product',
      unit: json['unit'],
      defaultGstPercentage: (json['default_gst_percentage'] ?? 0.0).toDouble(),
      imageUrl: json['image_url']?.toString(),
      createdBy: json['created_by'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      category: json['product_categories'] != null 
          ? (json['product_categories'] is List 
              ? (json['product_categories'] as List).isNotEmpty 
                  ? ProductCategory.fromJson(json['product_categories'][0])
                  : null
              : ProductCategory.fromJson(json['product_categories']))
          : null,
      brand: json['product_brands'] != null 
          ? (json['product_brands'] is List 
              ? (json['product_brands'] as List).isNotEmpty
                  ? ProductBrand.fromJson(json['product_brands'][0])
                  : null
              : ProductBrand.fromJson(json['product_brands']))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'product_name': productName,
      'unit': unit,
      'default_gst_percentage': defaultGstPercentage,
      'created_by': createdBy,
    };
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      map['image_url'] = imageUrl;
    }
    if (categoryId != null && categoryId!.isNotEmpty) {
      map['category_id'] = categoryId;
    }
    if (brandId != null && brandId!.isNotEmpty) {
      map['brand_id'] = brandId;
    }
    return map;
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
      id: json['id']?.toString() ?? '',
      shopId: json['shop_id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      customRate: (json['custom_rate'] ?? 0.0).toDouble(),
      gstPercentage: (json['gst_percentage'] ?? 18.0).toDouble(),
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      product: json['master_products'] != null 
          ? (json['master_products'] is List 
              ? (json['master_products'] as List).isNotEmpty
                  ? MasterProduct.fromJson(json['master_products'][0])
                  : null
              : MasterProduct.fromJson(json['master_products']))
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
      id: json['id']?.toString() ?? '',
      shopId: json['shop_id']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? 'Unnamed Customer',
      mobile: json['mobile'],
      gstNumber: json['gst_number'],
      address: json['address'],
      city: json['city'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
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
