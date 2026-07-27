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
import 'package:uuid/uuid.dart';


class CreateInvoiceScreen extends ConsumerStatefulWidget {
  const CreateInvoiceScreen({super.key});

  @override
  ConsumerState<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends ConsumerState<CreateInvoiceScreen> {
  final _invoiceNumberController = TextEditingController(text: 'INV-${DateFormat('yyyyMMddHHmm').format(DateTime.now())}');
  final _dateController = TextEditingController(text: DateFormat('dd/MM/yyyy').format(DateTime.now()));
  
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
      _items.add(InvoiceItem(
        id: const Uuid().v4(),
        invoiceId: '',
        quantity: 1,
        rate: 0,
        gstPercentage: 0,
      ));
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
      appBar: AppBar(title: const Text('Create Invoice')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeaderSection(),
            const SizedBox(height: 24),
            _buildCustomerSection(),
            const SizedBox(height: 24),
            const Text('Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildItemsList(),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade50, foregroundColor: Colors.blue),
            ),
            const SizedBox(height: 24),
            _buildSummarySection(),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : () => _openPreview(context),
              icon: _isSaving 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.visibility_outlined),
              label: Text(
                _isSaving ? 'SAVING INVOICE...' : 'PREVIEW & GENERATE PDF', 
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.indigo.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        const SnackBar(content: Text('Profile not loaded. Please try again.'), backgroundColor: Colors.red),
      );
      return;
    }

    // Validate: at least one item with a product name
    final validItems = _items.where((i) => (i.productName?.isNotEmpty ?? false)).toList();
    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one product item.'), backgroundColor: Colors.orange),
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
      
      // 4. Refresh history provider
      ref.invalidate(invoicesProvider);

      if (!mounted) return;

      // 5. Proceed to Preview
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
          SnackBar(content: Text('Failed to save invoice: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildHeaderSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _invoiceNumberController,
                decoration: const InputDecoration(labelText: 'Invoice No.', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _dateController,
                decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
                readOnly: true,
                onTap: () async {
                  final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (date != null) {
                    _dateController.text = DateFormat('dd/MM/yyyy').format(date);
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
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Customer Details', style: TextStyle(fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: () => _showAddCustomerDialog(context, profile?.id ?? ''),
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: const Text('New Customer'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                  decoration: const InputDecoration(
                    hintText: 'Search or Select Customer',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                );
              },
              suggestionsCallback: (pattern) async {
                final customers = await ref.read(businessRepoProvider).getCustomers(profile!.id);
                return customers.where((c) => c.customerName.toLowerCase().contains(pattern.toLowerCase())).toList();
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
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_selectedCustomer!.customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('Mob: ${_selectedCustomer!.mobile ?? 'N/A'} | City: ${_selectedCustomer!.city ?? 'N/A'}'),
                        ],
                      ),
                    ),
                    IconButton(onPressed: () => setState(() => _selectedCustomer = null), icon: const Icon(Icons.close, size: 20)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAddCustomerDialog(BuildContext context, String shopId) {
    if (shopId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile not loaded. Please try again.')),
      );
      return;
    }

    final nameController = TextEditingController();
    final mobileController = TextEditingController();
    final cityController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.person_add_alt_1, color: Colors.blue),
              SizedBox(width: 8),
              Text('Add New Customer'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Customer Name *',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: mobileController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Mobile',
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cityController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'City',
                  prefixIcon: Icon(Icons.location_city_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (nameController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Customer name is required.')),
                        );
                        return;
                      }
                      setDialogState(() => isSaving = true);
                      try {
                        final newCustomer = Customer(
                          id: '',
                          shopId: shopId,
                          customerName: nameController.text.trim(),
                          mobile: mobileController.text.trim().isEmpty ? null : mobileController.text.trim(),
                          city: cityController.text.trim().isEmpty ? null : cityController.text.trim(),
                          createdAt: DateTime.now(),
                        );
                        await ref.read(businessRepoProvider).addCustomer(newCustomer);
                        // Fetch the newly saved customer to auto-select it
                        final customers = await ref.read(businessRepoProvider).getCustomers(shopId);
                        final saved = customers.lastWhere(
                          (c) => c.customerName == newCustomer.customerName,
                          orElse: () => newCustomer,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        setState(() => _selectedCustomer = saved);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${saved.customerName} added & selected!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              child: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save & Select'),
            ),
          ],
        ),
      ),
    );
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final searchCtrl = TextEditingController();
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            // Load products once
            if (isLoading) {
              ref.read(unifiedProductsProvider.future).then((products) {
                setSheetState(() {
                  allProducts = products;
                  filtered = products;
                  isLoading = false;
                });
              }).catchError((e) {
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
                  left: 16, right: 16, top: 16,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                ),
                child: Column(
                  children: [
                    // Handle
                    Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                    const Text('Select Product', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: searchCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search product...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onChanged: (val) {
                        setSheetState(() {
                          filtered = allProducts
                              .where((p) => p.product?.productName.toLowerCase().contains(val.toLowerCase()) ?? false)
                              .toList();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : filtered.isEmpty
                              ? const Center(child: Text('No products found'))
                              : ListView.separated(
                                  controller: scrollController,
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (_, i) {
                                    final shopProduct = filtered[i];
                                    final product = shopProduct.product;
                                    if (product == null) return const SizedBox.shrink();

                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Colors.blue.shade50,
                                        child: Text(
                                          product.productName[0].toUpperCase(),
                                          style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      title: Text(product.productName, style: const TextStyle(fontWeight: FontWeight.w500)),
                                      subtitle: Text(
                                        '${product.brand?.brandName ?? ''} • ${product.category?.categoryName ?? ''} • GST ${shopProduct.gstPercentage.toStringAsFixed(0)}%',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      trailing: shopProduct.customRate > 0 
                                        ? Text('₹${shopProduct.customRate}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                                        : null,
                                      onTap: () {
                                        setState(() {
                                          _items[index] = InvoiceItem(
                                            id: _items[index].id,
                                            invoiceId: '',
                                            productName: product.productName,
                                            quantity: _items[index].quantity,
                                            rate: shopProduct.customRate,
                                            gstPercentage: shopProduct.gstPercentage,
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
    return Card(
      color: Colors.blue.shade900,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildSummaryRow('Subtotal', '₹${_subtotal.toStringAsFixed(2)}'),
            const Divider(color: Colors.white24),
            _buildSummaryRow('GST Total', '₹${_gstTotal.toStringAsFixed(2)}'),
            const Divider(color: Colors.white),
            _buildSummaryRow('GRAND TOTAL', '₹${_grandTotal.toStringAsFixed(2)}', isBold: true),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white, fontSize: isBold ? 18 : 14, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(color: Colors.white, fontSize: isBold ? 22 : 16, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
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
          ? (widget.item.quantity % 1 == 0 ? widget.item.quantity.toInt().toString() : widget.item.quantity.toString())
          : '1',
    );
    _rateController = TextEditingController(
      text: widget.item.rate > 0
          ? (widget.item.rate % 1 == 0 ? widget.item.rate.toInt().toString() : widget.item.rate.toString())
          : '',
    );
    _gstController = TextEditingController(
      text: widget.item.gstPercentage > 0
          ? (widget.item.gstPercentage % 1 == 0 ? widget.item.gstPercentage.toInt().toString() : widget.item.gstPercentage.toString())
          : '0',
    );
  }

  @override
  void didUpdateWidget(covariant _ItemRowWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (double.tryParse(_qtyController.text) != widget.item.quantity) {
      _qtyController.text = widget.item.quantity > 0
          ? (widget.item.quantity % 1 == 0 ? widget.item.quantity.toInt().toString() : widget.item.quantity.toString())
          : '1';
    }
    if (double.tryParse(_rateController.text) != widget.item.rate) {
      _rateController.text = widget.item.rate > 0
          ? (widget.item.rate % 1 == 0 ? widget.item.rate.toInt().toString() : widget.item.rate.toString())
          : '';
    }
    if (double.tryParse(_gstController.text) != widget.item.gstPercentage) {
      _gstController.text = widget.item.gstPercentage > 0
          ? (widget.item.gstPercentage % 1 == 0 ? widget.item.gstPercentage.toInt().toString() : widget.item.gstPercentage.toString())
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
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.grey.shade400)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search, size: 18, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedProductName ?? 'Tap to search product',
                              style: TextStyle(
                                color: selectedProductName != null ? Colors.black87 : Colors.grey,
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
                              child: const Icon(Icons.close, size: 16, color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qtyController,
                    decoration: const InputDecoration(labelText: 'Qty', isDense: true, border: OutlineInputBorder()),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => _notifyChange(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _rateController,
                    decoration: const InputDecoration(labelText: 'Rate (₹)', isDense: true, border: OutlineInputBorder()),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => _notifyChange(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _gstController,
                    decoration: const InputDecoration(labelText: 'GST %', isDense: true, border: OutlineInputBorder()),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
