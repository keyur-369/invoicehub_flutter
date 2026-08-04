import 'package:invoicehub/models/business_models.dart';

class KhataTransaction {
  final String id;
  final String shopId;
  final String customerId;
  final String? invoiceId;
  final String transactionType; // 'GAVE' (Credit/Udhar) or 'GOT' (Debit/Payment)
  final double amount;
  final String paymentMode; // 'CASH', 'UPI', 'BANK_TRANSFER', 'CHEQUE', 'INVOICE'
  final DateTime transactionDate;
  final String? notes;
  final String? billImageUrl;
  final String? referenceNo; // For UPI Txn ID, Cheque No, or manual Invoice No
  final DateTime createdAt;

  // Relation fields
  final Customer? customer;
  final String? invoiceNumber;

  KhataTransaction({
    required this.id,
    required this.shopId,
    required this.customerId,
    this.invoiceId,
    required this.transactionType,
    required this.amount,
    this.paymentMode = 'CASH',
    required this.transactionDate,
    this.notes,
    this.billImageUrl,
    this.referenceNo,
    required this.createdAt,
    this.customer,
    this.invoiceNumber,
  });

  bool get isGave => transactionType.toUpperCase() == 'GAVE';
  bool get isGot => transactionType.toUpperCase() == 'GOT';

  factory KhataTransaction.fromJson(Map<String, dynamic> json) {
    return KhataTransaction(
      id: json['id']?.toString() ?? '',
      shopId: json['shop_id']?.toString() ?? '',
      customerId: json['customer_id']?.toString() ?? '',
      invoiceId: json['invoice_id']?.toString(),
      transactionType: json['transaction_type']?.toString().toUpperCase() ?? 'GAVE',
      amount: (json['amount'] ?? 0.0).toDouble(),
      paymentMode: json['payment_mode']?.toString() ?? 'CASH',
      transactionDate: json['transaction_date'] != null
          ? DateTime.parse(json['transaction_date'])
          : DateTime.now(),
      notes: json['notes']?.toString(),
      billImageUrl: json['bill_image_url']?.toString(),
      referenceNo: json['reference_no']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      customer: json['customers'] != null
          ? (json['customers'] is List
              ? (json['customers'] as List).isNotEmpty
                  ? Customer.fromJson(json['customers'][0])
                  : null
              : Customer.fromJson(json['customers']))
          : null,
      invoiceNumber: json['invoices'] != null
          ? (json['invoices'] is List
              ? (json['invoices'] as List).isNotEmpty
                  ? json['invoices'][0]['invoice_number']?.toString()
                  : null
              : json['invoices']['invoice_number']?.toString())
          : (json['reference_no']?.toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shop_id': shopId,
      'customer_id': customerId,
      if (invoiceId != null && invoiceId!.isNotEmpty) 'invoice_id': invoiceId,
      'transaction_type': transactionType,
      'amount': amount,
      'payment_mode': paymentMode,
      'transaction_date': transactionDate.toIso8601String(),
      if (notes != null) 'notes': notes,
      if (billImageUrl != null) 'bill_image_url': billImageUrl,
      if (referenceNo != null && referenceNo!.isNotEmpty) 'reference_no': referenceNo,
    };
  }
}

class CustomerKhataSummary {
  final Customer customer;
  final double totalGave; // Sum of Udhar / Credit
  final double totalGot;  // Sum of Payments / Debit
  final DateTime? lastTransactionDate;

  CustomerKhataSummary({
    required this.customer,
    this.totalGave = 0.0,
    this.totalGot = 0.0,
    this.lastTransactionDate,
  });

  /// Net balance calculation:
  /// > 0: Customer owes money to shop (YOU WILL GET / Aapko Milenge - Red)
  /// < 0: Shop owes money to customer (YOU WILL GIVE / Aapne Dene Hain - Green)
  /// == 0: Fully Settled
  double get netBalance => totalGave - totalGot;

  bool get customerOwesMe => netBalance > 0.01;
  bool get iOweCustomer => netBalance < -0.01;
  bool get isSettled => netBalance.abs() <= 0.01;
}
