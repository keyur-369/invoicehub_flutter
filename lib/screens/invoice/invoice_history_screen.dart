import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:invoicehub/providers/auth_provider.dart';
import 'package:invoicehub/providers/invoice_provider.dart';
import 'package:invoicehub/repositories/business_repository.dart';
import 'package:invoicehub/screens/invoice/invoice_preview_screen.dart';

class InvoiceHistoryScreen extends ConsumerWidget {
  const InvoiceHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(invoicesProvider);
    final profile = ref.watch(profileProvider).value;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Invoice History',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: invoicesAsync.when(
        data: (invoices) {
          if (invoices.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_edu, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No invoices generated yet',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: invoices.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final invoice = invoices[index];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: InkWell(
                  onTap: () => _viewInvoicePdf(context, ref, invoice.id),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  invoice.invoiceNumber,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat(
                                    'dd MMM yyyy, hh:mm a',
                                  ).format(invoice.createdAt),
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.green.shade200,
                                    ),
                                  ),
                                  child: Text(
                                    'PAID',
                                    style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.picture_as_pdf,
                                  color: Colors.indigo.shade300,
                                  size: 20,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(height: 1),
                        ),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.indigo.shade50,
                              child: const Icon(
                                Icons.person,
                                size: 18,
                                color: Colors.indigo,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    invoice.customer?.customerName ??
                                        'Walk-in Customer',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    invoice.customer?.mobile ?? 'No mobile',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              currency.format(invoice.grandTotal),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.indigo.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _viewInvoicePdf(
    BuildContext context,
    WidgetRef ref,
    String invoiceId,
  ) async {
    final profile = ref.read(profileProvider).value;
    if (profile == null) return;

    // Show loading
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
        Navigator.pop(context); // Pop loading
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
        Navigator.pop(context); // Pop loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching invoice details: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
