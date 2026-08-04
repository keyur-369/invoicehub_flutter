class AppConstants {
  static const String appName = 'InvoiceHub';

  // Supabase Config - Replace with your actual credentials
  static const String supabaseUrl = 'https://uvwkrctlytrelpplctyz.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV2d2tyY3RseXRyZWxwcGxjdHl6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUxMjIxMTIsImV4cCI6MjEwMDY5ODExMn0.3F2-Bxh_CmzIwZ2ccHZAURDpSOH0okotd5ZsPcvk52A';

  // Storage Buckets
  static const String logosBucket = 'logos';
  static const String invoicesBucket = 'invoices';
  static const String signaturesBucket = 'signatures';
  static const String productsBucket = 'products';
}

class DatabaseTables {
  static const String profiles = 'profiles';
  static const String productCategories = 'product_categories';
  static const String productBrands = 'product_brands';
  static const String masterProducts = 'master_products';
  static const String shopProducts = 'shop_products';
  static const String customers = 'customers';
  static const String invoices = 'invoices';
  static const String invoiceItems = 'invoice_items';
  static const String subscriptions = 'subscriptions';
  static const String khataTransactions = 'khata_transactions';
}
