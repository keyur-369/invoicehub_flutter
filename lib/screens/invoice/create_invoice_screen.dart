import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:invoicehub/models/business_models.dart';
import 'package:invoicehub/models/invoice_model.dart';
import 'package:invoicehub/providers/auth_provider.dart';
import 'package:invoicehub/repositories/business_repository.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:uuid/uuid.dart';

final businessRepoProvider = Provider((ref) => BusinessRepository());

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
        gstPercentage: 18,
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
    final profile = ref.watch(profileProvider).value;

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
            ElevatedButton(
              onPressed: () {
                // Implement save and PDF generation
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('GENERATE INVOICE & PDF', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
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
            const Text('Customer Details', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildItemsList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _buildItemRow(index);
      },
    );
  }

  Widget _buildItemRow(int index) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    decoration: const InputDecoration(hintText: 'Product Name', isDense: true),
                    onChanged: (v) {
                      _items[index] = InvoiceItem(
                        id: _items[index].id,
                        invoiceId: '',
                        productName: v,
                        quantity: _items[index].quantity,
                        rate: _items[index].rate,
                        gstPercentage: _items[index].gstPercentage,
                      );
                    },
                  ),
                ),
                IconButton(onPressed: () => _removeItem(index), icon: const Icon(Icons.delete_outline, color: Colors.red)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(labelText: 'Qty', isDense: true),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final qty = double.tryParse(v) ?? 0;
                      setState(() {
                        _items[index] = InvoiceItem(
                          id: _items[index].id,
                          invoiceId: '',
                          productName: _items[index].productName,
                          quantity: qty,
                          rate: _items[index].rate,
                          gstPercentage: _items[index].gstPercentage,
                        );
                        _calculateTotals();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(labelText: 'Rate', isDense: true),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final rate = double.tryParse(v) ?? 0;
                      setState(() {
                        _items[index] = InvoiceItem(
                          id: _items[index].id,
                          invoiceId: '',
                          productName: _items[index].productName,
                          quantity: _items[index].quantity,
                          rate: rate,
                          gstPercentage: _items[index].gstPercentage,
                        );
                        _calculateTotals();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(labelText: 'GST %', isDense: true),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final gst = double.tryParse(v) ?? 18;
                      setState(() {
                        _items[index] = InvoiceItem(
                          id: _items[index].id,
                          invoiceId: '',
                          productName: _items[index].productName,
                          quantity: _items[index].quantity,
                          rate: _items[index].rate,
                          gstPercentage: gst,
                        );
                        _calculateTotals();
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
