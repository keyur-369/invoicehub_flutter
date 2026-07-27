import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoicehub/providers/auth_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:invoicehub/screens/invoice/create_invoice_screen.dart';
import 'package:invoicehub/providers/invoice_provider.dart';
import 'package:invoicehub/providers/dashboard_provider.dart';
import 'package:invoicehub/repositories/business_repository.dart';
import 'package:invoicehub/models/business_models.dart';
import 'package:invoicehub/providers/product_provider.dart';
import 'package:invoicehub/screens/products/products_screen.dart';

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(profile?.shopName ?? 'My Shop', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Owner: ${profile?.ownerName ?? ''}', style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/profile-settings'),
            icon: CircleAvatar(
              radius: 16,
              backgroundImage: profile?.logoUrl != null ? NetworkImage(profile!.logoUrl!) : null,
              child: profile?.logoUrl == null ? const Icon(Icons.person, size: 20) : null,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatCards(context, ref),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => const CreateInvoiceScreen()));
              },
              icon: const Icon(Icons.add),
              label: const Text('CREATE NEW INVOICE'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                _buildActionCard(context, Icons.person_add_alt_1, 'Add Customer', Colors.orange, onTap: () {
                  if (profile != null) _showAddCustomerDialog(context, ref, profile.id);
                }),
                _buildActionCard(context, Icons.inventory_2, 'Show Products', Colors.green, onTap: () {
                  ref.read(dashboardIndexProvider.notifier).state = 2; // Products tab
                }),
                _buildActionCard(context, Icons.receipt, 'Recent Invoices', Colors.blue, onTap: () {
                  ref.read(dashboardIndexProvider.notifier).state = 3; // History tab
                }),
                _buildActionCard(context, Icons.analytics, 'Reports', Colors.purple, onTap: () {
                  _showReportsSummary(context, ref);
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCards(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(invoicesProvider);

    return Row(
      children: [
        Expanded(
          child: Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text('Total Invoices', style: TextStyle(color: Colors.blue)),
                  invoicesAsync.when(
                    data: (invoices) => Text(
                      invoices.length.toString(),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    loading: () => const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                    error: (_, __) => const Text('0', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text('Total Sales', style: TextStyle(color: Colors.green)),
                  invoicesAsync.when(
                    data: (invoices) {
                      final total = invoices.fold<double>(0, (sum, item) => sum + item.grandTotal);
                      return Text(
                        '₹${total.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      );
                    },
                    loading: () => const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                    error: (_, __) => const Text('₹0', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showAddCustomerDialog(BuildContext context, WidgetRef ref, String shopId) {
    final nameController = TextEditingController();
    final mobileController = TextEditingController();
    final cityController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Customer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Customer Name')),
            TextField(controller: mobileController, decoration: const InputDecoration(labelText: 'Mobile')),
            TextField(controller: cityController, decoration: const InputDecoration(labelText: 'City')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              final customer = Customer(
                id: '', 
                shopId: shopId,
                customerName: nameController.text.trim(),
                mobile: mobileController.text.trim(),
                city: cityController.text.trim(),
                createdAt: DateTime.now(),
              );
              await ref.read(businessRepoProvider).addCustomer(customer);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer added!')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showReportsSummary(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(invoicesProvider);
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Business Report', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            invoicesAsync.when(
              data: (invoices) {
                final totalSales = invoices.fold<double>(0, (sum, i) => sum + i.grandTotal);
                final totalGst = invoices.fold<double>(0, (sum, i) => sum + i.gstTotal);
                return Column(
                  children: [
                    _reportRow('Total Invoices', '${invoices.length}'),
                    _reportRow('Total Sales Amount', '₹${totalSales.toStringAsFixed(2)}'),
                    _reportRow('GST Collected', '₹${totalGst.toStringAsFixed(2)}'),
                  ],
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reportRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, IconData icon, String title, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
