import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoicehub/models/khata_model.dart';
import 'package:invoicehub/providers/auth_provider.dart';
import 'package:invoicehub/repositories/khata_repository.dart';

import 'package:invoicehub/providers/customer_provider.dart';

/// Provider for list of Customer Khata Summaries (for the Khata Dashboard)
final customerKhataSummariesProvider = FutureProvider<List<CustomerKhataSummary>>((ref) async {
  final profile = ref.watch(profileProvider).value;
  if (profile == null || profile.id.isEmpty) return [];

  // Reactive subscription: auto-rebuild Khata list whenever customer catalog is updated!
  ref.watch(customersProvider);

  final repo = ref.read(khataRepoProvider);
  return await repo.getCustomerKhataSummaries(profile.id);
});

/// Provider for a specific customer's Khata transactions timeline
final customerKhataDetailProvider = FutureProvider.family<List<KhataTransaction>, String>((ref, customerId) async {
  if (customerId.isEmpty) return [];

  final repo = ref.read(khataRepoProvider);
  return await repo.getTransactionsForCustomer(customerId);
});

/// Khata Controller for mutations
final khataControllerProvider = Provider((ref) => KhataController(ref));

class KhataController {
  final Ref _ref;
  KhataController(this._ref);

  Future<void> addTransaction(KhataTransaction tx) async {
    final repo = _ref.read(khataRepoProvider);
    await repo.addTransaction(tx);
    
    // Invalidate providers to refresh UI automatically
    _ref.invalidate(customerKhataSummariesProvider);
    _ref.invalidate(customerKhataDetailProvider(tx.customerId));
  }

  Future<void> deleteTransaction(String txId, String customerId) async {
    final repo = _ref.read(khataRepoProvider);
    await repo.deleteTransaction(txId);

    // Invalidate providers
    _ref.invalidate(customerKhataSummariesProvider);
    _ref.invalidate(customerKhataDetailProvider(customerId));
  }
}
