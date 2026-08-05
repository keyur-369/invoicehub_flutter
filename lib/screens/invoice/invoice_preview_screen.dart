import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:invoicehub/models/business_models.dart';
import 'package:invoicehub/models/invoice_model.dart';
import 'package:invoicehub/models/profile.dart';
import 'package:invoicehub/services/pdf_service.dart';
import 'package:invoicehub/services/ad_helper.dart';

class InvoicePreviewScreen extends StatefulWidget {
  final String invoiceNumber;
  final DateTime invoiceDate;
  final Customer? customer;
  final List<InvoiceItem> items;
  final double subtotal;
  final double gstTotal;
  final double grandTotal;
  final Profile shopProfile;

  const InvoicePreviewScreen({
    super.key,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.customer,
    required this.items,
    required this.subtotal,
    required this.gstTotal,
    required this.grandTotal,
    required this.shopProfile,
  });

  @override
  State<InvoicePreviewScreen> createState() => _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends State<InvoicePreviewScreen> {
  bool _isGenerating = false;

  /// Downloads a network image (e.g. the shop's saved signature) as bytes so
  /// it can be embedded directly into the PDF as a real image object.
  Future<Uint8List?> _fetchImageBytes(String url) async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      final bytes = await consolidateHttpClientResponseBytes(response);
      client.close();
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Future<void> _generateAndSharePdf() async {
    setState(() => _isGenerating = true);
    try {
      final invoice = Invoice(
        id: '',
        shopId: widget.shopProfile.id,
        invoiceNumber: widget.invoiceNumber,
        invoiceDate: widget.invoiceDate,
        subtotal: widget.subtotal,
        gstTotal: widget.gstTotal,
        grandTotal: widget.grandTotal,
        createdAt: DateTime.now(),
      );

      Uint8List? signatureBytes;
      if (widget.shopProfile.signatureUrl != null) {
        signatureBytes = await _fetchImageBytes(
          widget.shopProfile.signatureUrl!,
        );
      }

      // Printing.layoutPdf opens the native print/share sheet and re-builds
      // the PDF for whatever page format that sheet actually needs (A4,
      // Letter, a specific printer's paper size, etc.) — this is what
      // guarantees a properly sized, professional, print-ready document
      // instead of a stretched screenshot of the phone UI.
      await Printing.layoutPdf(
        name: '${widget.invoiceNumber}.pdf',
        onLayout: (PdfPageFormat format) => PdfService.generateInvoicePdf(
          shop: widget.shopProfile,
          customer: widget.customer,
          invoice: invoice,
          items: widget.items,
          signatureBytes: signatureBytes,
          format: format,
        ),
      );

      // Show full-screen interstitial ad after printing/sharing PDF
      AdHelper.loadAndShowInterstitialAd();
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEEEEE),
      appBar: AppBar(
        title: const Text('Invoice Preview'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          _isGenerating
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.share_outlined),
                  onPressed: _generateAndSharePdf,
                  tooltip: 'Print / Share PDF',
                ),
        ],
      ),
      body: PdfPreview(
        build: (format) => PdfService.generateInvoicePdf(
          shop: widget.shopProfile,
          customer: widget.customer,
          invoice: Invoice(
            id: '',
            shopId: widget.shopProfile.id,
            invoiceNumber: widget.invoiceNumber,
            invoiceDate: widget.invoiceDate,
            subtotal: widget.subtotal,
            gstTotal: widget.gstTotal,
            grandTotal: widget.grandTotal,
            createdAt: DateTime.now(),
          ),
          items: widget.items,
          format: format,
        ),
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
        pdfFileName: '${widget.invoiceNumber}.pdf',
      ),
    );
  }
}

// ─── Invoice Card (preview + what gets captured for PDF) ─────────────────────

class _InvoiceCard extends StatelessWidget {
  final String invoiceNumber;
  final DateTime invoiceDate;
  final Customer? customer;
  final List<InvoiceItem> items;
  final double subtotal;
  final double gstTotal;
  final double grandTotal;
  final Profile shopProfile;

  const _InvoiceCard({
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.customer,
    required this.items,
    required this.subtotal,
    required this.gstTotal,
    required this.grandTotal,
    required this.shopProfile,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Indigo gradient header ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo.shade800, Colors.indigo.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            child: Column(
              children: [
                const Text(
                  '|| Jay Swaminarayan ||',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shopProfile.shopName ?? 'Your Business',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (shopProfile.address != null)
                            Text(
                              shopProfile.address!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          if (shopProfile.city != null)
                            Text(
                              shopProfile.city!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          if (shopProfile.gstNumber != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'GSTIN: ${shopProfile.gstNumber}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.white38),
                          ),
                          child: const Text(
                            'TAX INVOICE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          invoiceNumber,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('dd MMM yyyy').format(invoiceDate),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                        if (shopProfile.mobile != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            '📞 ${shopProfile.mobile}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        if (shopProfile.ownerName != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Owner: ${shopProfile.ownerName}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Bill To ────────────────────────────────────────────────────────
          if (customer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade700,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'BILL TO',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        customer!.customerName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (customer!.mobile != null || customer!.city != null)
                        Text(
                          [
                            if (customer!.mobile != null)
                              '📞 ${customer!.mobile}',
                            if (customer!.city != null) '📍 ${customer!.city}',
                          ].join('   '),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),
          const Divider(height: 1, indent: 20, endIndent: 20),

          // ── Items table ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                // Table header
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade700,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          '#',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          'Product',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 32,
                        child: Text(
                          'Qty',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        child: Text(
                          'Rate',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 36,
                        child: Text(
                          'GST',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 64,
                        child: Text(
                          'Total',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Item rows
                ...items.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  final base = item.quantity * item.rate;
                  final gstAmt = base * (item.gstPercentage / 100);
                  final total = base + gstAmt;
                  final isEven = i % 2 == 0;

                  String fmt(double v) => '₹${v.toStringAsFixed(2)}';

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 9,
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isEven
                          ? Colors.white
                          : Colors.indigo.shade50.withValues(alpha: 0.5),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 24,
                          child: Text(
                            '${i + 1}.',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black45,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Text(
                            item.productName ?? '-',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(
                          width: 32,
                          child: Text(
                            item.quantity.toStringAsFixed(
                              item.quantity % 1 == 0 ? 0 : 2,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        SizedBox(
                          width: 60,
                          child: Text(
                            fmt(item.rate),
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        SizedBox(
                          width: 36,
                          child: Text(
                            '${item.gstPercentage.toStringAsFixed(0)}%',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 64,
                          child: Text(
                            fmt(total),
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                // Bottom border
                Container(
                  height: 1,
                  color: Colors.indigo.shade100,
                  margin: const EdgeInsets.only(top: 4),
                ),
              ],
            ),
          ),

          const Divider(height: 1, indent: 20, endIndent: 20),

          // ── Totals ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  width: 240,
                  child: Column(
                    children: [
                      _TotalRow(
                        label: 'Subtotal',
                        value: currency.format(subtotal),
                      ),
                      const SizedBox(height: 4),
                      _TotalRow(
                        label: 'GST Total',
                        value: currency.format(gstTotal),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1),
                      ),
                      _TotalRow(
                        label: 'GRAND TOTAL',
                        value: currency.format(grandTotal),
                        isBold: true,
                        valueColor: Colors.indigo.shade700,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Footer ─────────────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Terms & Conditions',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '• Goods once sold will not be taken back.',
                  style: TextStyle(fontSize: 10, color: Colors.black45),
                ),
                const Text(
                  '• Payment due within 30 days of invoice date.',
                  style: TextStyle(fontSize: 10, color: Colors.black45),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Customer Signature',
                          style: TextStyle(fontSize: 10, color: Colors.black45),
                        ),
                        const SizedBox(height: 20),
                        Container(width: 100, height: 1, color: Colors.black26),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'For ${shopProfile.shopName ?? 'Business'}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black45,
                          ),
                        ),
                        if (shopProfile.signatureUrl != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Image.network(
                              shopProfile.signatureUrl!,
                              height: 45,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const SizedBox(height: 45),
                            ),
                          )
                        else
                          const SizedBox(height: 45),
                        Container(width: 120, height: 1, color: Colors.black26),
                        const SizedBox(height: 4),
                        const Text(
                          'Authorised Signatory',
                          style: TextStyle(fontSize: 9, color: Colors.black38),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Branding footer bar ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.indigo.shade700,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: const Center(
              child: Text(
                'Generated by InvoiceHub',
                style: TextStyle(color: Colors.white60, fontSize: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helper widget ────────────────────────────────────────────────────────────

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? valueColor;

  const _TotalRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 14 : 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: Colors.black54,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}
