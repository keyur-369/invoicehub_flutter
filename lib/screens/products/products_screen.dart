import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoicehub/models/business_models.dart';
import 'package:invoicehub/providers/auth_provider.dart';
import 'package:invoicehub/repositories/business_repository.dart';

class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Products')),
      body: FutureBuilder<List<MasterProduct>>(
        future: ref.read(businessRepoProvider).getMasterProducts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final products = snapshot.data ?? [];
          return ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return ListTile(
                title: Text(product.productName),
                subtitle: Text('${product.category?.categoryName ?? ''} | ${product.brand?.brandName ?? ''}'),
                trailing: Text('GST: ${product.defaultGstPercentage}%'),
                onTap: () {},
              );
            },
          );
        },
      ),
    );
  }
}
