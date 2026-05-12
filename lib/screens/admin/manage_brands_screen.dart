import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoicehub/repositories/business_repository.dart';
import 'package:invoicehub/models/product_models.dart';
import 'package:invoicehub/providers/auth_provider.dart';

class ManageBrandsScreen extends ConsumerStatefulWidget {
  const ManageBrandsScreen({super.key});

  @override
  ConsumerState<ManageBrandsScreen> createState() => _ManageBrandsScreenState();
}

class _ManageBrandsScreenState extends ConsumerState<ManageBrandsScreen> {
  final _controller = TextEditingController();

  void _addBrand() async {
    if (_controller.text.isEmpty) return;
    final profile = ref.read(profileProvider).value;
    if (profile == null) return;

    await ref.read(businessRepoProvider).addBrand(_controller.text, profile.id);
    _controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Brands')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(labelText: 'Brand Name', hintText: 'e.g. Havells, GM'),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(onPressed: _addBrand, child: const Text('Add')),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: FutureBuilder<List<ProductBrand>>(
              future: ref.read(businessRepoProvider).getBrands(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final brands = snapshot.data!;
                return ListView.builder(
                  itemCount: brands.length,
                  itemBuilder: (context, index) {
                    final brand = brands[index];
                    return ListTile(
                      title: Text(brand.brandName),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          await ref.read(businessRepoProvider).deleteBrand(brand.id);
                          setState(() {});
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
