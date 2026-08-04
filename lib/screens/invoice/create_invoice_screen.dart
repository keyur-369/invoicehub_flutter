import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:invoicehub/models/business_models.dart';
import 'package:invoicehub/models/invoice_model.dart';
import 'package:invoicehub/providers/auth_provider.dart';
import 'package:invoicehub/repositories/business_repository.dart';
import 'package:invoicehub/screens/invoice/invoice_preview_screen.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:invoicehub/providers/invoice_provider.dart';
import 'package:invoicehub/providers/product_provider.dart';
import 'package:invoicehub/providers/customer_provider.dart';
import 'package:invoicehub/widgets/add_customer_dialog.dart';
import 'package:invoicehub/widgets/app_colors.dart';
import 'package:uuid/uuid.dart';
import 'package:invoicehub/models/khata_model.dart';
import 'package:invoicehub/providers/khata_provider.dart';

class CreateInvoiceScreen extends ConsumerStatefulWidget {
  const CreateInvoiceScreen({super.key});

  @override
  ConsumerState<CreateInvoiceScreen> createState() =>
      _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends ConsumerState<CreateInvoiceScreen> {
  final _invoiceNumberController = TextEditingController(
    text: 'INV-${DateFormat('yyyyMMddHHmm').format(DateTime.now())}',
  );
  final _dateController = TextEditingController(
    text: DateFormat('dd/MM/yyyy').format(DateTime.now()),
  );

  Customer? _selectedCustomer;
  final List<InvoiceItem> _items = [];

  double _subtotal = 0.0;
  double _gstTotal = 0.0;
  double _grandTotal = 0.0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _addItem();
  }

  void _addItem() {
    setState(() {
      _items.add(
        InvoiceItem(
          id: const Uuid().v4(),
          invoiceId: '',
          quantity: 1,
          rate: 0,
          gstPercentage: 0,
        ),
      );
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
      _calculateTotals();
    });
  }

  void _calculateTotals() {
    double sub = 0;
    double gst = 0;
    for (var item in _items) {
      final amount = item.quantity * item.rate;
      final itemGst = amount * (item.gstPercentage / 100);
      sub += amount;
      gst += itemGst;
    }
    setState(() {
      _subtotal = sub;
      _gstTotal = gst;
      _grandTotal = sub + gst;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Create Invoice'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeaderSection(),
            const SizedBox(height: 24),
            _buildCustomerSection(),
            const SizedBox(height: 24),
            const Text(
              'Items',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            _buildItemsList(),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add, color: AppColors.primary),
              label: const Text(
                'Add Item',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.primary.withOpacity(0.08),
                side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildSummarySection(),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : () => _openPreview(context),
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textOnPrimary,
                      ),
                    )
                  : const Icon(Icons.visibility_outlined),
              label: Text(
                _isSaving ? 'SAVING INVOICE...' : 'PREVIEW & GENERATE PDF',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPreview(BuildContext context) async {
    final profile = ref.read(profileProvider).value;
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile not loaded. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Validate: at least one item with a product name
    final validItems = _items
        .where((i) => (i.productName?.isNotEmpty ?? false))
        .toList();
    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one product item.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // Parse invoice date from controller
    DateTime parsedDate;
    try {
      parsedDate = DateFormat('dd/MM/yyyy').parse(_dateController.text);
    } catch (_) {
      parsedDate = DateTime.now();
    }

    setState(() => _isSaving = true);

    try {
      // 1. Create Invoice object
      final invoice = Invoice(
        id: const Uuid().v4(),
        shopId: profile.id,
        customerId: _selectedCustomer?.id,
        invoiceNumber: _invoiceNumberController.text,
        invoiceDate: parsedDate,
        subtotal: _subtotal,
        gstTotal: _gstTotal,
        grandTotal: _grandTotal,
        createdAt: DateTime.now(),
      );

      // 2. Map items with current totals
      final finalItems = validItems.map((i) {
        final base = i.quantity * i.rate;
        final gstAmt = base * (i.gstPercentage / 100);
        return InvoiceItem(
          id: i.id,
          invoiceId: invoice.id,
          productName: i.productName,
          quantity: i.quantity,
          rate: i.rate,
          gstPercentage: i.gstPercentage,
          gstAmount: gstAmt,
          totalAmount: base + gstAmt,
        );
      }).toList();

      // 3. Save to Supabase
      await ref.read(businessRepoProvider).createInvoice(invoice, finalItems);

      // 4. Auto-save new items to Shop Product Inventory
      final currentUser = ref.read(currentUserProvider);
      if (currentUser != null) {
        try {
          final existingProducts = await ref.read(
            unifiedProductsProvider.future,
          );
          final existingNames = existingProducts
              .map((p) => p.product?.productName.trim().toLowerCase() ?? '')
              .toSet();

          for (final item in finalItems) {
            final name = item.productName?.trim() ?? '';
            if (name.isNotEmpty &&
                !existingNames.contains(name.toLowerCase())) {
              await ref
                  .read(businessRepoProvider)
                  .createDirectProductForShop(
                    shopId: profile.id,
                    userId: currentUser.id,
                    productName: name,
                    rate: item.rate,
                    gstPercentage: item.gstPercentage,
                  );
            }
          }
          ref.invalidate(shopProductsProvider);
          ref.invalidate(unifiedProductsProvider);
        } catch (e) {
          // Non-blocking auto-save
        }
      }

      // 5. Auto-record in Khata Book if a customer is selected
      if (_selectedCustomer != null) {
        try {
          final khataTx = KhataTransaction(
            id: '',
            shopId: profile.id,
            customerId: _selectedCustomer!.id,
            transactionType: 'GAVE',
            amount: _grandTotal,
            paymentMode: 'INVOICE',
            transactionDate: parsedDate,
            notes: 'Invoice #${_invoiceNumberController.text}',
            createdAt: DateTime.now(),
          );
          await ref.read(khataControllerProvider).addTransaction(khataTx);
        } catch (_) {
          // Non-blocking auto-record
        }
      }

      // 6. Refresh history provider
      ref.invalidate(invoicesProvider);

      if (!mounted) return;

      // 6. Proceed to Preview
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InvoicePreviewScreen(
            invoiceNumber: _invoiceNumberController.text,
            invoiceDate: parsedDate,
            customer: _selectedCustomer,
            items: finalItems,
            subtotal: _subtotal,
            gstTotal: _gstTotal,
            grandTotal: _grandTotal,
            shopProfile: profile,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save invoice: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildHeaderSection() {
    return Card(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _invoiceNumberController,
                decoration: InputDecoration(
                  labelText: 'Invoice No.',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _dateController,
                decoration: InputDecoration(
                  labelText: 'Date',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  suffixIcon: const Icon(
                    Icons.calendar_today,
                    color: AppColors.textSecondary,
                  ),
                ),
                readOnly: true,
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (date != null) {
                    _dateController.text = DateFormat(
                      'dd/MM/yyyy',
                    ).format(date);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerSection() {
    final profile = ref.watch(profileProvider).value;
    return Card(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Customer Details',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextButton.icon(
                  onPressed: _showAddCustomerDialog,
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: const Text('New Customer'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TypeAheadField<Customer>(
              builder: (context, controller, focusNode) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: 'Search or Select Customer',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              },
              suggestionsCallback: (pattern) async {
                final customers = await ref
                    .read(businessRepoProvider)
                    .getCustomers(profile!.id);
                return customers
                    .where(
                      (c) => c.customerName.toLowerCase().contains(
                        pattern.toLowerCase(),
                      ),
                    )
                    .toList();
              },
              itemBuilder: (context, customer) {
                return ListTile(
                  title: Text(customer.customerName),
                  subtitle: Text(customer.mobile ?? ''),
                );
              },
              onSelected: (customer) {
                setState(() => _selectedCustomer = customer);
              },
            ),
            if (_selectedCustomer != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedCustomer!.customerName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Mob: ${_selectedCustomer!.mobile ?? 'N/A'} | City: ${_selectedCustomer!.city ?? 'N/A'}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _selectedCustomer = null),
                      icon: const Icon(
                        Icons.close,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAddCustomerDialog() async {
    final profile = ref.read(profileProvider).value;
    final shopId = profile?.id;
    if (shopId == null || shopId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile not loaded. Please try again.')),
      );
      return;
    }

    final savedCustomer = await AddCustomerDialog.show(
      context,
      shopId: shopId,
      saveButtonText: 'Save & Select',
    );

    if (savedCustomer != null) {
      setState(() => _selectedCustomer = savedCustomer);
    }
  }

  /// Opens a modal bottom sheet with a search field for products.
  /// This avoids the TypeAheadField gesture conflict with the parent SingleChildScrollView.
  Future<void> _showProductPickerSheet(int index) async {
    List<ShopProduct> allProducts = [];
    List<ShopProduct> filtered = [];
    bool isLoading = true;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final searchCtrl = TextEditingController();
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            // Load products once
            if (isLoading) {
              ref
                  .read(unifiedProductsProvider.future)
                  .then((products) {
                    setSheetState(() {
                      allProducts = products;
                      filtered = products;
                      isLoading = false;
                    });
                  })
                  .catchError((e) {
                    setSheetState(() => isLoading = false);
                  });
            }

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.75,
              maxChildSize: 0.95,
              minChildSize: 0.4,
              builder: (_, scrollController) => Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                ),
                child: Column(
                  children: [
                    // Handle
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const Text(
                      'Select Product',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: searchCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search product...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (val) {
                        setSheetState(() {
                          filtered = allProducts
                              .where(
                                (p) =>
                                    p.product?.productName
                                        .toLowerCase()
                                        .contains(val.toLowerCase()) ??
                                    false,
                              )
                              .toList();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.search_off,
                                    size: 48,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No existing products found',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  if (searchCtrl.text.trim().isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.add),
                                      label: Text(
                                        'Use "${searchCtrl.text.trim()}"',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor:
                                            AppColors.textOnPrimary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _items[index] = InvoiceItem(
                                            id: _items[index].id,
                                            invoiceId: '',
                                            productName: searchCtrl.text.trim(),
                                            quantity: _items[index].quantity,
                                            rate: _items[index].rate,
                                            gstPercentage:
                                                _items[index].gstPercentage,
                                          );
                                          _calculateTotals();
                                        });
                                        Navigator.pop(ctx);
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            )
                          : ListView.separated(
                              controller: scrollController,
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(
                                height: 1,
                                color: AppColors.border,
                              ),
                              itemBuilder: (_, i) {
                                final shopProduct = filtered[i];
                                final product = shopProduct.product;
                                if (product == null)
                                  return const SizedBox.shrink();

                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: AppColors.primary
                                        .withOpacity(0.1),
                                    child: Text(
                                      product.productName[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    product.productName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${product.brand?.brandName ?? ''} • ${product.category?.categoryName ?? ''} • GST ${shopProduct.gstPercentage.toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  trailing: shopProduct.customRate > 0
                                      ? Text(
                                          '₹${shopProduct.customRate}',
                                          style: const TextStyle(
                                            color: AppColors.success,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null,
                                  onTap: () {
                                    setState(() {
                                      _items[index] = InvoiceItem(
                                        id: _items[index].id,
                                        invoiceId: '',
                                        productName: product.productName,
                                        quantity: _items[index].quantity,
                                        rate: shopProduct.customRate,
                                        gstPercentage:
                                            shopProduct.gstPercentage,
                                      );
                                      _calculateTotals();
                                    });
                                    Navigator.pop(ctx);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildItemsList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = _items[index];
        return _ItemRowWidget(
          key: ValueKey(item.id),
          item: item,
          onPickProduct: () => _showProductPickerSheet(index),
          onDelete: () => _removeItem(index),
          onChanged: (updatedItem) {
            setState(() {
              _items[index] = updatedItem;
              _calculateTotals();
            });
          },
        );
      },
    );
  }

  Widget _buildSummarySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Total Amount',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14.0),
          child: Column(
            children: [
              _buildSummaryRow('Subtotal', '₹${_subtotal.toStringAsFixed(2)}'),
              const SizedBox(height: 6),
              _buildSummaryRow('GST Total', '₹${_gstTotal.toStringAsFixed(2)}'),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1, color: AppColors.border),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Grand Total',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '₹${_grandTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ItemRowWidget extends StatefulWidget {
  final InvoiceItem item;
  final VoidCallback onPickProduct;
  final VoidCallback onDelete;
  final ValueChanged<InvoiceItem> onChanged;

  const _ItemRowWidget({
    super.key,
    required this.item,
    required this.onPickProduct,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  State<_ItemRowWidget> createState() => _ItemRowWidgetState();
}

class _ItemRowWidgetState extends State<_ItemRowWidget> {
  late TextEditingController _qtyController;
  late TextEditingController _rateController;
  late TextEditingController _gstController;

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(
      text: widget.item.quantity > 0
          ? (widget.item.quantity % 1 == 0
                ? widget.item.quantity.toInt().toString()
                : widget.item.quantity.toString())
          : '1',
    );
    _rateController = TextEditingController(
      text: widget.item.rate > 0
          ? (widget.item.rate % 1 == 0
                ? widget.item.rate.toInt().toString()
                : widget.item.rate.toString())
          : '',
    );
    _gstController = TextEditingController(
      text: widget.item.gstPercentage > 0
          ? (widget.item.gstPercentage % 1 == 0
                ? widget.item.gstPercentage.toInt().toString()
                : widget.item.gstPercentage.toString())
          : '0',
    );
  }

  @override
  void didUpdateWidget(covariant _ItemRowWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (double.tryParse(_qtyController.text) != widget.item.quantity) {
      _qtyController.text = widget.item.quantity > 0
          ? (widget.item.quantity % 1 == 0
                ? widget.item.quantity.toInt().toString()
                : widget.item.quantity.toString())
          : '1';
    }
    if (double.tryParse(_rateController.text) != widget.item.rate) {
      _rateController.text = widget.item.rate > 0
          ? (widget.item.rate % 1 == 0
                ? widget.item.rate.toInt().toString()
                : widget.item.rate.toString())
          : '';
    }
    if (double.tryParse(_gstController.text) != widget.item.gstPercentage) {
      _gstController.text = widget.item.gstPercentage > 0
          ? (widget.item.gstPercentage % 1 == 0
                ? widget.item.gstPercentage.toInt().toString()
                : widget.item.gstPercentage.toString())
          : '0';
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _rateController.dispose();
    _gstController.dispose();
    super.dispose();
  }

  void _notifyChange() {
    final qty = double.tryParse(_qtyController.text) ?? 1.0;
    final rate = double.tryParse(_rateController.text) ?? 0.0;
    final gst = double.tryParse(_gstController.text) ?? 0.0;

    widget.onChanged(
      InvoiceItem(
        id: widget.item.id,
        invoiceId: widget.item.invoiceId,
        productName: widget.item.productName,
        quantity: qty,
        rate: rate,
        gstPercentage: gst,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedProductName = widget.item.productName;
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: widget.onPickProduct,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedProductName ?? 'Tap to search product',
                              style: TextStyle(
                                color: selectedProductName != null
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (selectedProductName != null)
                            GestureDetector(
                              onTap: () {
                                widget.onChanged(
                                  InvoiceItem(
                                    id: widget.item.id,
                                    invoiceId: '',
                                    productName: null,
                                    quantity: 1,
                                    rate: 0,
                                    gstPercentage: 0,
                                  ),
                                );
                              },
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: widget.onDelete,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qtyController,
                    decoration: InputDecoration(
                      labelText: 'Qty',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => _notifyChange(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _rateController,
                    decoration: InputDecoration(
                      labelText: 'Rate (₹)',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => _notifyChange(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _gstController,
                    decoration: InputDecoration(
                      labelText: 'GST %',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => _notifyChange(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
