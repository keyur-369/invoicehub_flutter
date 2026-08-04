import 'dart:typed_data';
import 'package:invoicehub/core/constants/constants.dart';
import 'package:invoicehub/models/invoice_model.dart';
import 'package:invoicehub/models/business_models.dart';
import 'package:invoicehub/models/product_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoicehub/services/supabase_service.dart';

final businessRepoProvider = Provider((ref) => BusinessRepository());

class BusinessRepository extends SupabaseService {
  // Customers
  Future<List<Customer>> getCustomers(String shopId) async {
    if (shopId.isEmpty) return [];

    final response = await client
        .from(DatabaseTables.customers)
        .select()
        .eq('shop_id', shopId)
        .order('customer_name');

    return (response as List).map((c) => Customer.fromJson(c)).toList();
  }

  Future<void> addCustomer(Customer customer) async {
    await client.from(DatabaseTables.customers).insert(customer.toJson());
  }

  Future<void> updateCustomer(Customer customer) async {
    await client
        .from(DatabaseTables.customers)
        .update(customer.toJson())
        .eq('id', customer.id);
  }

  Future<void> deleteCustomer(String id) async {
    await client.from(DatabaseTables.customers).delete().eq('id', id);
  }

  // Admin: Manage Categories
  Future<void> addCategory(String name, String userId) async {
    await client.from(DatabaseTables.productCategories).insert({
      'category_name': name,
      'created_by': userId,
    });
  }

  Future<void> deleteCategory(String id) async {
    await client.from(DatabaseTables.productCategories).delete().eq('id', id);
  }

  // Admin: Manage Brands
  Future<void> addBrand(String name, String userId) async {
    await client.from(DatabaseTables.productBrands).insert({
      'brand_name': name,
      'created_by': userId,
    });
  }

  Future<void> deleteBrand(String id) async {
    await client.from(DatabaseTables.productBrands).delete().eq('id', id);
  }

  // Admin: Upload Product Image to Storage
  Future<String?> uploadProductImage(Uint8List imageBytes, String fileName) async {
    try {
      final path = 'products/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      await client.storage.from(AppConstants.productsBucket).uploadBinary(path, imageBytes);
      final imageUrl = client.storage.from(AppConstants.productsBucket).getPublicUrl(path);
      return imageUrl;
    } catch (e) {
      // If products bucket fails, fallback or rethrow
      return null;
    }
  }

  // Admin: Manage Master Products
  Future<void> addMasterProduct(MasterProduct product) async {
    final data = product.toJson();
    await client.from(DatabaseTables.masterProducts).insert(data);
  }

  Future<void> addMasterProductsBatch(List<MasterProduct> products) async {
    if (products.isEmpty) return;
    final listData = products.map((p) => p.toJson()).toList();
    await client.from(DatabaseTables.masterProducts).insert(listData);
  }

  // Products
  Future<List<MasterProduct>> getMasterProducts() async {
    final response = await client
        .from(DatabaseTables.masterProducts)
        .select('*, product_categories(*), product_brands(*)');

    return (response as List).map((p) => MasterProduct.fromJson(p)).toList();
  }

  Future<List<ShopProduct>> getShopProducts(String shopId) async {
    final response = await client
        .from(DatabaseTables.shopProducts)
        .select(
          '*, master_products(*, product_categories(*), product_brands(*))',
        )
        .eq('shop_id', shopId);

    return (response as List).map((p) => ShopProduct.fromJson(p)).toList();
  }

  Future<void> addShopProduct({
    required String shopId,
    required String productId,
    required double rate,
    required double gst,
  }) async {
    await client.from(DatabaseTables.shopProducts).upsert({
      'shop_id': shopId,
      'product_id': productId,
      'custom_rate': rate,
      'gst_percentage': gst,
      'is_active': true,
    });
  }

  // Create a product directly for shopkeeper
  Future<void> createDirectProductForShop({
    required String shopId,
    required String userId,
    required String productName,
    required double rate,
    required double gstPercentage,
    String unit = 'Pcs',
    String? categoryId,
    String? brandId,
  }) async {
    // 1. Create master product entry under user_id
    final masterRes = await client.from(DatabaseTables.masterProducts).insert({
      'product_name': productName,
      'unit': unit,
      'default_gst_percentage': gstPercentage,
      'created_by': userId,
      if (categoryId != null && categoryId.isNotEmpty) 'category_id': categoryId,
      if (brandId != null && brandId.isNotEmpty) 'brand_id': brandId,
    }).select().single();

    final productId = masterRes['id']?.toString() ?? '';

    // 2. Link product to shop
    await client.from(DatabaseTables.shopProducts).insert({
      'shop_id': shopId,
      'product_id': productId,
      'custom_rate': rate,
      'gst_percentage': gstPercentage,
      'is_active': true,
    });
  }

  // Batch import products from CSV
  Future<int> importProductsBatchFromCsv({
    required String shopId,
    required String userId,
    required List<Map<String, dynamic>> items,
  }) async {
    int successCount = 0;
    for (final item in items) {
      final String name = item['name']?.toString().trim() ?? '';
      if (name.isEmpty) continue;
      final double rate = (item['price'] ?? item['rate'] ?? 0.0).toDouble();
      final double gst = (item['gst'] ?? item['gst_percentage'] ?? 0.0).toDouble();
      final String unit = item['unit']?.toString() ?? 'Pcs';

      await createDirectProductForShop(
        shopId: shopId,
        userId: userId,
        productName: name,
        rate: rate,
        gstPercentage: gst,
        unit: unit,
      );
      successCount++;
    }
    return successCount;
  }

  // Delete shop product
  Future<void> deleteShopProduct(String shopProductId) async {
    await client.from(DatabaseTables.shopProducts).delete().eq('id', shopProductId);
  }

  // Update product name
  Future<void> updateProductName(String productId, String newName) async {
    await client
        .from(DatabaseTables.masterProducts)
        .update({'product_name': newName})
        .eq('id', productId);
  }

  // Categories & Brands
  Future<List<ProductCategory>> getCategories() async {
    final response = await client
        .from(DatabaseTables.productCategories)
        .select();
    return (response as List).map((c) => ProductCategory.fromJson(c)).toList();
  }

  Future<List<ProductBrand>> getBrands() async {
    final response = await client.from(DatabaseTables.productBrands).select();
    return (response as List).map((b) => ProductBrand.fromJson(b)).toList();
  }

  // Invoices
  Future<void> createInvoice(Invoice invoice, List<InvoiceItem> items) async {
    // 1. Insert Invoice
    final invoiceData = invoice.toJson();
    final response = await client
        .from(DatabaseTables.invoices)
        .insert(invoiceData)
        .select()
        .single();

    final newInvoiceId = response['id'];

    // 2. Insert Items
    final itemsData = items.map((item) {
      final itemJson = item.toJson();
      itemJson['invoice_id'] = newInvoiceId;
      return itemJson;
    }).toList();

    await client.from(DatabaseTables.invoiceItems).insert(itemsData);
  }

  Future<List<Invoice>> getInvoices(String shopId) async {
    final response = await client
        .from(DatabaseTables.invoices)
        .select('*, customers(*)')
        .eq('shop_id', shopId)
        .order('created_at', ascending: false);

    return (response as List).map((i) => Invoice.fromJson(i)).toList();
  }

  Future<Invoice> getInvoiceDetails(String invoiceId) async {
    final response = await client
        .from(DatabaseTables.invoices)
        .select('*, customers(*), invoice_items(*)')
        .eq('id', invoiceId)
        .single();

    return Invoice.fromJson(response);
  }

  Future<void> deleteInvoice(String invoiceId) async {
    await client.from(DatabaseTables.invoiceItems).delete().eq('invoice_id', invoiceId);
    await client.from(DatabaseTables.invoices).delete().eq('id', invoiceId);
  }
}
