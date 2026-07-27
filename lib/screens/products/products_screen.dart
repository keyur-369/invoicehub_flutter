import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoicehub/models/business_models.dart';
import 'package:invoicehub/providers/auth_provider.dart';
import 'package:invoicehub/providers/product_provider.dart';
import 'package:invoicehub/repositories/business_repository.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showEditPriceDialog(BuildContext context, WidgetRef ref, ShopProduct shopProduct, String shopId) {
    final rateController = TextEditingController(
      text: shopProduct.customRate > 0 
          ? (shopProduct.customRate % 1 == 0 ? shopProduct.customRate.toInt().toString() : shopProduct.customRate.toString()) 
          : '',
    );
    final gstController = TextEditingController(
      text: shopProduct.gstPercentage > 0 
          ? (shopProduct.gstPercentage % 1 == 0 ? shopProduct.gstPercentage.toInt().toString() : shopProduct.gstPercentage.toString()) 
          : '0',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Price/GST - ${shopProduct.product?.productName ?? "Product"}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: rateController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Custom Rate (₹)',
                hintText: 'Enter shop rate',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: gstController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'GST Percentage (%)',
                hintText: 'Enter GST percentage',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final rate = double.tryParse(rateController.text.trim()) ?? 0.0;
              final gst = double.tryParse(gstController.text.trim()) ?? shopProduct.product?.defaultGstPercentage ?? 0.0;

              try {
                await ref.read(businessRepoProvider).addShopProduct(
                      shopId: shopId,
                      productId: shopProduct.productId,
                      rate: rate,
                      gst: gst,
                    );
                ref.invalidate(shopProductsProvider);
                ref.invalidate(unifiedProductsProvider);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Product updated successfully!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating product: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(unifiedProductsProvider);
    final profile = ref.watch(profileProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products by name, brand, or category...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: productsAsync.when(
              data: (products) {
                final filteredProducts = products.where((p) {
                  final name = p.product?.productName.toLowerCase() ?? '';
                  final brand = p.product?.brand?.brandName.toLowerCase() ?? '';
                  final cat = p.product?.category?.categoryName.toLowerCase() ?? '';
                  return name.contains(_searchQuery) ||
                      brand.contains(_searchQuery) ||
                      cat.contains(_searchQuery);
                }).toList();

                if (filteredProducts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty ? 'No products available.' : 'No matching products found.',
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final item = filteredProducts[index];
                    final product = item.product;
                    if (product == null) return const SizedBox.shrink();

                    final brandName = product.brand?.brandName;
                    final categoryName = product.category?.categoryName;
                    final subtitleParts = <String>[];
                    if (brandName != null && brandName.isNotEmpty) subtitleParts.add(brandName);
                    if (categoryName != null && categoryName.isNotEmpty) subtitleParts.add(categoryName);
                    subtitleParts.add('GST: ${item.gstPercentage.toStringAsFixed(0)}%');

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                          child: Text(
                            product.productName.isNotEmpty ? product.productName[0].toUpperCase() : 'P',
                            style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          product.productName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(subtitleParts.join(' • ')),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              item.customRate > 0 ? '₹${item.customRate.toStringAsFixed(2)}' : 'Default',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: item.customRate > 0 ? Colors.green[700] : Colors.grey[700],
                              ),
                            ),
                            if (profile != null)
                              InkWell(
                                onTap: () => _showEditPriceDialog(context, ref, item, profile.id),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.edit, size: 14, color: Colors.blue),
                                      SizedBox(width: 2),
                                      Text('Set Price', style: TextStyle(fontSize: 12, color: Colors.blue)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Text('Error loading products: $err', style: const TextStyle(color: Colors.red)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
