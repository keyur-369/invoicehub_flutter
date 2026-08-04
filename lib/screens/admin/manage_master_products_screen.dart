import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:invoicehub/models/business_models.dart';
import 'package:invoicehub/models/product_models.dart';
import 'package:invoicehub/providers/auth_provider.dart';
import 'package:invoicehub/repositories/business_repository.dart';
import 'package:invoicehub/providers/product_provider.dart';
import 'package:invoicehub/services/auth_service.dart';

class ManageMasterProductsScreen extends ConsumerStatefulWidget {
  const ManageMasterProductsScreen({super.key});

  @override
  ConsumerState<ManageMasterProductsScreen> createState() => _ManageMasterProductsScreenState();
}

class _ManageMasterProductsScreenState extends ConsumerState<ManageMasterProductsScreen> {
  final _nameController = TextEditingController();
  final _gstController = TextEditingController(text: '0');
  final _unitController = TextEditingController();
  String? _selectedCategoryId;
  String? _selectedBrandId;

  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  bool _isSaving = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImage = image;
          _selectedImageBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _clearImage() {
    setState(() {
      _selectedImage = null;
      _selectedImageBytes = null;
    });
  }

  void _addProduct() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a product name')),
      );
      return;
    }
    
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      String? imageUrl;
      if (_selectedImageBytes != null && _selectedImage != null) {
        imageUrl = await ref.read(businessRepoProvider).uploadProductImage(
          _selectedImageBytes!,
          _selectedImage!.name,
        );
      }

      final product = MasterProduct(
        id: '',
        categoryId: _selectedCategoryId,
        brandId: _selectedBrandId,
        productName: _nameController.text.trim(),
        unit: _unitController.text.trim().isNotEmpty ? _unitController.text.trim() : null,
        defaultGstPercentage: double.tryParse(_gstController.text) ?? 0.0,
        imageUrl: imageUrl,
        createdBy: user.id,
        createdAt: DateTime.now(),
      );

      await ref.read(businessRepoProvider).addMasterProduct(product);
      
      _nameController.clear();
      _unitController.clear();
      _clearImage();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product added successfully!'), backgroundColor: Colors.green),
        );
      }
      ref.invalidate(masterProductsProvider); // Refresh product list
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding product: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- CSV BULK IMPORT ---
  Future<void> _pickAndParseCsv() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      String csvContent = '';

      if (file.bytes != null) {
        csvContent = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        csvContent = await File(file.path!).readAsString();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to read CSV file content.')),
          );
        }
        return;
      }

      final List<List<dynamic>> rows = const CsvToListConverter(
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(csvContent);

      if (rows.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('The selected CSV file is empty.')),
          );
        }
        return;
      }

      // Parse headers
      final headers = rows.first.map((e) => e.toString().trim().toLowerCase()).toList();
      
      int nameIdx = headers.indexWhere((h) => h == 'product_name' || h == 'product name' || h == 'name' || h == 'product');
      int unitIdx = headers.indexWhere((h) => h == 'unit');
      int gstIdx = headers.indexWhere((h) => h == 'default_gst_percentage' || h == 'gst' || h == 'gst_percentage' || h == 'gst%');
      int catIdx = headers.indexWhere((h) => h == 'category' || h == 'category_name' || h == 'category_id');
      int brandIdx = headers.indexWhere((h) => h == 'brand' || h == 'brand_name' || h == 'brand_id');
      int imgIdx = headers.indexWhere((h) => h == 'image_url' || h == 'image' || h == 'image url');

      if (nameIdx == -1) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('CSV must contain a "product_name" or "Name" column.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final user = ref.read(authServiceProvider).currentUser;
      final existingCategories = await ref.read(businessRepoProvider).getCategories();
      final existingBrands = await ref.read(businessRepoProvider).getBrands();

      final List<MasterProduct> parsedProducts = [];

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty || row.length <= nameIdx) continue;

        final productName = row[nameIdx].toString().trim();
        if (productName.isEmpty) continue;

        final unit = unitIdx != -1 && unitIdx < row.length ? row[unitIdx].toString().trim() : null;
        
        double gst = 0.0;
        if (gstIdx != -1 && gstIdx < row.length) {
          gst = double.tryParse(row[gstIdx].toString().replaceAll('%', '').trim()) ?? 0.0;
        }

        String? categoryId;
        if (catIdx != -1 && catIdx < row.length) {
          final catVal = row[catIdx].toString().trim();
          if (catVal.isNotEmpty) {
            final match = existingCategories.firstWhere(
              (c) => c.id == catVal || c.categoryName.toLowerCase() == catVal.toLowerCase(),
              orElse: () => ProductCategory(id: '', categoryName: '', createdAt: DateTime.now()),
            );
            if (match.id.isNotEmpty) categoryId = match.id;
          }
        }

        String? brandId;
        if (brandIdx != -1 && brandIdx < row.length) {
          final brandVal = row[brandIdx].toString().trim();
          if (brandVal.isNotEmpty) {
            final match = existingBrands.firstWhere(
              (b) => b.id == brandVal || b.brandName.toLowerCase() == brandVal.toLowerCase(),
              orElse: () => ProductBrand(id: '', brandName: '', createdAt: DateTime.now()),
            );
            if (match.id.isNotEmpty) brandId = match.id;
          }
        }

        String? imageUrl;
        if (imgIdx != -1 && imgIdx < row.length) {
          final imgVal = row[imgIdx].toString().trim();
          if (imgVal.startsWith('http://') || imgVal.startsWith('https://')) {
            imageUrl = imgVal;
          }
        }

        parsedProducts.add(
          MasterProduct(
            id: '',
            categoryId: categoryId,
            brandId: brandId,
            productName: productName,
            unit: unit,
            defaultGstPercentage: gst,
            imageUrl: imageUrl,
            createdBy: user?.id,
            createdAt: DateTime.now(),
          ),
        );
      }

      if (parsedProducts.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No valid products found in the CSV file.')),
          );
        }
        return;
      }

      if (mounted) {
        _showCsvPreviewDialog(parsedProducts);
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing CSV: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showCsvPreviewDialog(List<MasterProduct> products) {
    bool isImporting = false;

    showDialog(
      context: context,
      barrierDismissible: !isImporting,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Confirm CSV Import (${products.length} Products)'),
              content: SizedBox(
                width: double.maxFinite,
                height: 350,
                child: Column(
                  children: [
                    const Text(
                      'Preview of parsed products ready to import:',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: products.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final item = products[idx];
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue.shade50,
                              child: Text('${idx + 1}', style: const TextStyle(fontSize: 12)),
                            ),
                            title: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Unit: ${item.unit ?? '-'} | GST: ${item.defaultGstPercentage}%'),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isImporting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  icon: isImporting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.cloud_upload),
                  label: Text(isImporting ? 'Importing...' : 'IMPORT ALL (${products.length})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isImporting
                      ? null
                      : () async {
                          setDialogState(() => isImporting = true);
                          try {
                            await ref.read(businessRepoProvider).addMasterProductsBatch(products);
                            ref.invalidate(masterProductsProvider);
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Successfully imported ${products.length} products!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isImporting = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error importing products: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCsvHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.blue),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'CSV Format Guidelines',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Upload a CSV file containing your product catalog. The headers should include:',
                style: TextStyle(fontSize: 13),
              ),
              SizedBox(height: 10),
              SelectableText(
                'product_name,unit,default_gst_percentage,category,brand,image_url\n'
                'LED Tubelight 22W,Pcs,0,Electronics,Philips,https://example.com/led.jpg\n'
                'Switch 6A,Box,0,Electricals,Anchor,\n'
                'Copper Wire 90m,Coil,0,Wiring,Finolex,',
                style: TextStyle(fontFamily: 'monospace', fontSize: 12, backgroundColor: Color(0xFFF0F4F8)),
              ),
              SizedBox(height: 12),
              Text('• product_name (Required): Name of the product.', style: TextStyle(fontSize: 12)),
              Text('• unit (Optional): e.g. Pcs, Box, Kg, Meter.', style: TextStyle(fontSize: 12)),
              Text('• default_gst_percentage (Optional): Default 0% (shopkeeper can set custom GST).', style: TextStyle(fontSize: 12)),
              Text('• category (Optional): Name or ID of existing category.', style: TextStyle(fontSize: 12)),
              Text('• brand (Optional): Name or ID of existing brand.', style: TextStyle(fontSize: 12)),
              Text('• image_url (Optional): Public HTTP image link.', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Master Products'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'CSV Format Help',
            onPressed: _showCsvHelpDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Quick Add Product', 
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          OutlinedButton.icon(
                            onPressed: _pickAndParseCsv,
                            icon: const Icon(Icons.file_upload, size: 18),
                            label: const Text('Import CSV', style: TextStyle(fontSize: 13)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue.shade700,
                              side: BorderSide(color: Colors.blue.shade300),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Product Image Picker Section
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                          ),
                          child: _selectedImageBytes != null
                              ? Stack(
                                  children: [
                                    Center(
                                      child: Image.memory(
                                        _selectedImageBytes!,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: 120,
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: CircleAvatar(
                                        radius: 16,
                                        backgroundColor: Colors.black54,
                                        child: IconButton(
                                          icon: const Icon(Icons.close, size: 16, color: Colors.white),
                                          onPressed: _clearImage,
                                          padding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_a_photo_outlined, size: 36, color: Colors.blue),
                                    SizedBox(height: 6),
                                    Text('Tap to upload product image', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: _nameController, 
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _addProduct(),
                        autofocus: false,
                        decoration: InputDecoration(
                          labelText: 'Product Name *',
                          hintText: 'e.g. LED tublite 22w',
                          prefixIcon: const Icon(Icons.inventory, color: Colors.blue),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ExpansionTile(
                        title: const Text('Optional Details (GST %, Unit, Category, Brand)', style: TextStyle(fontSize: 13, color: Colors.grey)),
                        tilePadding: EdgeInsets.zero,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _gstController, 
                                  decoration: const InputDecoration(
                                    labelText: 'Default GST %', 
                                    suffixText: '%',
                                    prefixIcon: Icon(Icons.percent),
                                  ), 
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _unitController,
                                  decoration: const InputDecoration(
                                    labelText: 'Unit (e.g. Pcs, Kg)',
                                    prefixIcon: Icon(Icons.straighten),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          FutureBuilder<List<ProductCategory>>(
                            future: ref.read(businessRepoProvider).getCategories(),
                            builder: (context, snapshot) {
                              final categories = snapshot.data ?? [];
                              return DropdownButtonFormField<String?>(
                                value: _selectedCategoryId,
                                decoration: const InputDecoration(
                                  labelText: 'Category (Optional)',
                                  prefixIcon: Icon(Icons.category),
                                ),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('-- None (Optional) --', style: TextStyle(color: Colors.grey)),
                                  ),
                                  ...categories.map((c) => DropdownMenuItem<String?>(value: c.id, child: Text(c.categoryName))),
                                ],
                                onChanged: (v) => setState(() => _selectedCategoryId = v),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          FutureBuilder<List<ProductBrand>>(
                            future: ref.read(businessRepoProvider).getBrands(),
                            builder: (context, snapshot) {
                              final brands = snapshot.data ?? [];
                              return DropdownButtonFormField<String?>(
                                value: _selectedBrandId,
                                decoration: const InputDecoration(
                                  labelText: 'Brand (Optional)',
                                  prefixIcon: Icon(Icons.branding_watermark),
                                ),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('-- None (Optional) --', style: TextStyle(color: Colors.grey)),
                                  ),
                                  ...brands.map((b) => DropdownMenuItem<String?>(value: b.id, child: Text(b.brandName))),
                                ],
                                onChanged: (v) => setState(() => _selectedBrandId = v),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _isSaving ? null : _addProduct, 
                        icon: _isSaving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.add),
                        label: Text(_isSaving ? 'SAVING...' : 'ADD PRODUCT NOW', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(),
            ref.watch(masterProductsProvider).when(
              data: (products) {
                if (products.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Center(child: Text('No master products found.')),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final p = products[index];
                    final cat = p.category?.categoryName;
                    final brand = p.brand?.brandName;
                    final unitStr = p.unit != null && p.unit!.isNotEmpty ? ' [${p.unit}]' : '';
                    final details = [
                      if (cat != null && cat.isNotEmpty) cat,
                      if (brand != null && brand.isNotEmpty) brand,
                    ].join(' | ');

                    Widget leadingWidget;
                    if (p.imageUrl != null && p.imageUrl!.isNotEmpty) {
                      leadingWidget = ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: p.imageUrl!,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 44,
                            height: 44,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.inventory_2, color: Colors.grey),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 44,
                            height: 44,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        ),
                      );
                    } else {
                      leadingWidget = Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.inventory_2, color: Colors.green),
                      );
                    }

                    return ListTile(
                      leading: leadingWidget,
                      title: Text('${p.productName}$unitStr', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: details.isNotEmpty ? Text(details) : null,
                      trailing: Text('${p.defaultGstPercentage.toStringAsFixed(0)}% GST', style: const TextStyle(fontWeight: FontWeight.bold)),
                    );
                  },
                );
              },
              loading: () => const Center(child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(),
              )),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(20.0),
                child: Center(child: Text('Error loading products: $e', style: const TextStyle(color: Colors.red))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
