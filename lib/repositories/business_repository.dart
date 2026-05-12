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

  // Admin: Manage Master Products
  Future<void> addMasterProduct(MasterProduct product) async {
    final data = product.toJson();
    await client.from(DatabaseTables.masterProducts).insert(data);
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
        .select('*, master_products(*, product_categories(*), product_brands(*))')
        .eq('shop_id', shopId);
    
    return (response as List).map((p) => ShopProduct.fromJson(p)).toList();
  }

  // Categories & Brands
  Future<List<ProductCategory>> getCategories() async {
    final response = await client.from(DatabaseTables.productCategories).select();
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
