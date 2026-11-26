import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../widgets/door_pictorial_guide.dart';
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
      context: context != null && context.mounted ? context : null,
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
                                  width: 60,
                                  height: 24,
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: pw.BoxDecoration(
                                    color: PdfColors.white,
                                    borderRadius: pw.BorderRadius.circular(5),
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
                                    width: 82,
                                    height: 32,
                                    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
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
                      padding: const pw.EdgeInsets.all(4),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        border: pw.Border.all(color: PdfColors.grey400),
                      ),
                      child: pw.Image(designImg, fit: pw.BoxFit.contain),
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
                        padding: const pw.EdgeInsets.all(4),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          border: pw.Border.all(color: PdfColors.grey400),
                        ),
                        child: pw.Image(designImg, fit: pw.BoxFit.contain),
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
  /// Includes ONLY Job ID, QR Code, Final Output Design, Dimensions, Woodwork Specs,
  /// Workshop Notes, Target Delivery Date, and the 5-Element Section Details Style Source Guide.
  /// STRICTLY EXCLUDES Customer Name, Mobile, Address, and Pricing!
  static Future<void> printWorkshopJobSheet(Map<String, dynamic> job, {BuildContext? context}) async {
    final breakdownItems = _resolveStyleGuideBreakdown(job);
    final refDesigns = (job['reference_designs'] as List?) ?? [];

    final uniqueSourceUrls = <String>{
      for (final item in breakdownItems)
        if (item.designImageUrl.isNotEmpty) item.designImageUrl,
      for (final r in refDesigns)
        if (r is Map && (r['image_url'] ?? '').toString().isNotEmpty) (r['image_url'] ?? '').toString(),
    }.toList();

    final loadedImages = await Future.wait<pw.MemoryImage?>([
      _loadNetworkImage(job['ai_output_image_url']?.toString()),
      _loadAssetLogo(),
      ...uniqueSourceUrls.map(_loadNetworkImage),
    ]);

    final designImg = loadedImages[0];
    final logoImg = loadedImages[1];
    final sourceImages = <String, pw.MemoryImage>{};
    for (int i = 0; i < uniqueSourceUrls.length; i++) {
      final img = loadedImages[i + 2];
      if (img != null) {
        sourceImages[uniqueSourceUrls[i]] = img;
      }
    }

    await _openPreview(
      context: context != null && context.mounted ? context : null,
      title: 'Workshop Sheet - ${job['job_id'] ?? ''}',
      fileName: 'Workshop_Job_Sheet_${job['job_id']}.pdf',
      builder: (PdfPageFormat pageFormat) => buildWorkshopJobSheetPdf(
        job,
        pageFormat: pageFormat,
        designImg: designImg,
        logoImg: logoImg,
        sourceImages: sourceImages,
      ),
    );
  }

  /// Builds the Workshop Technical Job Sheet PDF bytes for any [PdfPageFormat].
  static Future<Uint8List> buildWorkshopJobSheetPdf(
    Map<String, dynamic> job, {
    required PdfPageFormat pageFormat,
    pw.MemoryImage? designImg,
    pw.MemoryImage? logoImg,
    Map<String, pw.MemoryImage> sourceImages = const {},
  }) async {
    final breakdownItems = _resolveStyleGuideBreakdown(job);
    final regions = _resolveStyleGuideRegions(job);

    // Center image for the Style Source Guide: final combined door, or fallback to base source image
    pw.MemoryImage? guideDoorImg = designImg;
    if (guideDoorImg == null && breakdownItems.isNotEmpty) {
      for (final item in breakdownItems) {
        final candidate = sourceImages[item.designImageUrl];
        if (candidate != null) {
          guideDoorImg = candidate;
          break;
        }
      }
    }

    final rawAspect = (job['output_aspect'] as num?)?.toDouble();
    final double doorAspect;
    if (rawAspect != null && rawAspect > 0) {
      doorAspect = rawAspect.clamp(0.45, 1.35);
    } else if (guideDoorImg != null && (guideDoorImg.width ?? 0) > 0 && (guideDoorImg.height ?? 0) > 0) {
      doorAspect = (guideDoorImg.width! / guideDoorImg.height!).clamp(0.45, 1.35);
    } else {
      doorAspect = 0.72;
    }

    final doc = pw.Document();
    final isNarrow = pageFormat.width < 420;
    final margin = isNarrow ? 10.0 : 24.0;
    final contentWidth = (pageFormat.width - margin * 2).clamp(160.0, 800.0);
    final categoryLabel = _sanitizePdfText((job['woodwork_category'] ?? 'Door').toString().trim());

    final pageChildren = <pw.Widget>[
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
                      width: isNarrow ? 58 : 78,
                      height: isNarrow ? 24 : 30,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: pw.BorderRadius.circular(5),
                      ),
                      child: pw.Center(child: pw.Image(logoImg, fit: pw.BoxFit.contain)),
                    ),
                    pw.SizedBox(width: 8),
                  ],
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'WORKSHOP TECHNICAL JOB SHEET',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: isNarrow ? 11 : 15,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'PRODUCTION COPY - TECHNICAL SPECS ONLY',
                          style: pw.TextStyle(
                            color: PdfColor.fromHex('#D4AF37'),
                            fontSize: isNarrow ? 7.5 : 9.5,
                          ),
                        ),
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
      pw.SizedBox(height: 10),

      pw.Wrap(
        spacing: 12,
        runSpacing: 4,
        alignment: pw.WrapAlignment.spaceBetween,
        children: [
          pw.Text(
            'JOB ID: ${_sanitizePdfText('${job['job_id'] ?? ''}')}',
            style: pw.TextStyle(fontSize: isNarrow ? 11 : 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'TARGET DELIVERY: ${_sanitizePdfText('${job['expected_delivery_date'] ?? ''} (${job['priority'] ?? 'Normal'})')}',
            style: pw.TextStyle(
              fontSize: isNarrow ? 9.5 : 11.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.red800,
            ),
          ),
        ],
      ),
      pw.Divider(),
      pw.SizedBox(height: 6),

      if (isNarrow) ...[
        if (designImg != null) ...[
          pw.Center(
            child: pw.Container(
              width: (contentWidth * 0.80).clamp(110.0, 200.0),
              height: (contentWidth * 1.06).clamp(150.0, 265.0),
              padding: const pw.EdgeInsets.all(4),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                border: pw.Border.all(color: PdfColors.black, width: 1.5),
              ),
              child: pw.Center(child: pw.Image(designImg, fit: pw.BoxFit.contain)),
            ),
          ),
          pw.SizedBox(height: 10),
        ],
        pw.Text(
          'TECHNICAL MEASUREMENTS & SPECS',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
        ),
        pw.SizedBox(height: 6),
        ..._workshopSpecRows(job, compact: true),
      ] else
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (designImg != null)
              pw.Container(
                width: 185,
                height: 248,
                padding: const pw.EdgeInsets.all(4),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  border: pw.Border.all(color: PdfColors.black, width: 1.5),
                ),
                child: pw.Center(child: pw.Image(designImg, fit: pw.BoxFit.contain)),
              ),
            if (designImg != null) pw.SizedBox(width: 16),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'TECHNICAL MEASUREMENTS & SPECS',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11.5),
                  ),
                  pw.SizedBox(height: 7),
                  ..._workshopSpecRows(job, compact: false),
                ],
              ),
            ),
          ],
        ),

      if ((job['workshop_notes'] ?? '').toString().trim().isNotEmpty) ...[
        pw.SizedBox(height: 10),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(9),
          decoration: pw.BoxDecoration(
            color: PdfColors.amber50,
            border: pw.Border.all(color: PdfColors.amber700),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'WORKSHOP NOTES:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: isNarrow ? 9 : 10),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                _sanitizePdfText('${job['workshop_notes']}'),
                style: pw.TextStyle(fontSize: isNarrow ? 8.5 : 9.5),
              ),
            ],
          ),
        ),
      ],

      // Selected Reference Door Photos (clear individual photos of every selected door)
      if (breakdownItems.isNotEmpty) ...[
        pw.SizedBox(height: 10),
        _buildSelectedReferencePhotosSection(
          items: breakdownItems,
          sourceImages: sourceImages,
          contentWidth: contentWidth,
          compact: isNarrow,
        ),
      ],

      // Section Details - Style Source Guide (Pictorial Breakdown of ONLY the selected elements)
      if (breakdownItems.isNotEmpty) ...[
        pw.SizedBox(height: 12),
        if (isNarrow)
          ..._buildStyleSourceGuideCompact(
            category: categoryLabel.isEmpty ? 'Door' : categoryLabel,
            contentWidth: contentWidth,
            doorImg: guideDoorImg,
            doorAspect: doorAspect,
            items: breakdownItems,
            regions: regions,
            sourceImages: sourceImages,
          )
        else
          _buildStyleSourceGuideWide(
            category: categoryLabel.isEmpty ? 'Door' : categoryLabel,
            contentWidth: contentWidth,
            doorImg: guideDoorImg,
            doorAspect: doorAspect,
            items: breakdownItems,
            regions: regions,
            sourceImages: sourceImages,
          ),
      ],

      pw.SizedBox(height: 10),
      pw.Text(
        'Scan the QR code in the Production Team App to update workshop stage.',
        style: pw.TextStyle(fontSize: isNarrow ? 8 : 8.5, color: PdfColors.grey700),
      ),
    ];

    if (pageFormat.height.isFinite) {
      doc.addPage(
        pw.MultiPage(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.all(margin),
          build: (context) => pageChildren,
        ),
      );
    } else {
      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.all(margin),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: pageChildren,
          ),
        ),
      );
    }

    final Uint8List bytes = await doc.save();
    return bytes;
  }

  static String _sanitizePdfText(String input) {
    return input
        .replaceAll('\u2014', '-')
        .replaceAll('\u2013', '-')
        .replaceAll('\u2022', '|')
        .replaceAll('\u00D7', 'x')
        .replaceAll('\u2018', "'")
        .replaceAll('\u2019', "'")
        .replaceAll('\u201C', '"')
        .replaceAll('\u201D', '"')
        .replaceAll('\u20B9', 'Rs. ')
        .replaceAll('\u00A0', ' ');
  }

  static PdfColor _pdfColorForElementKey(String key) {
    switch (key) {
      case 'frame':
        return PdfColor.fromHex('#2563EB'); // 1 Blue
      case 'center':
        return PdfColor.fromHex('#EA580C'); // 2 Orange
      case 'border':
        return PdfColor.fromHex('#9333EA'); // 3 Purple
      case 'crown':
        return PdfColor.fromHex('#DC2626'); // 4 Red
      case 'panel':
        return PdfColor.fromHex('#16A34A'); // 5 Green
      default:
        return PdfColor.fromHex('#2563EB');
    }
  }

  static Map<String, _PdfGuideRect> _resolveStyleGuideRegions(Map<String, dynamic> job) {
    const defaults = <String, _PdfGuideRect>{
      'crown': _PdfGuideRect(0.03, 0.02, 0.94, 0.16),
      'frame': _PdfGuideRect(0.05, 0.17, 0.90, 0.80),
      'panel': _PdfGuideRect(0.16, 0.18, 0.68, 0.77),
      'center': _PdfGuideRect(0.22, 0.24, 0.56, 0.64),
      'border': _PdfGuideRect(0.80, 0.62, 0.09, 0.27),
    };
    final raw = job['element_regions'];
    if (raw is! Map) return defaults;

    final resolved = Map<String, _PdfGuideRect>.from(defaults);
    raw.forEach((key, val) {
      if (val is Map) {
        final x = (val['x'] as num?)?.toDouble();
        final y = (val['y'] as num?)?.toDouble();
        final w = (val['w'] as num?)?.toDouble();
        final h = (val['h'] as num?)?.toDouble();
        if (x != null && y != null && w != null && h != null) {
          resolved[key.toString()] = _PdfGuideRect(x, y, w, h);
        }
      }
    });
    return resolved;
  }

  static List<_PdfElementGuideItem> _resolveStyleGuideBreakdown(Map<String, dynamic> job) {
    final refDesigns = (job['reference_designs'] as List?) ?? [];
    final refElements = (job['reference_elements'] as List?) ?? [];
    final serverBreakdown = job['element_breakdown'];

    final designById = <int, Map<String, dynamic>>{};
    for (final raw in refDesigns) {
      if (raw is Map) {
        final m = Map<String, dynamic>.from(raw);
        final id = int.tryParse('${m['id']}');
        if (id != null) designById[id] = m;
      }
    }

    final serverByKey = <String, Map<String, dynamic>>{};
    if (serverBreakdown is List) {
      for (final raw in serverBreakdown) {
        if (raw is Map) {
          final m = Map<String, dynamic>.from(raw);
          final k = (m['key'] ?? '').toString();
          if (k.isNotEmpty) serverByKey[k] = m;
        }
      }
    }

    final polishShade = _sanitizePdfText(
      (job['polish_shade'] ?? 'Natural Teak Matte').toString().trim(),
    );

    // Priority 1: Strictly map ONLY the elements explicitly selected in reference_elements
    if (refElements.isNotEmpty) {
      final selectedByKey = <String, _PdfElementGuideItem>{};
      for (final raw in refElements) {
        if (raw is! Map) continue;
        final did = int.tryParse('${raw['design_id']}');
        final elLabel = (raw['element'] ?? '').toString().trim();
        if (did == null || elLabel.isEmpty) continue;

        final meta = CombineElementMeta.forLabel(elLabel);
        final d = designById[did];
        final srv = serverByKey[meta.key];
        final srvMatches = srv != null && int.tryParse('${srv['design_id']}') == did;

        final defaultDesc = meta.key == 'border'
            ? '${polishShade.isNotEmpty ? polishShade : 'Natural Teak'} wood tone, shine & inner border molding'
            : meta.defaultDescription;

        final title = _sanitizePdfText(
          (d?['title'] ?? (srvMatches ? srv['design_title'] : null) ?? 'Design #$did').toString(),
        );
        final imgUrl = (d?['image_url'] ?? (srvMatches ? srv['design_image_url'] : null) ?? '').toString();
        final desc = _sanitizePdfText(
          (srvMatches ? (srv['description'] ?? defaultDesc) : defaultDesc).toString(),
        );

        selectedByKey[meta.key] = _PdfElementGuideItem(
          meta: meta,
          pdfColor: _pdfColorForElementKey(meta.key),
          designId: did,
          designTitle: title,
          designImageUrl: imgUrl,
          isExplicit: true,
          description: desc,
        );
      }

      if (selectedByKey.isNotEmpty) {
        final result = selectedByKey.values.toList()
          ..sort((a, b) => a.meta.number.compareTo(b.meta.number));
        return result;
      }
    }

    // Priority 2: Explicit-only items from element_breakdown (ignore auto-filled Base items)
    if (serverBreakdown is List && serverBreakdown.isNotEmpty) {
      final maps = serverBreakdown.whereType<Map>().toList();
      final explicitOnly = maps.where((m) => m['is_explicit'] == true).toList();
      final source = explicitOnly.isNotEmpty ? explicitOnly : maps;
      final parsed = <_PdfElementGuideItem>[];
      for (final raw in source) {
        final key = (raw['key'] ?? 'frame').toString();
        final meta = CombineElementMeta.forKey(key);
        parsed.add(
          _PdfElementGuideItem(
            meta: meta,
            pdfColor: _pdfColorForElementKey(meta.key),
            designId: int.tryParse('${raw['design_id']}') ?? 0,
            designTitle: _sanitizePdfText((raw['design_title'] ?? 'Catalog Design').toString()),
            designImageUrl: (raw['design_image_url'] ?? '').toString(),
            isExplicit: true,
            description: _sanitizePdfText((raw['description'] ?? meta.defaultDescription).toString()),
          ),
        );
      }
      if (parsed.isNotEmpty) {
        parsed.sort((a, b) => a.meta.number.compareTo(b.meta.number));
        return parsed;
      }
    }

    // Priority 3: Legacy orders having reference_designs without element labels
    if (refDesigns.isNotEmpty) {
      final parsed = <_PdfElementGuideItem>[];
      for (int i = 0; i < refDesigns.length && i < CombineElementMeta.all.length; i++) {
        final raw = refDesigns[i];
        if (raw is! Map) continue;
        final meta = CombineElementMeta.all[i];
        final did = int.tryParse('${raw['id']}') ?? 0;
        final desc = meta.key == 'border'
            ? '${polishShade.isNotEmpty ? polishShade : 'Natural Teak'} wood tone, shine & inner border molding'
            : meta.defaultDescription;
        parsed.add(
          _PdfElementGuideItem(
            meta: meta,
            pdfColor: _pdfColorForElementKey(meta.key),
            designId: did,
            designTitle: _sanitizePdfText((raw['title'] ?? 'Design #$did').toString()),
            designImageUrl: (raw['image_url'] ?? '').toString(),
            isExplicit: true,
            description: _sanitizePdfText(desc),
          ),
        );
      }
      return parsed;
    }

    return [];
  }

  /// Renders large, clear individual photos of every selected reference door for the workshop team.
  static pw.Widget _buildSelectedReferencePhotosSection({
    required List<_PdfElementGuideItem> items,
    required Map<String, pw.MemoryImage> sourceImages,
    required double contentWidth,
    required bool compact,
  }) {
    final cardW = compact ? ((contentWidth - 8) / 2.0).clamp(84.0, 120.0) : 101.0;
    final imgH = compact ? 92.0 : 120.0;

    return pw.Row(
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'SELECTED REFERENCE DOOR PHOTOS (${items.length})',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: compact ? 9.5 : 10.5,
                  color: PdfColor.fromHex('#261B12'),
                ),
              ),
              pw.SizedBox(height: 1.5),
              pw.Text(
                'Individual source door photos selected for this custom order',
                style: pw.TextStyle(fontSize: compact ? 7.0 : 7.5, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 6),
              pw.Wrap(
                spacing: compact ? 8 : 10,
                runSpacing: compact ? 8 : 10,
                children: items.map((item) {
                  final img = sourceImages[item.designImageUrl];
                  return pw.Container(
                    width: cardW,
                    padding: const pw.EdgeInsets.all(5),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(color: item.pdfColor, width: 1.2),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Container(
                          width: cardW - 10,
                          height: imgH,
                          padding: const pw.EdgeInsets.all(2.5),
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromHex('#FDFAF6'),
                            borderRadius: pw.BorderRadius.circular(4),
                            border: pw.Border.all(color: PdfColor.fromHex('#E2D9CC'), width: 0.6),
                          ),
                          child: img != null
                              ? pw.Center(child: pw.Image(img, fit: pw.BoxFit.contain))
                              : pw.Center(
                                  child: pw.Text(
                                    'Design #${item.designId}',
                                    textAlign: pw.TextAlign.center,
                                    style: pw.TextStyle(
                                      fontSize: 7,
                                      fontWeight: pw.FontWeight.bold,
                                      color: item.pdfColor,
                                    ),
                                  ),
                                ),
                        ),
                        pw.SizedBox(height: 4.5),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            _buildNumberBadge(
                              number: item.meta.number,
                              color: item.pdfColor,
                              size: 11.5,
                              withWhiteRing: false,
                            ),
                            pw.SizedBox(width: 3.5),
                            pw.Expanded(
                              child: pw.Text(
                                _sanitizePdfText(item.meta.label),
                                maxLines: 1,
                                overflow: pw.TextOverflow.clip,
                                style: pw.TextStyle(
                                  fontSize: compact ? 6.8 : 7.2,
                                  fontWeight: pw.FontWeight.bold,
                                  color: item.pdfColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          item.designTitle,
                          maxLines: 2,
                          overflow: pw.TextOverflow.clip,
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            fontSize: compact ? 6.2 : 6.6,
                            color: PdfColor.fromHex('#2A180C'),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Desktop / A4 3-column pictorial Style Source Guide matching Screenshot 2.
  static pw.Widget _buildStyleSourceGuideWide({
    required String category,
    required double contentWidth,
    required pw.MemoryImage? doorImg,
    required double doorAspect,
    required List<_PdfElementGuideItem> items,
    required Map<String, _PdfGuideRect> regions,
    required Map<String, pw.MemoryImage> sourceImages,
  }) {
    final byKey = <String, _PdfElementGuideItem>{
      for (final it in items) it.meta.key: it,
    };

    final innerW = contentWidth - 2.0; // account for outer 1pt border left + right
    const diagramH = 268.0;
    const padX = 8.0;
    const padY = 8.0;
    final sideCardW = ((innerW - padX * 2) * 0.338).clamp(150.0, 192.0);
    const gapW = 14.0;
    final doorBoxW = (innerW - padX * 2 - sideCardW * 2 - gapW * 2).clamp(112.0, 180.0);
    const doorBoxH = diagramH - padY * 2;
    final doorLeft = (innerW - doorBoxW) / 2.0;
    const doorTop = padY;
    const doorPad = 5.0;

    const cardH = 78.0;
    final rightX = innerW - padX - sideCardW;

    final cardRects = <String, _PdfGuideRect>{
      'crown': _PdfGuideRect(padX, 8.0, sideCardW, cardH),
      'frame': _PdfGuideRect(padX, (diagramH - cardH) / 2.0, sideCardW, cardH),
      'panel': _PdfGuideRect(padX, diagramH - cardH - 8.0, sideCardW, cardH),
      'center': _PdfGuideRect(rightX, diagramH * 0.165, sideCardW, cardH),
      'border': _PdfGuideRect(rightX, diagramH * 0.56, sideCardW, cardH),
    };

    final doorInnerRect = _PdfGuideRect(
      doorLeft + doorPad,
      doorTop + doorPad,
      doorBoxW - doorPad * 2,
      doorBoxH - doorPad * 2,
    );
    final renderedDoorRect = _computeRenderedDoorRect(
      doorInnerRect: doorInnerRect,
      doorAspect: doorAspect,
    );
    final mappedZones = _computeMappedZones(
      renderedDoorRect: renderedDoorRect,
      regions: regions,
    );
    final badgeCenters = _computeDoorBadgeCenters(mappedZones);
    const badgeSize = 14.0;

    // Wrap in a horizontal Row so MultiPage keeps header + full diagram atomic across page breaks
    return pw.Row(
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(
                'SECTION DETAILS - STYLE SOURCE GUIDE',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10.5,
                  color: PdfColor.fromHex('#261B12'),
                ),
              ),
              pw.SizedBox(height: 1.5),
              pw.Text(
                'Shows which selected catalog design contributed each marked section',
                style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 5),
              pw.Container(
                width: contentWidth,
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#FAF7F2'),
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColor.fromHex('#E2D9CC'), width: 1.0),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    // Dark wood header banner
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#381E0E'),
                        borderRadius: const pw.BorderRadius.only(
                          topLeft: pw.Radius.circular(7),
                          topRight: pw.Radius.circular(7),
                        ),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Text(
                            'Custom $category - ${items.length} Selected ${items.length == 1 ? 'Element' : 'Elements'} Guide',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 10.5,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 1.5),
                          pw.Text(
                            'Each color highlights only the exact areas & source catalog designs you selected',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                              color: PdfColor.fromHex('#ECDECC'),
                              fontSize: 7.2,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 3-Column Pictorial Diagram
                    pw.SizedBox(
                      width: innerW,
                      height: diagramH,
                      child: pw.Stack(
                        children: [
                          // Layer 1a: Center White Showcase Container
                          pw.Positioned(
                            left: doorLeft,
                            top: doorTop,
                            child: pw.Container(
                              width: doorBoxW,
                              height: doorBoxH,
                              decoration: pw.BoxDecoration(
                                color: PdfColors.white,
                                borderRadius: pw.BorderRadius.circular(8),
                                border: pw.Border.all(color: PdfColor.fromHex('#E2D9CC'), width: 1.0),
                              ),
                              child: doorImg == null
                                  ? pw.Center(
                                      child: pw.Text(
                                        'Final Design Preview',
                                        style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
                                      ),
                                    )
                                  : null,
                            ),
                          ),

                          // Layer 1b: Exact-positioned Door Image aligned 1:1 with renderedDoorRect
                          if (doorImg != null)
                            pw.Positioned(
                              left: renderedDoorRect.left,
                              top: renderedDoorRect.top,
                              child: pw.SizedBox(
                                width: renderedDoorRect.width,
                                height: renderedDoorRect.height,
                                child: pw.Image(doorImg, fit: pw.BoxFit.fill),
                              ),
                            ),

                          // Layer 2: Vector Zone Overlays + Leader Callout Lines + Target Dots
                          pw.Positioned(
                            left: 0,
                            top: 0,
                            child: pw.CustomPaint(
                              size: PdfPoint(innerW, diagramH),
                              painter: (PdfGraphics canvas, PdfPoint size) {
                                _paintPdfPictorialOverlay(
                                  canvas: canvas,
                                  size: size,
                                  zones: mappedZones,
                                  cardRects: cardRects,
                                  byKey: byKey,
                                  doorCenterX: doorInnerRect.centerX,
                                  drawLeaderLines: true,
                                );
                              },
                            ),
                          ),

                          // Layer 3a: Numbered Circular Badges right on each zone of the door
                          for (final meta in CombineElementMeta.all)
                            if (byKey.containsKey(meta.key) && badgeCenters.containsKey(meta.key))
                              pw.Positioned(
                                left: badgeCenters[meta.key]!.x - badgeSize / 2,
                                top: badgeCenters[meta.key]!.y - badgeSize / 2,
                                child: _buildNumberBadge(
                                  number: meta.number,
                                  color: _pdfColorForElementKey(meta.key),
                                  size: badgeSize,
                                  withWhiteRing: true,
                                ),
                              ),

                          // Layer 3b: Left & Right Color-Coded Source Callout Cards
                          for (final entry in cardRects.entries)
                            if (byKey.containsKey(entry.key))
                              pw.Positioned(
                                left: entry.value.left,
                                top: entry.value.top,
                                child: pw.SizedBox(
                                  width: entry.value.width,
                                  height: entry.value.height,
                                  child: _buildStyleCalloutCard(
                                    item: byKey[entry.key]!,
                                    thumbImg: sourceImages[byKey[entry.key]!.designImageUrl],
                                    compact: false,
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),

                    // Bottom Legend Strip
                    pw.Container(height: 0.8, color: PdfColor.fromHex('#E2D9CC')),
                    _buildLegendStrip(items: items, compact: false),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Compact / Narrow (A5 & 80mm Receipt) vertical Style Source Guide returned as flowable widgets.
  static List<pw.Widget> _buildStyleSourceGuideCompact({
    required String category,
    required double contentWidth,
    required pw.MemoryImage? doorImg,
    required double doorAspect,
    required List<_PdfElementGuideItem> items,
    required Map<String, _PdfGuideRect> regions,
    required Map<String, pw.MemoryImage> sourceImages,
  }) {
    final byKey = <String, _PdfElementGuideItem>{
      for (final it in items) it.meta.key: it,
    };
    const orderedKeys = ['crown', 'frame', 'panel', 'center', 'border'];
    final doorBoxH = (contentWidth * 0.96).clamp(155.0, 215.0);
    const doorPad = 5.0;
    final doorInnerRect = _PdfGuideRect(
      doorPad,
      doorPad,
      contentWidth - doorPad * 2,
      doorBoxH - doorPad * 2,
    );
    final renderedDoorRect = _computeRenderedDoorRect(
      doorInnerRect: doorInnerRect,
      doorAspect: doorAspect,
    );
    final mappedZones = _computeMappedZones(
      renderedDoorRect: renderedDoorRect,
      regions: regions,
    );
    final badgeCenters = _computeDoorBadgeCenters(mappedZones);
    const badgeSize = 13.0;

    return [
      // Wrap in a horizontal Row so MultiPage keeps title, dark banner, and annotated door together
      pw.Row(
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(
                  'SECTION DETAILS - STYLE SOURCE GUIDE',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 9.5,
                    color: PdfColor.fromHex('#261B12'),
                  ),
                ),
                pw.SizedBox(height: 1.5),
                pw.Text(
                  'Shows which selected catalog design contributed each marked section',
                  style: const pw.TextStyle(fontSize: 7.0, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 5),
                pw.Container(
                  width: contentWidth,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#381E0E'),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'Custom $category - ${items.length} Selected ${items.length == 1 ? 'Element' : 'Elements'} Guide',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(color: PdfColors.white, fontSize: 9.0, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 1.5),
                      pw.Text(
                        'Each color highlights only the exact areas & source catalog designs you selected',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(color: PdfColor.fromHex('#ECDECC'), fontSize: 6.5),
                      ),
                    ],
                  ),
                ),
                if (doorImg != null) ...[
                  pw.SizedBox(height: 6),
                  pw.Container(
                    width: contentWidth,
                    height: doorBoxH,
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(7),
                      border: pw.Border.all(color: PdfColor.fromHex('#E2D9CC'), width: 1.0),
                    ),
                    child: pw.Stack(
                      children: [
                        pw.Positioned(
                          left: renderedDoorRect.left,
                          top: renderedDoorRect.top,
                          child: pw.SizedBox(
                            width: renderedDoorRect.width,
                            height: renderedDoorRect.height,
                            child: pw.Image(doorImg, fit: pw.BoxFit.fill),
                          ),
                        ),
                        pw.Positioned(
                          left: 0,
                          top: 0,
                          child: pw.CustomPaint(
                            size: PdfPoint(contentWidth, doorBoxH),
                            painter: (PdfGraphics canvas, PdfPoint size) {
                              _paintPdfPictorialOverlay(
                                canvas: canvas,
                                size: size,
                                zones: mappedZones,
                                cardRects: const {},
                                byKey: byKey,
                                doorCenterX: renderedDoorRect.centerX,
                                drawLeaderLines: false,
                              );
                            },
                          ),
                        ),
                        for (final meta in CombineElementMeta.all)
                          if (byKey.containsKey(meta.key) && badgeCenters.containsKey(meta.key))
                            pw.Positioned(
                              left: badgeCenters[meta.key]!.x - badgeSize / 2,
                              top: badgeCenters[meta.key]!.y - badgeSize / 2,
                              child: _buildNumberBadge(
                                number: meta.number,
                                color: _pdfColorForElementKey(meta.key),
                                size: badgeSize,
                                withWhiteRing: true,
                              ),
                            ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 6),
      for (final key in orderedKeys)
        if (byKey.containsKey(key)) ...[
          _buildStyleCalloutCard(
            item: byKey[key]!,
            thumbImg: sourceImages[byKey[key]!.designImageUrl],
            compact: true,
          ),
          pw.SizedBox(height: 5),
        ],
      _buildLegendStrip(items: items, compact: true),
    ];
  }

  static pw.Widget _buildStyleCalloutCard({
    required _PdfElementGuideItem item,
    required pw.MemoryImage? thumbImg,
    required bool compact,
  }) {
    final prefix = item.isExplicit ? 'From:' : 'Base:';
    final thumbW = compact ? 32.0 : 35.0;
    final thumbH = compact ? 48.0 : 64.0;

    return pw.Container(
      padding: pw.EdgeInsets.all(compact ? 5.0 : 4.5),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(7),
        border: pw.Border.all(color: item.pdfColor, width: 1.25),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: thumbW,
            height: thumbH,
            padding: const pw.EdgeInsets.all(2),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#FDFAF6'),
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(color: PdfColor.fromHex('#E2D9CC'), width: 0.7),
            ),
            child: thumbImg != null
                ? pw.Center(child: pw.Image(thumbImg, fit: pw.BoxFit.contain))
                : pw.Center(
                    child: pw.Text(
                      '#${item.designId}',
                      style: pw.TextStyle(
                        fontSize: 6.5,
                        fontWeight: pw.FontWeight.bold,
                        color: item.pdfColor,
                      ),
                    ),
                  ),
          ),
          pw.SizedBox(width: 5.5),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.center,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    _buildNumberBadge(
                      number: item.meta.number,
                      color: item.pdfColor,
                      size: compact ? 12.0 : 12.5,
                      withWhiteRing: false,
                    ),
                    pw.SizedBox(width: 4),
                    pw.Expanded(
                      child: pw.Text(
                        _sanitizePdfText(item.meta.label),
                        maxLines: 1,
                        overflow: pw.TextOverflow.clip,
                        style: pw.TextStyle(
                          fontSize: compact ? 7.5 : 7.4,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#2A180C'),
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 2.5),
                pw.Text(
                  '$prefix ${item.designTitle}',
                  maxLines: 2,
                  overflow: pw.TextOverflow.clip,
                  style: pw.TextStyle(
                    fontSize: compact ? 6.8 : 6.6,
                    fontWeight: pw.FontWeight.bold,
                    color: item.pdfColor,
                    lineSpacing: 1.0,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  item.description,
                  maxLines: 2,
                  overflow: pw.TextOverflow.clip,
                  style: pw.TextStyle(
                    fontSize: compact ? 6.0 : 5.9,
                    color: PdfColor.fromHex('#5C5248'),
                    lineSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildNumberBadge({
    required int number,
    required PdfColor color,
    required double size,
    required bool withWhiteRing,
  }) {
    return pw.Container(
      width: size,
      height: size,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        color: color,
        shape: pw.BoxShape.circle,
        border: withWhiteRing ? pw.Border.all(color: PdfColors.white, width: 1.3) : null,
      ),
      child: pw.Text(
        '$number',
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: (size * 0.54).clamp(6.0, 9.0),
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _buildLegendStrip({
    required List<_PdfElementGuideItem> items,
    required bool compact,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: pw.EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 5 : 6),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F3ECE2'),
        borderRadius: compact
            ? pw.BorderRadius.circular(6)
            : const pw.BorderRadius.only(
                bottomLeft: pw.Radius.circular(7),
                bottomRight: pw.Radius.circular(7),
              ),
        border: compact ? pw.Border.all(color: PdfColor.fromHex('#E2D9CC'), width: 0.8) : null,
      ),
      child: pw.Wrap(
        alignment: pw.WrapAlignment.center,
        spacing: compact ? 7 : 10,
        runSpacing: 4,
        children: items.map((item) {
          final m = item.meta;
          return pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              _buildNumberBadge(
                number: m.number,
                color: _pdfColorForElementKey(m.key),
                size: compact ? 10.5 : 11.0,
                withWhiteRing: false,
              ),
              pw.SizedBox(width: 3.5),
              pw.Text(
                _sanitizePdfText(m.label),
                style: pw.TextStyle(
                  fontSize: compact ? 6.5 : 7.0,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#2A180C'),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  static _PdfGuideRect _computeRenderedDoorRect({
    required _PdfGuideRect doorInnerRect,
    required double doorAspect,
  }) {
    final cW = doorInnerRect.width;
    final cH = doorInnerRect.height;
    final aspect = doorAspect.clamp(0.45, 1.35);
    double rw = cW;
    double rh = rw / aspect;
    if (rh > cH) {
      rh = cH;
      rw = rh * aspect;
    }
    final ox = doorInnerRect.left + (cW - rw) / 2.0;
    final oy = doorInnerRect.top + (cH - rh) / 2.0;
    return _PdfGuideRect(ox, oy, rw, rh);
  }

  static Map<String, _PdfGuideRect> _computeMappedZones({
    required _PdfGuideRect renderedDoorRect,
    required Map<String, _PdfGuideRect> regions,
  }) {
    final ox = renderedDoorRect.left;
    final oy = renderedDoorRect.top;
    final rw = renderedDoorRect.width;
    final rh = renderedDoorRect.height;

    final out = <String, _PdfGuideRect>{};
    for (final entry in regions.entries) {
      final norm = entry.value;
      out[entry.key] = _PdfGuideRect(
        ox + norm.left * rw,
        oy + norm.top * rh,
        (norm.width * rw).clamp(8.0, rw),
        (norm.height * rh).clamp(8.0, rh),
      );
    }
    return out;
  }

  static Map<String, PdfPoint> _computeDoorBadgeCenters(Map<String, _PdfGuideRect> zones) {
    final zCrown = zones['crown'];
    final zFrame = zones['frame'];
    final zPanel = zones['panel'];
    final zCenter = zones['center'];
    final zBorder = zones['border'];
    final out = <String, PdfPoint>{};

    if (zCrown != null) {
      out['crown'] = PdfPoint(zCrown.centerX, zCrown.centerY);
    }
    if (zFrame != null && zPanel != null) {
      out['frame'] = PdfPoint(
        zFrame.left + ((zPanel.left - zFrame.left) * 0.52).clamp(5.0, 14.0),
        zFrame.top + zFrame.height * 0.48,
      );
    }
    if (zPanel != null) {
      out['panel'] = PdfPoint(
        zPanel.left + (zPanel.width * 0.24).clamp(10.0, 26.0),
        zPanel.bottom - 9.0,
      );
    }
    if (zCenter != null) {
      out['center'] = PdfPoint(zCenter.centerX, zCenter.centerY);
    }
    if (zBorder != null) {
      out['border'] = PdfPoint(zBorder.centerX, zBorder.bottom - 10.0);
    }
    return out;
  }

  static void _paintPdfPictorialOverlay({
    required PdfGraphics canvas,
    required PdfPoint size,
    required Map<String, _PdfGuideRect> zones,
    required Map<String, _PdfGuideRect> cardRects,
    required Map<String, _PdfElementGuideItem> byKey,
    required double doorCenterX,
    required bool drawLeaderLines,
  }) {
    double toPdfY(double topDownY) => size.y - topDownY;

    void drawZone(String key, {required bool dashed}) {
      if (!byKey.containsKey(key)) return;
      final r = zones[key];
      if (r == null) return;
      final col = _pdfColorForElementKey(key);
      canvas.saveContext();
      canvas.setStrokeColor(col);
      canvas.setLineWidth(1.3);
      if (dashed) {
        canvas.setLineDashPattern([4.0, 2.5]);
      } else {
        canvas.setLineDashPattern();
      }
      final radius = (r.width < 12 || r.height < 12) ? 1.5 : 3.0;
      canvas.drawRRect(r.left, toPdfY(r.bottom), r.width, r.height, radius, radius);
      canvas.strokePath();
      canvas.restoreContext();
    }

    drawZone('frame', dashed: true);
    drawZone('panel', dashed: true);
    drawZone('center', dashed: false);
    drawZone('border', dashed: false);
    drawZone('crown', dashed: false);

    if (drawLeaderLines && cardRects.isNotEmpty) {
      final zCrown = zones['crown'];
      final zFrame = zones['frame'];
      final zPanel = zones['panel'];
      final zCenter = zones['center'];
      final zBorder = zones['border'];

      final targets = <String, PdfPoint>{
        if (zCrown != null) 'crown': PdfPoint(zCrown.left + 6.0, zCrown.centerY),
        if (zFrame != null) 'frame': PdfPoint(zFrame.left, zFrame.top + zFrame.height * 0.36),
        if (zPanel != null) 'panel': PdfPoint(zPanel.left + 3.0, zPanel.bottom - (zPanel.height * 0.08).clamp(8.0, 15.0)),
        if (zCenter != null) 'center': PdfPoint(zCenter.right - 3.0, zCenter.top + zCenter.height * 0.34),
        if (zBorder != null) 'border': PdfPoint(zBorder.right, zBorder.centerY),
      };

      for (final m in CombineElementMeta.all) {
        if (!byKey.containsKey(m.key)) continue;
        final card = cardRects[m.key];
        final target = targets[m.key];
        if (card == null || target == null) continue;

        final col = _pdfColorForElementKey(m.key);
        final isLeft = card.centerX < doorCenterX;
        final startX = isLeft ? card.right : card.left;
        final startY = card.centerY;
        final elbowX = isLeft ? card.right + 7.5 : card.left - 7.5;

        canvas.saveContext();
        canvas.setStrokeColor(col);
        canvas.setLineWidth(1.15);
        canvas.setLineCap(PdfLineCap.round);
        canvas.setLineJoin(PdfLineJoin.round);
        canvas.setLineDashPattern();
        canvas.moveTo(startX, toPdfY(startY));
        canvas.lineTo(elbowX, toPdfY(startY));
        canvas.lineTo(target.x, toPdfY(target.y));
        canvas.strokePath();

        // White-ringed target dot on the door zone
        canvas.setFillColor(PdfColors.white);
        canvas.drawEllipse(target.x, toPdfY(target.y), 3.1, 3.1);
        canvas.fillPath();

        canvas.setFillColor(col);
        canvas.drawEllipse(target.x, toPdfY(target.y), 1.9, 1.9);
        canvas.fillPath();
        canvas.restoreContext();
      }
    }
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
            child: pw.Text(
              '${_sanitizePdfText(label)}:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: compact ? 8.5 : 10),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              _sanitizePdfText(value),
              style: pw.TextStyle(fontSize: compact ? 8.5 : 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _PdfGuideRect {
  final double left;
  final double top;
  final double width;
  final double height;

  const _PdfGuideRect(this.left, this.top, this.width, this.height);

  double get right => left + width;
  double get bottom => top + height;
  double get centerX => left + width / 2.0;
  double get centerY => top + height / 2.0;
}

class _PdfElementGuideItem {
  final CombineElementMeta meta;
  final PdfColor pdfColor;
  final int designId;
  final String designTitle;
  final String designImageUrl;
  final bool isExplicit;
  final String description;

  const _PdfElementGuideItem({
    required this.meta,
    required this.pdfColor,
    required this.designId,
    required this.designTitle,
    required this.designImageUrl,
    required this.isExplicit,
    required this.description,
  });
}
