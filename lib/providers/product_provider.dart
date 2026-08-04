import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoicehub/models/business_models.dart';
import 'package:invoicehub/repositories/business_repository.dart';
import 'package:invoicehub/providers/auth_provider.dart';

final masterProductsProvider = FutureProvider<List<MasterProduct>>((ref) async {
  return ref.watch(businessRepoProvider).getMasterProducts();
});

final shopProductsProvider = FutureProvider<List<ShopProduct>>((ref) async {
  final profile = ref.watch(profileProvider).value;
  if (profile == null) return [];
  return ref.watch(businessRepoProvider).getShopProducts(profile.id);
});

// Unified products now returns ONLY the current shopkeeper's products
final unifiedProductsProvider = FutureProvider<List<ShopProduct>>((ref) async {
  return ref.watch(shopProductsProvider.future);
});

