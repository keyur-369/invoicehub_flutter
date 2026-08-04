import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoicehub/core/constants/constants.dart';
import 'package:invoicehub/models/business_models.dart';
import 'package:invoicehub/models/khata_model.dart';
import 'package:invoicehub/services/supabase_service.dart';
import 'package:invoicehub/repositories/business_repository.dart';

final khataRepoProvider = Provider((ref) => KhataRepository(ref));

class KhataRepository extends SupabaseService {
  final Ref _ref;
  KhataRepository(this._ref);

  /// Fetch all transactions for a specific customer
  Future<List<KhataTransaction>> getTransactionsForCustomer(String customerId) async {
    if (customerId.isEmpty) return [];

    try {
      final response = await client
          .from(DatabaseTables.khataTransactions)
          .select('*, customers(*), invoices(invoice_number)')
          .eq('customer_id', customerId)
          .order('transaction_date', ascending: false);

      return (response as List).map((t) => KhataTransaction.fromJson(t)).toList();
    } catch (e) {
      // Return empty list if table doesn't exist or on error
      return [];
    }
  }

  /// Fetch all transactions for a shop
  Future<List<KhataTransaction>> getTransactionsForShop(String shopId) async {
    if (shopId.isEmpty) return [];

    try {
      final response = await client
          .from(DatabaseTables.khataTransactions)
          .select('*, customers(*), invoices(invoice_number)')
          .eq('shop_id', shopId)
          .order('transaction_date', ascending: false);

      return (response as List).map((t) => KhataTransaction.fromJson(t)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Add a new Khata transaction (GAVE / GOT)
  Future<void> addTransaction(KhataTransaction transaction) async {
    await client.from(DatabaseTables.khataTransactions).insert(transaction.toJson());
  }

  /// Delete a transaction
  Future<void> deleteTransaction(String transactionId) async {
    await client.from(DatabaseTables.khataTransactions).delete().eq('id', transactionId);
  }

  /// Get aggregated summaries for all customers in a shop
  Future<List<CustomerKhataSummary>> getCustomerKhataSummaries(String shopId) async {
    if (shopId.isEmpty) return [];

    // 1. Get all customers for the shop
    final businessRepo = _ref.read(businessRepoProvider);
    final customers = await businessRepo.getCustomers(shopId);

    if (customers.isEmpty) return [];

    // 2. Get all khata transactions for the shop
    List<KhataTransaction> allTxs = [];
    try {
      allTxs = await getTransactionsForShop(shopId);
    } catch (_) {
      allTxs = [];
    }

    // 3. Aggregate transactions by customerId
    final Map<String, List<KhataTransaction>> customerTxMap = {};
    for (final tx in allTxs) {
      customerTxMap.putIfAbsent(tx.customerId, () => []).add(tx);
    }

    final List<CustomerKhataSummary> summaries = [];

    for (final customer in customers) {
      final txs = customerTxMap[customer.id] ?? [];
      double gave = 0.0;
      double got = 0.0;
      DateTime? lastDate;

      for (final tx in txs) {
        if (tx.isGave) {
          gave += tx.amount;
        } else if (tx.isGot) {
          got += tx.amount;
        }
        if (lastDate == null || tx.transactionDate.isAfter(lastDate)) {
          lastDate = tx.transactionDate;
        }
      }

      summaries.add(
        CustomerKhataSummary(
          customer: customer,
          totalGave: gave,
          totalGot: got,
          lastTransactionDate: lastDate,
        ),
      );
    }

    // Sort by last transaction date (newest first), or customer name
    summaries.sort((a, b) {
      if (a.lastTransactionDate != null && b.lastTransactionDate != null) {
        return b.lastTransactionDate!.compareTo(a.lastTransactionDate!);
      } else if (a.lastTransactionDate != null) {
        return -1;
      } else if (b.lastTransactionDate != null) {
        return 1;
      }
      return a.customer.customerName.compareTo(b.customer.customerName);
    });

    return summaries;
  }
}
