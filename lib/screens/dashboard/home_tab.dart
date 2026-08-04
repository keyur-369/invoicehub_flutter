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
import 'package:intl/intl.dart';
import 'package:invoicehub/screens/invoice/invoice_preview_screen.dart';
import 'package:invoicehub/widgets/app_colors.dart';
import 'package:invoicehub/widgets/add_customer_dialog.dart';

import 'package:invoicehub/providers/khata_provider.dart';

class HomeTab extends ConsumerWidget {
  final VoidCallback? onOpenDrawer;
  const HomeTab({super.key, this.onOpenDrawer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (scaffoldCtx) => IconButton(
            icon: const Icon(Icons.menu_rounded, size: 28),
            tooltip: 'Open Menu',
            onPressed: () {
              if (onOpenDrawer != null) {
                onOpenDrawer!();
              } else {
                Scaffold.of(scaffoldCtx).openDrawer();
              }
            },
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              profile?.shopName ?? 'My Shop',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (profile?.ownerName != null && profile!.ownerName!.isNotEmpty)
              Text(
                'Owner: ${profile.ownerName}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary.withOpacity(0.12),
              backgroundImage:
                  (profile?.logoUrl != null && profile!.logoUrl!.isNotEmpty)
                  ? NetworkImage(profile.logoUrl!)
                  : null,
              child: (profile?.logoUrl == null || profile!.logoUrl!.isEmpty)
                  ? Text(
                      (profile?.shopName != null &&
                              profile!.shopName!.isNotEmpty)
                          ? profile.shopName![0].toUpperCase()
                          : 'S',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(
          left: 16.0,
          right: 16.0,
          top: 16.0,
          bottom: 100.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatCards(context, ref),
            const SizedBox(height: 14),
            _buildKhataSummaryCard(context, ref),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const CreateInvoiceScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add, size: 24),
              label: const Text('CREATE NEW INVOICE'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 28),
            _buildRecentInvoicesSection(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildKhataSummaryCard(BuildContext context, WidgetRef ref) {
    final summariesAsync = ref.watch(customerKhataSummariesProvider);

    return InkWell(
      onTap: () {
        ref.read(dashboardIndexProvider.notifier).state = 1; // Khata tab
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.khataGave.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.khataGave.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.khataGave.withOpacity(0.15),
              child: const Icon(Icons.menu_book_rounded, color: AppColors.khataGave, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pending Udhar Collection',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.khataGave,
                    ),
                  ),
                  const SizedBox(height: 2),
                  summariesAsync.when(
                    data: (summaries) {
                      double pending = 0.0;
                      int count = 0;
                      for (final s in summaries) {
                        if (s.customerOwesMe) {
                          pending += s.netBalance;
                          count++;
                        }
                      }
                      return Text(
                        '₹${pending.toStringAsFixed(0)} ($count customers owe you)',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      );
                    },
                    loading: () => const Text('Loading Khata...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    error: (_, __) => const Text('Tap to view Khata Book', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.khataGave),
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
          child: InkWell(
            onTap: () {
              ref.read(dashboardIndexProvider.notifier).state = 4; // History tab
            },
            borderRadius: BorderRadius.circular(16),
            child: Card(
              color: AppColors.primary.withOpacity(0.08),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'Total Invoices',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    invoicesAsync.when(
                      data: (invoices) => Text(
                        invoices.length.toString(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      loading: () => const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      error: (_, __) => const Text(
                        '0',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: InkWell(
            onTap: () => _showReportsSummary(context, ref),
            borderRadius: BorderRadius.circular(16),
            child: Card(
              color: AppColors.success.withOpacity(0.08),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'Total Sales',
                      style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    invoicesAsync.when(
                      data: (invoices) {
                        final total = invoices.fold<double>(
                          0,
                          (sum, item) => sum + item.grandTotal,
                        );
                        return Text(
                          '₹${total.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        );
                      },
                      loading: () => const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      error: (_, __) => const Text(
                        '₹0',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showAddCustomerDialog(
    BuildContext context,
    WidgetRef ref,
    String shopId,
  ) {
    AddCustomerDialog.show(context, shopId: shopId);
  }

  void _showReportsSummary(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(invoicesProvider);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Business Report',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            invoicesAsync.when(
              data: (invoices) {
                final totalSales = invoices.fold<double>(
                  0,
                  (sum, i) => sum + i.grandTotal,
                );
                final totalGst = invoices.fold<double>(
                  0,
                  (sum, i) => sum + i.gstTotal,
                );
                return Column(
                  children: [
                    _reportRow('Total Invoices', '${invoices.length}'),
                    _reportRow(
                      'Total Sales Amount',
                      '₹${totalSales.toStringAsFixed(2)}',
                    ),
                    _reportRow(
                      'GST Collected',
                      '₹${totalGst.toStringAsFixed(2)}',
                    ),
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
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentInvoicesSection(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(invoicesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () {
                ref.read(dashboardIndexProvider.notifier).state =
                    3; // History tab
              },
              child: const Text('See All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        invoicesAsync.when(
          data: (invoices) {
            if (invoices.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Center(
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long, size: 40, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'No recent invoices',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            }

            final recent = invoices.take(3).toList();
            final currency = NumberFormat.currency(
              locale: 'en_IN',
              symbol: '₹',
            );

            return Column(
              children: recent.map((invoice) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    onTap: () => _viewInvoicePdf(context, ref, invoice.id),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: const Icon(
                        Icons.receipt,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      invoice.invoiceNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      invoice.customer?.customerName ?? 'Walk-in Customer',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    trailing: Text(
                      currency.format(invoice.grandTotal),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  void _viewInvoicePdf(
    BuildContext context,
    WidgetRef ref,
    String invoiceId,
  ) async {
    final profile = ref.read(profileProvider).value;
    if (profile == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final fullInvoice = await ref
          .read(businessRepoProvider)
          .getInvoiceDetails(invoiceId);

      if (context.mounted) {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => InvoicePreviewScreen(
              invoiceNumber: fullInvoice.invoiceNumber,
              invoiceDate: fullInvoice.invoiceDate,
              customer: fullInvoice.customer,
              items: fullInvoice.items ?? [],
              subtotal: fullInvoice.subtotal,
              gstTotal: fullInvoice.gstTotal,
              grandTotal: fullInvoice.grandTotal,
              shopProfile: profile,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
