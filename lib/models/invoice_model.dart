import 'package:invoicehub/models/business_models.dart';

class Invoice {
  final String id;
  final String shopId;
  final String? customerId;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final double subtotal;
  final double gstTotal;
  final double grandTotal;
  final String? notes;
  final String? pdfUrl;
  final DateTime createdAt;
  
  final Customer? customer;
  final List<InvoiceItem>? items;

  Invoice({
    required this.id,
    required this.shopId,
    this.customerId,
    required this.invoiceNumber,
    required this.invoiceDate,
    this.subtotal = 0.0,
    this.gstTotal = 0.0,
    this.grandTotal = 0.0,
    this.notes,
    this.pdfUrl,
    required this.createdAt,
    this.customer,
    this.items,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id'],
      shopId: json['shop_id'],
      customerId: json['customer_id'],
      invoiceNumber: json['invoice_number'],
      invoiceDate: DateTime.parse(json['invoice_date']),
      subtotal: (json['subtotal'] ?? 0.0).toDouble(),
      gstTotal: (json['gst_total'] ?? 0.0).toDouble(),
      grandTotal: (json['grand_total'] ?? 0.0).toDouble(),
      notes: json['notes'],
      pdfUrl: json['pdf_url'],
      createdAt: DateTime.parse(json['created_at']),
      customer: json['customers'] != null 
          ? Customer.fromJson(json['customers']) 
          : null,
      items: json['invoice_items'] != null
          ? (json['invoice_items'] as List)
              .map((i) => InvoiceItem.fromJson(i))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shop_id': shopId,
      'customer_id': customerId,
      'invoice_number': invoiceNumber,
      'invoice_date': invoiceDate.toIso8601String(),
      'subtotal': subtotal,
      'gst_total': gstTotal,
      'grand_total': grandTotal,
      'notes': notes,
      'pdf_url': pdfUrl,
    };
  }
}

class InvoiceItem {
  final String id;
  final String invoiceId;
  final String? productId;
  final String? productName;
  final double quantity;
  final double rate;
  final double gstPercentage;
  final double gstAmount;
  final double totalAmount;

  InvoiceItem({
    required this.id,
    required this.invoiceId,
    this.productId,
    this.productName,
    this.quantity = 0.0,
    this.rate = 0.0,
    this.gstPercentage = 18.0,
    this.gstAmount = 0.0,
    this.totalAmount = 0.0,
  });

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    return InvoiceItem(
      id: json['id'],
      invoiceId: json['invoice_id'],
      productId: json['product_id'],
      productName: json['product_name'],
      quantity: (json['quantity'] ?? 0.0).toDouble(),
      rate: (json['rate'] ?? 0.0).toDouble(),
      gstPercentage: (json['gst_percentage'] ?? 18.0).toDouble(),
      gstAmount: (json['gst_amount'] ?? 0.0).toDouble(),
      totalAmount: (json['total_amount'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'invoice_id': invoiceId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'rate': rate,
      'gst_percentage': gstPercentage,
      'gst_amount': gstAmount,
      'total_amount': totalAmount,
    };
  }
}
