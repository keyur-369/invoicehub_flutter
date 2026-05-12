import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoicehub/models/business_models.dart';
import 'package:invoicehub/models/product_models.dart';
import 'package:invoicehub/providers/auth_provider.dart';
import 'package:invoicehub/repositories/business_repository.dart';

class ManageMasterProductsScreen extends ConsumerStatefulWidget {
  const ManageMasterProductsScreen({super.key});

  @override
  ConsumerState<ManageMasterProductsScreen> createState() => _ManageMasterProductsScreenState();
}

class _ManageMasterProductsScreenState extends ConsumerState<ManageMasterProductsScreen> {
  final _nameController = TextEditingController();
  final _gstController = TextEditingController(text: '18');
  String? _selectedCategoryId;
  String? _selectedBrandId;

  void _addProduct() async {
    if (_nameController.text.isEmpty || _selectedCategoryId == null || _selectedBrandId == null) return;
    final profile = ref.read(profileProvider).value;
    if (profile == null) return;

    final product = MasterProduct(
      id: '',
      categoryId: _selectedCategoryId!,
      brandId: _selectedBrandId!,
      productName: _nameController.text.trim(),
      defaultGstPercentage: double.tryParse(_gstController.text) ?? 18,
      createdBy: profile.id,
      createdAt: DateTime.now(),
    );

    await ref.read(businessRepoProvider).addMasterProduct(product);
    _nameController.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Master Products')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      FutureBuilder<List<ProductCategory>>(
                        future: ref.read(businessRepoProvider).getCategories(),
                        builder: (context, snapshot) {
                          return DropdownButtonFormField<String>(
                            value: _selectedCategoryId,
                            decoration: const InputDecoration(labelText: 'Select Category'),
                            items: (snapshot.data ?? []).map((c) => DropdownMenuItem(value: c.id, child: Text(c.categoryName))).toList(),
                            onChanged: (v) => setState(() => _selectedCategoryId = v),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      FutureBuilder<List<ProductBrand>>(
                        future: ref.read(businessRepoProvider).getBrands(),
                        builder: (context, snapshot) {
                          return DropdownButtonFormField<String>(
                            value: _selectedBrandId,
                            decoration: const InputDecoration(labelText: 'Select Brand'),
                            items: (snapshot.data ?? []).map((b) => DropdownMenuItem(value: b.id, child: Text(b.brandName))).toList(),
                            onChanged: (v) => setState(() => _selectedBrandId = v),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Product Name')),
                      const SizedBox(height: 12),
                      TextField(controller: _gstController, decoration: const InputDecoration(labelText: 'GST %'), keyboardType: TextInputType.number),
                      const SizedBox(height: 20),
                      ElevatedButton(onPressed: _addProduct, style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)), child: const Text('Add Product')),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(),
            FutureBuilder<List<MasterProduct>>(
              future: ref.read(businessRepoProvider).getMasterProducts(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                final products = snapshot.data!;
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final p = products[index];
                    return ListTile(
                      title: Text(p.productName),
                      subtitle: Text('${p.category?.categoryName ?? ''} | ${p.brand?.brandName ?? ''}'),
                      trailing: Text('${p.defaultGstPercentage}% GST'),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
