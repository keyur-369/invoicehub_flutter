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
}
