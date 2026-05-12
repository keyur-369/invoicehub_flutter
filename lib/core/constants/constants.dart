class AppConstants {
  static const String appName = 'InvoiceHub';

  // Supabase Config - Replace with your actual credentials
  static const String supabaseUrl = 'https://farutaqyvpijnqdxsttq.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZhcnV0YXF5dnBpam5xZHhzdHRxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg1NTI3OTYsImV4cCI6MjA5NDEyODc5Nn0.vgHWZVwSG9v1mrKL86Sf0PcdcjCDmBROaGHKUGx_778';

  // Storage Buckets
  static const String logosBucket = 'logos';
  static const String invoicesBucket = 'invoices';
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
}
