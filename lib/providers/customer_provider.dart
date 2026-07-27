import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoicehub/models/business_models.dart';
import 'package:invoicehub/repositories/business_repository.dart';
import 'package:invoicehub/providers/auth_provider.dart';

final customersProvider = FutureProvider<List<Customer>>((ref) async {
  final profile = ref.watch(profileProvider).value;
  if (profile == null) return [];
  return ref.watch(businessRepoProvider).getCustomers(profile.id);
});
