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

final unifiedProductsProvider = FutureProvider<List<ShopProduct>>((ref) async {
  final masterProducts = await ref.watch(masterProductsProvider.future);
  final shopProducts = await ref.watch(shopProductsProvider.future);
  
  final Map<String, ShopProduct> shopProductsMap = {
    for (var p in shopProducts) p.productId: p
  };
  
  return masterProducts.map((mp) {
    if (shopProductsMap.containsKey(mp.id)) {
      return shopProductsMap[mp.id]!;
    } else {
      return ShopProduct(
        id: '', 
        shopId: '', 
        productId: mp.id,
        customRate: 0.0,
        gstPercentage: mp.defaultGstPercentage,
        createdAt: mp.createdAt,
        product: mp,
      );
    }
  }).toList();
});
