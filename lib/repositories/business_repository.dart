import 'package:invoicehub/core/constants/constants.dart';
import 'package:invoicehub/models/business_models.dart';
import 'package:invoicehub/models/product_models.dart';
import 'package:invoicehub/services/supabase_service.dart';

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
}
