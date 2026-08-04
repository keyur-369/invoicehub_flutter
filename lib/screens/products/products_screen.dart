import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:invoicehub/models/business_models.dart';
import 'package:invoicehub/providers/auth_provider.dart';
import 'package:invoicehub/providers/product_provider.dart';
import 'package:invoicehub/repositories/business_repository.dart';
import 'package:invoicehub/widgets/app_colors.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  final VoidCallback? onOpenDrawer;
  const ProductsScreen({super.key, this.onOpenDrawer});

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

  void _showAddProductDialog(BuildContext context, WidgetRef ref, String shopId, String userId) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.add_shopping_cart, color: Colors.blue),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Add New Product',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Product Name *',
                hintText: 'e.g. Samsung 43 inch TV',
                prefixIcon: Icon(Icons.shopping_bag_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('Add Product'),
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a product name')),
                );
                return;
              }

              try {
                await ref.read(businessRepoProvider).createDirectProductForShop(
                      shopId: shopId,
                      userId: userId,
                      productName: name,
                      rate: 0.0,
                      gstPercentage: 0.0,
                      unit: 'Pcs',
                    );
                ref.invalidate(shopProductsProvider);
                ref.invalidate(unifiedProductsProvider);
                ref.invalidate(masterProductsProvider);

                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Product "$name" added successfully!'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error adding product: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndImportCsv(BuildContext context, WidgetRef ref, String shopId, String userId) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final pickedFile = result.files.first;
      List<int>? fileBytes = pickedFile.bytes;

      // On Android native, bytes can be null while path is populated
      if ((fileBytes == null || fileBytes.isEmpty) && pickedFile.path != null) {
        final file = File(pickedFile.path!);
        if (await file.exists()) {
          fileBytes = await file.readAsBytes();
        }
      }

      if (fileBytes == null || fileBytes.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read CSV file content'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      // Decode with UTF-8 / Latin1 fallback
      String csvString;
      try {
        csvString = utf8.decode(fileBytes);
      } catch (_) {
        csvString = String.fromCharCodes(fileBytes);
      }

      // Strip UTF-8 BOM if present
      if (csvString.startsWith('\uFEFF')) {
        csvString = csvString.substring(1);
      }
      csvString = csvString.trim();

      if (csvString.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CSV file is empty'), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      // Always split into non-empty raw lines first to avoid single-multiline cell bugs from Excel
      final rawLines = csvString
          .split(RegExp(r'\r\n|\r|\n'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();

      if (rawLines.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No lines found in CSV file'), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      // Convert each line into columns
      final List<List<dynamic>> rows = [];
      for (final line in rawLines) {
        try {
          final parsedLine = const CsvToListConverter().convert(line);
          if (parsedLine.isNotEmpty && parsedLine.first.isNotEmpty) {
            rows.add(parsedLine.first);
          } else {
            rows.add(line.split(','));
          }
        } catch (_) {
          rows.add(line.split(','));
        }
      }

      if (rows.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No valid rows in CSV file'), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      // Header column detection
      final firstRow = rows.first.map((e) => e.toString().trim().replaceAll('"', '').toLowerCase()).toList();
      int nameIdx = firstRow.indexWhere((h) => h.contains('name') || h.contains('product') || h.contains('title') || h.contains('item') || h.contains('particular'));
      int priceIdx = firstRow.indexWhere((h) => h.contains('price') || h.contains('rate') || h.contains('amount') || h.contains('mrp'));
      int gstIdx = firstRow.indexWhere((h) => h.contains('gst') || h.contains('tax'));
      int unitIdx = firstRow.indexWhere((h) => h.contains('unit'));

      bool hasHeader = nameIdx != -1 || priceIdx != -1 || gstIdx != -1;
      int startRowIndex = hasHeader ? 1 : 0;

      if (!hasHeader) {
        nameIdx = 0;
        priceIdx = 1;
        gstIdx = 2;
        unitIdx = 3;
      }

      final List<Map<String, dynamic>> parsedItems = [];
      for (int i = startRowIndex; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty) continue;

        String name = '';
        if (nameIdx >= 0 && row.length > nameIdx) {
          name = row[nameIdx].toString().trim();
        }

        // Fallback: search row for first non-numeric cell
        if (name.isEmpty) {
          for (var cell in row) {
            final cellStr = cell.toString().trim().replaceAll('"', '');
            if (cellStr.isNotEmpty && double.tryParse(cellStr) == null) {
              name = cellStr;
              break;
            }
          }
        }

        name = name.replaceAll('"', '').trim();
        if (name.isEmpty) continue;

        // Skip header-like string if startRowIndex was 0
        final nameLower = name.toLowerCase();
        if (i == 0 && (nameLower == 'product' || nameLower == 'product name' || nameLower == 'product_name' || nameLower == 'item' || nameLower == 'item name' || nameLower == 'name' || nameLower == 'items' || nameLower == 'sl no' || nameLower == 'sr no')) {
          continue;
        }

        final price = priceIdx >= 0 && row.length > priceIdx ? double.tryParse(row[priceIdx].toString().replaceAll(RegExp(r'[^\d.]'), '').trim()) ?? 0.0 : 0.0;
        final gst = gstIdx >= 0 && row.length > gstIdx ? double.tryParse(row[gstIdx].toString().replaceAll(RegExp(r'[^\d.]'), '').trim()) ?? 0.0 : 0.0;
        final unit = unitIdx >= 0 && row.length > unitIdx ? row[unitIdx].toString().replaceAll('"', '').trim() : 'Pcs';

        parsedItems.add({
          'name': name,
          'price': price,
          'gst': gst,
          'unit': unit.isEmpty ? 'Pcs' : unit,
        });
      }

      if (parsedItems.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No valid product names found in CSV'), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      // Show loading indicator
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Importing ${parsedItems.length} products from CSV...')),
        );
      }

      final importedCount = await ref.read(businessRepoProvider).importProductsBatchFromCsv(
            shopId: shopId,
            userId: userId,
            items: parsedItems,
          );

      ref.invalidate(shopProductsProvider);
      ref.invalidate(unifiedProductsProvider);
      ref.invalidate(masterProductsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully imported $importedCount products!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import CSV: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showEditProductNameDialog(BuildContext context, WidgetRef ref, ShopProduct shopProduct) {
    final currentName = shopProduct.product?.productName ?? '';
    final nameController = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Product Name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Product Name*',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.inventory_2_outlined),
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
              final newName = nameController.text.trim();
              if (newName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Product name cannot be empty'), backgroundColor: Colors.orange),
                );
                return;
              }

              try {
                await ref.read(businessRepoProvider).updateProductName(shopProduct.productId, newName);
                ref.invalidate(shopProductsProvider);
                ref.invalidate(unifiedProductsProvider);
                ref.invalidate(masterProductsProvider);

                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Product name updated to "$newName"'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating product name: $e'), backgroundColor: Colors.red),
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

  void _showProductOptionsSheet(BuildContext context, WidgetRef ref, ShopProduct shopProduct, String? shopId) {
    final product = shopProduct.product;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(
                    (product?.productName.isNotEmpty ?? false) ? product!.productName[0].toUpperCase() : 'P',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product?.productName ?? 'Product Options',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: Colors.blue),
              title: const Text('Edit Product Name', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Change the name of this product'),
              onTap: () {
                Navigator.pop(ctx);
                _showEditProductNameDialog(context, ref, shopProduct);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete Product', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
              subtitle: const Text('Remove product from inventory'),
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteProductConfirmation(context, ref, shopProduct);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteProductConfirmation(BuildContext context, WidgetRef ref, ShopProduct shopProduct) {
    final productName = shopProduct.product?.productName ?? 'Product';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "$productName" from your shop catalog?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                await ref.read(businessRepoProvider).deleteShopProduct(shopProduct.id);
                ref.invalidate(shopProductsProvider);
                ref.invalidate(unifiedProductsProvider);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Product "$productName" deleted successfully'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting product: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(unifiedProductsProvider);
    final profile = ref.watch(profileProvider).value;
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (scaffoldCtx) => IconButton(
            icon: const Icon(Icons.menu_rounded, size: 28),
            tooltip: 'Open Menu',
            onPressed: () {
              if (widget.onOpenDrawer != null) {
                widget.onOpenDrawer!();
              } else {
                Scaffold.of(scaffoldCtx).openDrawer();
              }
            },
          ),
        ),
        title: const Text('My Products'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Import CSV',
            onPressed: () {
              final shopId = profile?.id ?? '';
              final userId = currentUser?.id ?? '';
              _pickAndImportCsv(context, ref, shopId, userId);
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 75.0),
        child: FloatingActionButton.extended(
          onPressed: () {
            final shopId = profile?.id ?? '';
            final userId = currentUser?.id ?? '';
            _showAddProductDialog(context, ref, shopId, userId);
          },
          icon: const Icon(Icons.add),
          label: const Text('Add Product'),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products by name...',
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
                          _searchQuery.isEmpty ? 'No products in inventory yet.' : 'No matching products found.',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(left: 12, right: 12, top: 4, bottom: 90),
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
                        onLongPress: () => _showProductOptionsSheet(context, ref, item, profile?.id),
                        onTap: () => _showProductOptionsSheet(context, ref, item, profile?.id),
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
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                          tooltip: 'Edit Product Name',
                          onPressed: () => _showEditProductNameDialog(context, ref, item),
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

