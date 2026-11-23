import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'api_service.dart';

class PdfService {
  static final _inr = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 0);

  static Future<void> _openPreview({
    required BuildContext? context,
    required String title,
    required String fileName,
    required Future<Uint8List> Function(PdfPageFormat format) builder,
  }) async {
    if (context != null && context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            body: PdfPreview(
              build: builder,
              initialPageFormat: PdfPageFormat.a4,
              pdfFileName: fileName,
              canChangeOrientation: false,
              canDebug: false,
              allowPrinting: true,
              allowSharing: true,
              pageFormats: const {
                'A4': PdfPageFormat.a4,
                'A5': PdfPageFormat.a5,
                '80mm Receipt': PdfPageFormat.roll80,
              },
            ),
          ),
        ),
      );
    } else {
      await Printing.layoutPdf(format: PdfPageFormat.a4, name: fileName, onLayout: builder);
    }
  }

  static Future<pw.MemoryImage?> _loadNetworkImage(String? path) async {
    if (path == null || path.isEmpty) return null;
    try {
      final url = ApiService.instance.mediaUrl(path);
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        return pw.MemoryImage(res.bodyBytes);
      }
    } catch (_) {}
    return null;
  }

  static Future<pw.MemoryImage?> _loadAssetLogo() async {
    try {
      final data = await rootBundle.load('assets/images/app_logo.png');
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  /// 1. Customer Copy PDF: Includes final design preview, full specs, pricing,
  /// payment summary (Total, Advance, Balance), and expected delivery date.
  static Future<void> printCustomerCopy(Map<String, dynamic> order, {BuildContext? context}) async {
    final designImg = await _loadNetworkImage(order['ai_output_image_url']?.toString());
    final logoImg = await _loadAssetLogo();

    await _openPreview(
      context: context,
      title: 'Customer Copy - ${order['job_id'] ?? ''}',
      fileName: 'Customer_Copy_${order['job_id']}.pdf',
      builder: (PdfPageFormat pageFormat) async {
        final doc = pw.Document();
        final isNarrow = pageFormat.width < 420;
        final margin = isNarrow ? 10.0 : 26.0;
        final contentWidth = (pageFormat.width - margin * 2).clamp(160.0, 800.0);

        doc.addPage(
          pw.MultiPage(
            pageFormat: pageFormat,
            margin: pw.EdgeInsets.all(margin),
            build: (context) => [
              // Header Banner
              pw.Container(
                width: double.infinity,
                padding: pw.EdgeInsets.all(isNarrow ? 10 : 14),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#3B210E'),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: isNarrow
                    ? pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            children: [
                              if (logoImg != null) ...[
                                pw.Container(
                                  width: 28,
                                  height: 28,
                                  padding: const pw.EdgeInsets.all(2),
                                  decoration: pw.BoxDecoration(
                                    color: PdfColors.white,
                                    borderRadius: pw.BorderRadius.circular(6),
                                  ),
                                  child: pw.Image(logoImg, fit: pw.BoxFit.contain),
                                ),
                                pw.SizedBox(width: 8),
                              ],
                              pw.Expanded(
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text('WOODCRAFT CUSTOMIZER',
                                        style: pw.TextStyle(
                                            color: PdfColors.white, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                                    pw.Text('CUSTOMER ORDER COPY & ESTIMATE',
                                        style: pw.TextStyle(color: PdfColor.fromHex('#D4AF37'), fontSize: 8)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 6),
                          pw.Text('Job ID: ${order['job_id'] ?? ''}',
                              style: pw.TextStyle(
                                  color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          pw.Text('Delivery: ${order['expected_delivery_date'] ?? ''}',
                              style: const pw.TextStyle(color: PdfColors.white, fontSize: 9)),
                        ],
                      )
                    : pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Expanded(
                            child: pw.Row(
                              children: [
                                if (logoImg != null) ...[
                                  pw.Container(
                                    width: 36,
                                    height: 36,
                                    padding: const pw.EdgeInsets.all(2),
                                    decoration: pw.BoxDecoration(
                                      color: PdfColors.white,
                                      borderRadius: pw.BorderRadius.circular(6),
                                    ),
                                    child: pw.Image(logoImg, fit: pw.BoxFit.contain),
                                  ),
                                  pw.SizedBox(width: 10),
                                ],
                                pw.Expanded(
                                  child: pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Text('WOODEN DOOR & FRAME CUSTOMIZER',
                                          style: pw.TextStyle(
                                              color: PdfColors.white, fontSize: 14, fontWeight: pw.FontWeight.bold)),
                                      pw.Text('CUSTOMER ORDER COPY & ESTIMATE',
                                          style: pw.TextStyle(color: PdfColor.fromHex('#D4AF37'), fontSize: 9.5)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          pw.SizedBox(width: 10),
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text('Job ID: ${order['job_id'] ?? ''}',
                                  style: pw.TextStyle(
                                      color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11.5)),
                              pw.Text('Delivery: ${order['expected_delivery_date'] ?? ''}',
                                  style: const pw.TextStyle(color: PdfColors.white, fontSize: 9.5)),
                            ],
                          ),
                        ],
                      ),
              ),
              pw.SizedBox(height: isNarrow ? 10 : 14),

              // Customer Details
              pw.Container(
                width: double.infinity,
                padding: pw.EdgeInsets.all(isNarrow ? 9 : 12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('CUSTOMER DETAILS',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: isNarrow ? 9.5 : 11)),
                    pw.SizedBox(height: 5),
                    pw.Text('Name: ${order['customer_name'] ?? ''}',
                        style: pw.TextStyle(fontSize: isNarrow ? 9 : 10.5)),
                    pw.Text('Mobile: ${order['customer_mobile'] ?? ''}',
                        style: pw.TextStyle(fontSize: isNarrow ? 9 : 10.5)),
                    pw.Text('Delivery Address: ${order['customer_address'] ?? order['delivery_address'] ?? '-'}',
                        style: pw.TextStyle(fontSize: isNarrow ? 9 : 10.5)),
                  ],
                ),
              ),
              pw.SizedBox(height: isNarrow ? 10 : 14),

              // Design Image + Specs (side-by-side on A4, stacked cleanly on narrow paper)
              if (isNarrow) ...[
                if (designImg != null) ...[
                  pw.Center(
                    child: pw.Container(
                      width: (contentWidth * 0.78).clamp(110.0, 200.0),
                      height: (contentWidth * 1.04).clamp(150.0, 265.0),
                      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
                      child: pw.Image(designImg, fit: pw.BoxFit.cover),
                    ),
                  ),
                  pw.SizedBox(height: 10),
                ],
                pw.Text('DOOR & WOODWORK SPECIFICATIONS',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                pw.SizedBox(height: 6),
                ..._customerSpecRows(order, compact: true),
              ] else
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (designImg != null)
                      pw.Container(
                        width: 170,
                        height: 235,
                        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
                        child: pw.Image(designImg, fit: pw.BoxFit.cover),
                      ),
                    if (designImg != null) pw.SizedBox(width: 16),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('DOOR & WOODWORK SPECIFICATIONS',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                          pw.SizedBox(height: 8),
                          ..._customerSpecRows(order, compact: false),
                        ],
                      ),
                    ),
                  ],
                ),
              pw.SizedBox(height: isNarrow ? 12 : 16),

              // Payment Summary
              pw.Container(
                width: double.infinity,
                padding: pw.EdgeInsets.all(isNarrow ? 10 : 14),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F8F5F0'),
                  border: pw.Border.all(color: PdfColor.fromHex('#6B3E1D')),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Text('Total Order Amount',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: isNarrow ? 9.5 : 12)),
                        ),
                        pw.Text(_inr.format(double.tryParse('${order['total_cost']}') ?? 0),
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: isNarrow ? 10 : 13)),
                      ],
                    ),
                    pw.SizedBox(height: 5),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Text('Advance Paid', style: pw.TextStyle(fontSize: isNarrow ? 9 : 11)),
                        ),
                        pw.Text(_inr.format(double.tryParse('${order['advance_amount']}') ?? 0),
                            style: pw.TextStyle(fontSize: isNarrow ? 9 : 11)),
                      ],
                    ),
                    pw.Divider(),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Text('Balance Payable on Delivery',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.red800,
                                  fontSize: isNarrow ? 9.5 : 11.5)),
                        ),
                        pw.Text(_inr.format(double.tryParse('${order['balance_amount']}') ?? 0),
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.red800,
                                fontSize: isNarrow ? 10 : 13)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),
              pw.Text(
                'Track your live production progress in the Customer App using your registered mobile number.',
                style: pw.TextStyle(fontSize: isNarrow ? 8 : 9, color: PdfColors.grey700),
              ),
            ],
          ),
        );

        final Uint8List bytes = await doc.save();
        return bytes;
      },
    );
  }

  /// 2. Workshop Job Sheet PDF (Privacy-Protected):
  /// Includes ONLY Job ID, QR Code, Final Output Design, Reference Images, Dimensions,
  /// Woodwork Specs, Workshop Notes, and Target Delivery Date.
  /// STRICTLY EXCLUDES Customer Name, Mobile, Address, and Pricing!
  static Future<void> printWorkshopJobSheet(Map<String, dynamic> job, {BuildContext? context}) async {
    final designImg = await _loadNetworkImage(job['ai_output_image_url']?.toString());
    final logoImg = await _loadAssetLogo();

    final refList = (job['reference_designs'] as List?) ?? [];
    final refImgs = <pw.MemoryImage>[];
    for (final r in refList.take(3)) {
      final img = await _loadNetworkImage(r['image_url']?.toString());
      if (img != null) refImgs.add(img);
    }

    await _openPreview(
      context: context,
      title: 'Workshop Sheet - ${job['job_id'] ?? ''}',
      fileName: 'Workshop_Job_Sheet_${job['job_id']}.pdf',
      builder: (PdfPageFormat pageFormat) async {
        final doc = pw.Document();
        final isNarrow = pageFormat.width < 420;
        final margin = isNarrow ? 10.0 : 24.0;
        final contentWidth = (pageFormat.width - margin * 2).clamp(160.0, 800.0);

        doc.addPage(
          pw.MultiPage(
            pageFormat: pageFormat,
            margin: pw.EdgeInsets.all(margin),
            build: (context) => [
              pw.Container(
                width: double.infinity,
                padding: pw.EdgeInsets.all(isNarrow ? 10 : 14),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#261B12'),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Expanded(
                      child: pw.Row(
                        children: [
                          if (logoImg != null) ...[
                            pw.Container(
                              width: isNarrow ? 26 : 34,
                              height: isNarrow ? 26 : 34,
                              padding: const pw.EdgeInsets.all(2),
                              decoration: pw.BoxDecoration(
                                color: PdfColors.white,
                                borderRadius: pw.BorderRadius.circular(6),
                              ),
                              child: pw.Image(logoImg, fit: pw.BoxFit.contain),
                            ),
                            pw.SizedBox(width: 8),
                          ],
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('WORKSHOP TECHNICAL JOB SHEET',
                                    style: pw.TextStyle(
                                        color: PdfColors.white,
                                        fontSize: isNarrow ? 11 : 15,
                                        fontWeight: pw.FontWeight.bold)),
                                pw.Text('PRODUCTION COPY - TECHNICAL SPECS ONLY',
                                    style: pw.TextStyle(
                                        color: PdfColor.fromHex('#D4AF37'), fontSize: isNarrow ? 7.5 : 9.5)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: '${job['job_id'] ?? ''}',
                      width: isNarrow ? 42 : 52,
                      height: isNarrow ? 42 : 52,
                      color: PdfColors.white,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),

              pw.Wrap(
                spacing: 12,
                runSpacing: 4,
                alignment: pw.WrapAlignment.spaceBetween,
                children: [
                  pw.Text('JOB ID: ${job['job_id'] ?? ''}',
                      style: pw.TextStyle(fontSize: isNarrow ? 11 : 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text('TARGET DELIVERY: ${job['expected_delivery_date'] ?? ''} (${job['priority'] ?? 'Normal'})',
                      style: pw.TextStyle(
                          fontSize: isNarrow ? 9.5 : 11.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red800)),
                ],
              ),
              pw.Divider(),
              pw.SizedBox(height: 8),

              if (isNarrow) ...[
                if (designImg != null) ...[
                  pw.Center(
                    child: pw.Container(
                      width: (contentWidth * 0.80).clamp(110.0, 200.0),
                      height: (contentWidth * 1.06).clamp(150.0, 265.0),
                      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1.5)),
                      child: pw.Image(designImg, fit: pw.BoxFit.cover),
                    ),
                  ),
                  pw.SizedBox(height: 10),
                ],
                pw.Text('TECHNICAL MEASUREMENTS & SPECS',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                pw.SizedBox(height: 6),
                ..._workshopSpecRows(job, compact: true),
              ] else
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (designImg != null)
                      pw.Container(
                        width: 185,
                        height: 255,
                        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1.5)),
                        child: pw.Image(designImg, fit: pw.BoxFit.cover),
                      ),
                    if (designImg != null) pw.SizedBox(width: 16),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('TECHNICAL MEASUREMENTS & SPECS',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11.5)),
                          pw.SizedBox(height: 8),
                          ..._workshopSpecRows(job, compact: false),
                        ],
                      ),
                    ),
                  ],
                ),
              pw.SizedBox(height: 12),

              if ((job['workshop_notes'] ?? '').toString().isNotEmpty)
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.amber50,
                    border: pw.Border.all(color: PdfColors.amber700),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('WORKSHOP NOTES:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: isNarrow ? 9 : 10)),
                      pw.SizedBox(height: 4),
                      pw.Text('${job['workshop_notes']}', style: pw.TextStyle(fontSize: isNarrow ? 8.5 : 10)),
                    ],
                  ),
                ),

              if (refImgs.isNotEmpty) ...[
                pw.SizedBox(height: 12),
                pw.Text('SOURCE REFERENCE DESIGNS',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: isNarrow ? 9.5 : 11)),
                pw.SizedBox(height: 8),
                pw.Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: refImgs
                      .map((img) => pw.Container(
                            width: isNarrow ? 64 : 88,
                            height: isNarrow ? 86 : 120,
                            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
                            child: pw.Image(img, fit: pw.BoxFit.cover),
                          ))
                      .toList(),
                ),
              ],
              pw.SizedBox(height: 14),
              pw.Text(
                'Scan the QR code in the Production Team App to update workshop stage.',
                style: pw.TextStyle(fontSize: isNarrow ? 8 : 9, color: PdfColors.grey700),
              ),
            ],
          ),
        );

        final Uint8List bytes = await doc.save();
        return bytes;
      },
    );
  }

  static List<pw.Widget> _customerSpecRows(Map<String, dynamic> order, {required bool compact}) => [
        _specRow('Category', '${order['woodwork_category'] ?? ''}', compact: compact),
        _specRow('Dimensions', '${order['width_inches']}" W x ${order['height_inches']}" H', compact: compact),
        _specRow('Frame Section', '${order['frame_section'] ?? ''}', compact: compact),
        _specRow('Door Thickness', '${order['door_thickness'] ?? ''}', compact: compact),
        _specRow('Leaf Type', '${order['leaf_type'] ?? ''}', compact: compact),
        _specRow('Wood Species', '${order['wood_species'] ?? ''}', compact: compact),
        _specRow('Carving Pattern', '${order['carving_pattern'] ?? '-'}', compact: compact),
        _specRow('Polish Shade', '${order['polish_shade'] ?? ''}', compact: compact),
        _specRow('Hardware', '${order['hardware'] ?? '-'}', compact: compact),
        _specRow('Quantity', '${order['quantity'] ?? 1}', compact: compact),
      ];

  static List<pw.Widget> _workshopSpecRows(Map<String, dynamic> job, {required bool compact}) => [
        _specRow('Woodwork Type', '${job['woodwork_category'] ?? ''}', compact: compact),
        _specRow('Exact Width', '${job['width_inches']} inches', compact: compact),
        _specRow('Exact Height', '${job['height_inches']} inches', compact: compact),
        _specRow('Frame Section', '${job['frame_section'] ?? ''}', compact: compact),
        _specRow('Door Thickness', '${job['door_thickness'] ?? ''}', compact: compact),
        _specRow('Leaf Type', '${job['leaf_type'] ?? ''}', compact: compact),
        _specRow('Wood Species', '${job['wood_species'] ?? ''}', compact: compact),
        _specRow('Carving Pattern', '${job['carving_pattern'] ?? '-'}', compact: compact),
        _specRow('Color / Polish', '${job['polish_shade'] ?? ''}', compact: compact),
        _specRow('Hardware Cutouts', '${job['hardware'] ?? '-'}', compact: compact),
        _specRow('Quantity', '${job['quantity'] ?? 1} Unit(s)', compact: compact),
      ];

  static pw.Widget _specRow(String label, String value, {bool compact = false}) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: compact ? 3.5 : 5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: compact ? 82 : 108,
            child: pw.Text('$label:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: compact ? 8.5 : 10)),
          ),
          pw.Expanded(child: pw.Text(value, style: pw.TextStyle(fontSize: compact ? 8.5 : 10))),
        ],
      ),
    );
  }
}
