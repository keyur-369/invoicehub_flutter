import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:invoicehub/models/khata_model.dart';
import 'package:invoicehub/models/profile.dart';
import 'package:invoicehub/providers/khata_provider.dart';
import 'package:invoicehub/providers/auth_provider.dart';
import 'package:invoicehub/services/khata_pdf_service.dart';
import 'package:invoicehub/screens/khata/customer_ledger_screen.dart';
import 'package:invoicehub/screens/khata/widgets/add_khata_entry_dialog.dart';
import 'package:invoicehub/widgets/app_colors.dart';
import 'package:invoicehub/widgets/add_customer_dialog.dart';

class KhataDashboardScreen extends ConsumerStatefulWidget {
  final VoidCallback? onOpenDrawer;

  const KhataDashboardScreen({super.key, this.onOpenDrawer});

  @override
  ConsumerState<KhataDashboardScreen> createState() =>
      _KhataDashboardScreenState();
}

class _KhataDashboardScreenState extends ConsumerState<KhataDashboardScreen> {
  String _searchQuery = '';
  int _selectedFilterTab = 0; // 0: All, 1: You'll Get (Udhar), 2: Settled

  Future<void> _exportShopCaReport(List<CustomerKhataSummary> summaries, Profile? profile) async {
    final shop = profile ?? Profile(id: '', userId: '', role: 'shop_owner', shopName: 'My Shop', mobile: '', address: '', createdAt: DateTime.now(), updatedAt: DateTime.now());

    await Printing.layoutPdf(
      name: 'Shop_Khata_CA_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      onLayout: (PdfPageFormat format) => KhataPdfService.generateShopKhataReportPdf(
        shop: shop,
        customerSummaries: summaries,
        format: format,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summariesAsync = ref.watch(customerKhataSummariesProvider);
    final profile = ref.watch(profileProvider).value;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: Builder(
          builder: (scaffoldCtx) => IconButton(
            icon: const Icon(Icons.menu_rounded, size: 28),
            tooltip: 'Open Menu',
            onPressed: () {
              if (widget.onOpenDrawer != null) {
                widget.onOpenDrawer!();
              } else {
                Scaffold.of(scaffoldCtx).openDrawer();
              }
            },
          ),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Khata Book',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Customer Udhar & Payment Ledger',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.picture_as_pdf_outlined,
              color: AppColors.primary,
            ),
            tooltip: 'Export Full CA Report',
            onPressed: () {
              final summaries = summariesAsync.value ?? [];
              if (summaries.isNotEmpty) {
                _exportShopCaReport(summaries, profile);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No Khata entries available to generate CA report.')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.person_add_outlined,
              color: AppColors.primary,
            ),
            tooltip: 'Add Customer',
            onPressed: () {
              if (profile != null) {
                AddCustomerDialog.show(context, shopId: profile.id);
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(customerKhataSummariesProvider);
        },
        child: summariesAsync.when(
          data: (summaries) {
            double totalWillGet = 0.0;
            double totalWillGive = 0.0;

            for (final s in summaries) {
              if (s.customerOwesMe) {
                totalWillGet += s.netBalance;
              } else if (s.iOweCustomer) {
                totalWillGive += s.netBalance.abs();
              }
            }

            // Filter logic
            final filtered = summaries.where((s) {
              final queryMatch =
                  s.customer.customerName.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ) ||
                  (s.customer.mobile?.contains(_searchQuery) ?? false);

              if (!queryMatch) return false;

              if (_selectedFilterTab == 1) {
                return s.customerOwesMe; // Udhar only
              } else if (_selectedFilterTab == 2) {
                return s.isSettled; // Settled only
              }
              return true;
            }).toList();

            return Column(
              children: [
                // Top Summary Header
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [AppColors.cardShadow],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.khataGave.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.khataGave.withOpacity(0.2),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.arrow_upward_rounded,
                                        color: AppColors.khataGave,
                                        size: 16,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        "You'll Get",
                                        style: TextStyle(
                                          color: AppColors.khataGave,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '₹${totalWillGet.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.khataGave,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.khataGot.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.khataGot.withOpacity(0.2),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.arrow_downward_rounded,
                                        color: AppColors.khataGot,
                                        size: 16,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        "You'll Give",
                                        style: TextStyle(
                                          color: AppColors.khataGot,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '₹${totalWillGive.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.khataGot,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _exportShopCaReport(summaries, profile),
                        icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                        label: const Text('Generate CA Financial Summary PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 42),
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search customer name or phone...',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.textSecondary,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () =>
                                  setState(() => _searchQuery = ''),
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Filter Tabs
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _filterTab('All Accounts', 0, summaries.length),
                      const SizedBox(width: 8),
                      _filterTab(
                        "You'll Get",
                        1,
                        summaries.where((s) => s.customerOwesMe).length,
                        color: AppColors.khataGave,
                      ),
                      const SizedBox(width: 8),
                      _filterTab(
                        'Settled',
                        2,
                        summaries.where((s) => s.isSettled).length,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Customer Accounts List
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.menu_book_rounded,
                                size: 64,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No Khata accounts found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Tap "NEW ENTRY" or add a customer to start tracking udhar',
                                style: TextStyle(fontSize: 13, color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            return _buildCustomerSummaryTile(context, item);
                          },
                        ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error loading Khata: $e')),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 75.0),
        child: FloatingActionButton.extended(
          onPressed: () {
            AddKhataEntryDialog.show(context);
          },
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text(
            'New Entry',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterTab(
    String label,
    int index,
    int count, {
    Color? color,
  }) {
    final isSelected = _selectedFilterTab == index;
    final activeColor = color ?? AppColors.primary;

    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      selectedColor: activeColor,
      backgroundColor: AppColors.surface,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? activeColor : AppColors.border,
        ),
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilterTab = index;
          });
        }
      },
    );
  }

  Widget _buildCustomerSummaryTile(
    BuildContext context,
    CustomerKhataSummary summary,
  ) {
    final net = summary.netBalance;
    final owesMe = summary.customerOwesMe;
    final iOwe = summary.iOweCustomer;
    final settled = summary.isSettled;

    Color statusColor = AppColors.textSecondary;
    String statusText = 'SETTLED';

    if (owesMe) {
      statusColor = AppColors.khataGave;
      statusText = "You'll Get";
    } else if (iOwe) {
      statusColor = AppColors.khataGot;
      statusText = "You'll Give";
    }

    final lastDateStr = summary.lastTransactionDate != null
        ? DateFormat('dd MMM').format(summary.lastTransactionDate!)
        : 'No entries';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border.withOpacity(0.8)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CustomerLedgerScreen(customer: summary.customer),
            ),
          );
        },
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: Text(
            summary.customer.customerName.isNotEmpty
                ? summary.customer.customerName[0].toUpperCase()
                : 'C',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                summary.customer.customerName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              lastDateStr,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              if (summary.customer.mobile != null &&
                  summary.customer.mobile!.isNotEmpty)
                Text(
                  summary.customer.mobile!,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
            ],
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              settled ? '₹0' : '₹${net.abs().toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
