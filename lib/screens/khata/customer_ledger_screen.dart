import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:invoicehub/models/business_models.dart';
import 'package:invoicehub/models/khata_model.dart';
import 'package:invoicehub/models/profile.dart';
import 'package:invoicehub/providers/auth_provider.dart';
import 'package:invoicehub/providers/khata_provider.dart';
import 'package:invoicehub/services/khata_pdf_service.dart';
import 'package:invoicehub/screens/khata/widgets/add_khata_entry_dialog.dart';
import 'package:invoicehub/widgets/app_colors.dart';

class CustomerLedgerScreen extends ConsumerStatefulWidget {
  final Customer customer;

  const CustomerLedgerScreen({super.key, required this.customer});

  @override
  ConsumerState<CustomerLedgerScreen> createState() => _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState extends ConsumerState<CustomerLedgerScreen> {
  String _selectedDateFilter = 'ALL'; // ALL, THIS_MONTH, LAST_30_DAYS, CUSTOM
  DateTimeRange? _customDateRange;

  void _sendWhatsAppReminder(BuildContext context, double balance, String shopName) async {
    final phone = widget.customer.mobile?.replaceAll(RegExp(r'\D'), '') ?? '';
    final formattedBalance = balance.abs().toStringAsFixed(0);
    final message =
        "Dear ${widget.customer.customerName},\nYour pending balance at *$shopName* is *₹$formattedBalance*.\nKindly settle the payment at your earliest convenience.\nThank you!";

    if (phone.isNotEmpty) {
      final whatsappUrl = Uri.parse("https://wa.me/91$phone?text=${Uri.encodeComponent(message)}");
      try {
        if (await canLaunchUrl(whatsappUrl)) {
          await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (_) {}
    }

    // Fallback to general Share
    Share.share(message, subject: 'Payment Reminder from $shopName');
  }

  void _shareStatement(List<KhataTransaction> txs, String shopName) {
    double totalGave = 0.0;
    double totalGot = 0.0;
    final buffer = StringBuffer();
    buffer.writeln("📋 *ACCOUNT STATEMENT - ${widget.customer.customerName}*");
    buffer.writeln("Shop: $shopName");
    buffer.writeln("Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}");
    buffer.writeln("-----------------------------------");

    for (final tx in txs.reversed) {
      final dateStr = DateFormat('dd MMM yyyy').format(tx.transactionDate);
      if (tx.isGave) {
        totalGave += tx.amount;
        buffer.writeln("🔴 $dateStr: Gave ₹${tx.amount.toStringAsFixed(0)} (${tx.paymentMode})");
      } else {
        totalGot += tx.amount;
        buffer.writeln("🟢 $dateStr: Got ₹${tx.amount.toStringAsFixed(0)} (${tx.paymentMode})");
      }
    }

    final net = totalGave - totalGot;
    buffer.writeln("-----------------------------------");
    buffer.writeln("Total Gave: ₹${totalGave.toStringAsFixed(0)}");
    buffer.writeln("Total Got: ₹${totalGot.toStringAsFixed(0)}");
    if (net > 0) {
      buffer.writeln("NET OUTSTANDING: ₹${net.toStringAsFixed(0)} (CUSTOMER OWES)");
    } else if (net < 0) {
      buffer.writeln("NET BALANCE: ₹${net.abs().toStringAsFixed(0)} (SHOP OWES)");
    } else {
      buffer.writeln("NET BALANCE: ₹0 (SETTLED)");
    }

    Share.share(buffer.toString(), subject: 'Ledger Statement for ${widget.customer.customerName}');
  }

  Future<void> _generatePdfReport(List<KhataTransaction> txs, Profile? profile) async {
    final shop = profile ?? Profile(id: '', userId: '', role: 'shop_owner', shopName: 'My Shop', mobile: '', address: '', createdAt: DateTime.now(), updatedAt: DateTime.now());
    
    String dateText = 'All Time';
    if (_selectedDateFilter == 'THIS_MONTH') {
      dateText = DateFormat('MMMM yyyy').format(DateTime.now());
    } else if (_selectedDateFilter == 'LAST_30_DAYS') {
      dateText = 'Last 30 Days';
    } else if (_selectedDateFilter == 'CUSTOM' && _customDateRange != null) {
      final start = DateFormat('dd MMM yyyy').format(_customDateRange!.start);
      final end = DateFormat('dd MMM yyyy').format(_customDateRange!.end);
      dateText = '$start to $end';
    }

    await Printing.layoutPdf(
      name: 'Khata_Statement_${widget.customer.customerName.replaceAll(" ", "_")}.pdf',
      onLayout: (PdfPageFormat format) => KhataPdfService.generateCustomerLedgerPdf(
        shop: shop,
        customer: widget.customer,
        transactions: txs,
        dateRangeText: dateText,
        format: format,
      ),
    );
  }

  void _callCustomer() async {
    final phone = widget.customer.mobile?.replaceAll(RegExp(r'\D'), '') ?? '';
    if (phone.isNotEmpty) {
      final url = Uri.parse("tel:$phone");
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    }
  }

  List<KhataTransaction> _filterTransactions(List<KhataTransaction> txs) {
    if (_selectedDateFilter == 'ALL') return txs;

    final now = DateTime.now();
    if (_selectedDateFilter == 'THIS_MONTH') {
      return txs.where((t) => t.transactionDate.year == now.year && t.transactionDate.month == now.month).toList();
    } else if (_selectedDateFilter == 'LAST_30_DAYS') {
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      return txs.where((t) => t.transactionDate.isAfter(thirtyDaysAgo)).toList();
    } else if (_selectedDateFilter == 'CUSTOM' && _customDateRange != null) {
      final start = DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day);
      final end = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59);
      return txs.where((t) => t.transactionDate.isAfter(start) && t.transactionDate.isBefore(end)).toList();
    }
    return txs;
  }

  @override
  Widget build(BuildContext context) {
    final txsAsync = ref.watch(customerKhataDetailProvider(widget.customer.id));
    final profile = ref.watch(profileProvider).value;
    final shopName = profile?.shopName ?? 'My Shop';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.customer.customerName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (widget.customer.mobile != null && widget.customer.mobile!.isNotEmpty)
              Text(
                widget.customer.mobile!,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        actions: [
          if (widget.customer.mobile != null && widget.customer.mobile!.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.call_rounded, color: AppColors.primary),
              tooltip: 'Call Customer',
              onPressed: _callCustomer,
            ),
          ],
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.primary),
            tooltip: 'Download CA PDF Report',
            onPressed: () {
              final txs = txsAsync.value ?? [];
              final filtered = _filterTransactions(txs);
              _generatePdfReport(filtered, profile);
            },
          ),
        ],
      ),
      body: txsAsync.when(
        data: (allTxs) {
          final txs = _filterTransactions(allTxs);

          double totalGave = 0.0;
          double totalGot = 0.0;
          for (final tx in txs) {
            if (tx.isGave) {
              totalGave += tx.amount;
            } else {
              totalGot += tx.amount;
            }
          }
          final netBalance = totalGave - totalGot;
          final customerOwes = netBalance > 0.01;
          final shopOwes = netBalance < -0.01;

          return Column(
            children: [
              // Top Balance Card Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      customerOwes
                          ? 'YOU WILL GET (Aapko Milenge)'
                          : (shopOwes ? 'YOU WILL GIVE (Aapne Dene Hain)' : 'ACCOUNT SETTLED'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: customerOwes
                            ? AppColors.khataGave
                            : (shopOwes ? AppColors.khataGot : AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${netBalance.abs().toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: customerOwes
                            ? AppColors.khataGave
                            : (shopOwes ? AppColors.khataGot : AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _summaryBadge('Total Gave', '₹${totalGave.toStringAsFixed(0)}', AppColors.khataGave),
                        Container(width: 1, height: 30, color: AppColors.border),
                        _summaryBadge('Total Got', '₹${totalGot.toStringAsFixed(0)}', AppColors.khataGot),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Quick Action Buttons (WhatsApp, Share, PDF)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: customerOwes
                                ? () => _sendWhatsAppReminder(context, netBalance, shopName)
                                : null,
                            icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF25D366), size: 16),
                            label: const Text(
                              'WhatsApp',
                              style: TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: customerOwes ? const Color(0xFF25D366) : AppColors.border),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: txs.isEmpty ? null : () => _shareStatement(txs, shopName),
                            icon: const Icon(Icons.share_outlined, size: 16),
                            label: const Text(
                              'Share Text',
                              style: TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _generatePdfReport(txs, profile),
                            icon: const Icon(Icons.print_outlined, size: 16),
                            label: const Text(
                              'CA Report',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Filter Chips Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _filterChip('All Time', 'ALL'),
                    const SizedBox(width: 8),
                    _filterChip('This Month', 'THIS_MONTH'),
                    const SizedBox(width: 8),
                    _filterChip('Last 30 Days', 'LAST_30_DAYS'),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(
                        _selectedDateFilter == 'CUSTOM' && _customDateRange != null
                            ? '${DateFormat('dd/MM').format(_customDateRange!.start)} - ${DateFormat('dd/MM').format(_customDateRange!.end)}'
                            : 'Custom Date',
                        style: TextStyle(
                          fontSize: 12,
                          color: _selectedDateFilter == 'CUSTOM' ? Colors.white : AppColors.textPrimary,
                          fontWeight: _selectedDateFilter == 'CUSTOM' ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      selected: _selectedDateFilter == 'CUSTOM',
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      onSelected: (selected) async {
                        if (selected) {
                          final range = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (range != null) {
                            setState(() {
                              _customDateRange = range;
                              _selectedDateFilter = 'CUSTOM';
                            });
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),

              // Timeline List of Transactions
              Expanded(
                child: txs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.menu_book_rounded, size: 56, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            const Text(
                              'No transactions recorded in selected period',
                              style: TextStyle(fontSize: 15, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Use buttons below to add Udhar or Payments',
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                        itemCount: txs.length,
                        itemBuilder: (context, index) {
                          final tx = txs[index];
                          return _buildTransactionCard(context, ref, tx);
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading ledger: $e')),
      ),

      // Bottom Sticky Action Bar (YOU GAVE / YOU GOT)
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  AddKhataEntryDialog.show(context, customer: widget.customer, type: 'GAVE');
                },
                icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                label: const Text('YOU GAVE ₹'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.khataGave,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  elevation: 2,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  AddKhataEntryDialog.show(context, customer: widget.customer, type: 'GOT');
                },
                icon: const Icon(Icons.arrow_downward_rounded, size: 20),
                label: const Text('YOU GOT ₹'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.khataGot,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _selectedDateFilter == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isSelected ? Colors.white : AppColors.textPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedDateFilter = value;
          });
        }
      },
    );
  }

  Widget _summaryBadge(String title, String amount, Color color) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          amount,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildTransactionCard(BuildContext context, WidgetRef ref, KhataTransaction tx) {
    final isGave = tx.isGave;
    final color = isGave ? AppColors.khataGave : AppColors.khataGot;
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(tx.transactionDate);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border.withOpacity(0.8)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showTransactionDetailSheet(context, ref, tx),
        onLongPress: () => _confirmDelete(context, ref, tx),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withOpacity(0.12),
                child: Icon(
                  isGave ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isGave ? 'You Gave' : 'You Got',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            tx.paymentMode.replaceAll('_', ' '),
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                          ),
                        ),
                        if (tx.invoiceNumber != null && tx.invoiceNumber!.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Inv: ${tx.invoiceNumber}',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateStr,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    if (tx.referenceNo != null && tx.referenceNo!.isNotEmpty && tx.invoiceNumber != tx.referenceNo) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Ref: ${tx.referenceNo}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                      ),
                    ],
                    if (tx.notes != null && tx.notes!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        tx.notes!,
                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.textPrimary),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isGave ? "-" : "+"} ₹${tx.amount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTransactionDetailSheet(BuildContext context, WidgetRef ref, KhataTransaction tx) {
    final isGave = tx.isGave;
    final color = isGave ? AppColors.khataGave : AppColors.khataGot;
    final dateStr = DateFormat('dd MMMM yyyy, hh:mm a').format(tx.transactionDate);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: color.withOpacity(0.12),
                  child: Icon(
                    isGave ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isGave ? 'You Gave (Udhar)' : 'You Got (Payment)',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
                      ),
                      Text(
                        dateStr,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₹${tx.amount.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: AppColors.border),
            const SizedBox(height: 12),

            _detailRow('Customer', widget.customer.customerName),
            _detailRow('Payment Mode', tx.paymentMode.replaceAll('_', ' ')),
            if (tx.invoiceNumber != null && tx.invoiceNumber!.isNotEmpty)
              _detailRow('Invoice Reference', tx.invoiceNumber!),
            if (tx.referenceNo != null && tx.referenceNo!.isNotEmpty)
              _detailRow(
                tx.paymentMode == 'UPI'
                    ? 'UPI Transaction ID'
                    : (tx.paymentMode == 'CHEQUE' ? 'Cheque No.' : 'Reference No.'),
                tx.referenceNo!,
              ),
            if (tx.notes != null && tx.notes!.isNotEmpty)
              _detailRow('Notes / Description', tx.notes!),

            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _confirmDelete(context, ref, tx);
                    },
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                    label: const Text('Delete Entry', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, KhataTransaction tx) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: Text('Are you sure you want to delete this ${tx.isGave ? "Udhar" : "Payment"} entry of ₹${tx.amount.toStringAsFixed(0)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(khataControllerProvider).deleteTransaction(tx.id, widget.customer.id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
