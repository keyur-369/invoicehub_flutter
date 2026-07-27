import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:invoicehub/models/profile.dart';
import 'package:invoicehub/models/business_models.dart';
import 'package:invoicehub/models/invoice_model.dart';

class PdfService {
  static Future<Uint8List> generateInvoicePdf({
    required Profile shop,
    required Customer? customer,
    required Invoice invoice,
    required List<InvoiceItem> items,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            _buildHeader(shop, invoice),
            pw.SizedBox(height: 20),
            _buildInfoSection(shop, customer, invoice),
            pw.SizedBox(height: 20),
            _buildItemsTable(items),
            pw.SizedBox(height: 20),
            _buildTotalSection(invoice),
            pw.Spacer(),
            _buildFooter(shop),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(Profile shop, Invoice invoice) {
    return pw.Column(
      children: [
        pw.Center(
          child: pw.Text(
            '|| Jay Swaminarayan ||',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(shop.shopName ?? 'My Shop', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.Text(shop.address ?? ''),
                if (shop.gstNumber != null)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 5),
                    child: pw.Text(
                      'GSTIN: ${shop.gstNumber}',
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('TAX INVOICE', style: pw.TextStyle(fontSize: 30, color: PdfColors.blue900, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Text('Invoice No: ${invoice.invoiceNumber}'),
                pw.Text('Date: ${DateFormat('dd-MM-yyyy').format(invoice.invoiceDate)}'),
                if (shop.mobile != null) ...[
                  pw.SizedBox(height: 5),
                  pw.Text('Phone: ${shop.mobile}'),
                ],
                if (shop.ownerName != null) ...[
                  pw.SizedBox(height: 2),
                  pw.Text('Owner: ${shop.ownerName}', style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
                ],
              ],
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildInfoSection(Profile shop, Customer? customer, Invoice invoice) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(5),
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                width: double.infinity,
                child: pw.Text('Bill To:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(customer?.customerName ?? 'Walk-in Customer', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(customer?.address ?? ''),
                    pw.Text('GSTIN: ${customer?.gstNumber ?? 'N/A'}'),
                    pw.Text('Phone: ${customer?.mobile ?? ''}'),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 20),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(5),
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                width: double.infinity,
                child: pw.Text('Shipping Details:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(customer?.address ?? 'Same as billing'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildItemsTable(List<InvoiceItem> items) {
    final headers = ['S.No', 'Product Description', 'Qty', 'Rate', 'GST%', 'Total'];

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: List.generate(items.length, (index) {
        final item = items[index];
        final total = (item.quantity * item.rate) * (1 + (item.gstPercentage / 100));
        return [
          '${index + 1}',
          item.productName ?? 'Product',
          '${item.quantity}',
          '${item.rate.toStringAsFixed(2)}',
          '${item.gstPercentage}%',
          total.toStringAsFixed(2),
        ];
      }),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
      cellHeight: 30,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
      },
    );
  }

  static pw.Widget _buildTotalSection(Invoice invoice) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            _buildTotalRow('Subtotal:', '₹${invoice.subtotal.toStringAsFixed(2)}'),
            _buildTotalRow('GST Total:', '₹${invoice.gstTotal.toStringAsFixed(2)}'),
            pw.Divider(color: PdfColors.grey),
            _buildTotalRow('Grand Total:', '₹${invoice.grandTotal.toStringAsFixed(2)}', isBold: true),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildTotalRow(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(label, style: pw.TextStyle(fontWeight: isBold ? pw.FontWeight.bold : null)),
          pw.SizedBox(width: 20),
          pw.Container(
            width: 100,
            alignment: pw.Alignment.centerRight,
            child: pw.Text(value, style: pw.TextStyle(fontWeight: isBold ? pw.FontWeight.bold : null)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(Profile shop) {
    return pw.Column(
      children: [
        pw.Divider(),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Terms & Conditions:'),
                pw.Text('1. Goods once sold will not be taken back.', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('2. Subject to ${shop.city ?? 'Local'} Jurisdiction.', style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.SizedBox(height: 40),
                pw.Text('For ${shop.shopName ?? 'My Shop'}'),
                pw.SizedBox(height: 10),
                pw.Text('(Authorised Signatory)', style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
