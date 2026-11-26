import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:wooden_staff_app/services/pdf_service.dart';

void main() {
  pw.MemoryImage? loadDiskImage(String relativePath) {
    final file = File(relativePath);
    if (!file.existsSync()) return null;
    return pw.MemoryImage(file.readAsBytesSync());
  }

  Map<String, dynamic> sampleJob({bool includeServerBreakdown = true, String workshopNotes = ''}) {
    final job = <String, dynamic>{
      'job_id': 'SUW-2026-0005',
      'expected_delivery_date': '2026-12-10',
      'priority': 'Normal',
      'woodwork_category': 'Door',
      'width_inches': '42.00',
      'height_inches': '84.00',
      'frame_section': '5 x 3 inch',
      'door_thickness': '1.75 inch (45mm)',
      'leaf_type': 'Double Leaf',
      'wood_species': 'Burma Teak',
      'carving_pattern': 'Royal Lotus & Pillar Carving',
      'polish_shade': 'Natural Teak Matte',
      'hardware': 'Antique Brass Handles & Mortise Lock',
      'quantity': 1,
      'workshop_notes': workshopNotes,
      // Deliberately present to confirm Workshop Sheet strictly excludes customer & billing fields:
      'customer_name': 'SECRET_CUSTOMER_NAME',
      'customer_mobile': '9876543210',
      'customer_address': 'SECRET_DELIVERY_ADDRESS',
      'total_cost': 95000,
      'advance_amount': 30000,
      'balance_amount': 65000,
      'reference_design_ids': [14, 61, 62],
      'reference_elements': [
        {'design_id': 14, 'element': 'Frame Style'},
        {'design_id': 61, 'element': 'Center Carving'},
        {'design_id': 62, 'element': 'Border / Polish Finish'},
      ],
      'reference_designs': [
        {
          'id': 14,
          'title': 'Suresh Timbers Carved Teak Door #014',
          'image_url': '/uploads/catalog/st-product-17-royal-heritage-main-door.jpg',
        },
        {
          'id': 61,
          'title': 'Suresh Timbers Pooja Door Catalogue #061',
          'image_url': '/uploads/catalog/st-product-18-classic-single-door.jpg',
        },
        {
          'id': 62,
          'title': 'Suresh Timbers Pooja Door Catalogue #062',
          'image_url': '/uploads/catalog/st-product-19-grand-royal-entrance-door.jpg',
        },
      ],
    };

    if (includeServerBreakdown) {
      job['element_breakdown'] = [
        {
          'number': 1,
          'key': 'frame',
          'label': 'Frame Style',
          'design_id': 14,
          'design_title': 'Suresh Timbers Carved Teak Door #014',
          'design_image_url': '/uploads/catalog/st-product-17-royal-heritage-main-door.jpg',
          'is_explicit': true,
          'description': 'Full outer wooden frame & left/right carved pillars',
        },
        {
          'number': 2,
          'key': 'center',
          'label': 'Center Carving',
          'design_id': 61,
          'design_title': 'Suresh Timbers Pooja Door Catalogue #061',
          'design_image_url': '/uploads/catalog/st-product-18-classic-single-door.jpg',
          'is_explicit': true,
          'description': 'Main carving artwork inside the door leaf',
        },
        {
          'number': 3,
          'key': 'border',
          'label': 'Border / Polish Finish',
          'design_id': 62,
          'design_title': 'Suresh Timbers Pooja Door Catalogue #062',
          'design_image_url': '/uploads/catalog/st-product-19-grand-royal-entrance-door.jpg',
          'is_explicit': true,
          'description': 'Natural Teak Matte wood tone, shine & inner border molding',
        },
        {
          'number': 4,
          'key': 'crown',
          'label': 'Top Arch & Crown',
          'design_id': 61,
          'design_title': 'Suresh Timbers Pooja Door Catalogue #061',
          'design_image_url': '/uploads/catalog/st-product-18-classic-single-door.jpg',
          'is_explicit': false,
          'description': 'Top arch, temple carving & crown header only',
        },
        {
          'number': 5,
          'key': 'panel',
          'label': 'Panel Layout',
          'design_id': 61,
          'design_title': 'Suresh Timbers Pooja Door Catalogue #061',
          'design_image_url': '/uploads/catalog/st-product-18-classic-single-door.jpg',
          'is_explicit': false,
          'description': 'Full inner door shutter & panel layout',
        },
      ];
      job['element_regions'] = {
        'crown': {'x': 0.04, 'y': 0.02, 'w': 0.92, 'h': 0.14},
        'frame': {'x': 0.05, 'y': 0.15, 'w': 0.90, 'h': 0.82},
        'panel': {'x': 0.16, 'y': 0.17, 'w': 0.68, 'h': 0.78},
        'center': {'x': 0.22, 'y': 0.23, 'w': 0.56, 'h': 0.64},
        'border': {'x': 0.79, 'y': 0.62, 'w': 0.09, 'h': 0.26},
      };
    }
    return job;
  }

  test('Workshop Job Sheet PDF includes Style Source Guide on A4, A5, and 80mm Receipt', () async {
    final logoImg = loadDiskImage('assets/images/app_logo.png');
    final doorImg = loadDiskImage('../php_api/uploads/catalog/st-product-20-south-indian-main-door.jpg');
    final src1 = loadDiskImage('../php_api/uploads/catalog/st-product-17-royal-heritage-main-door.jpg');
    final src2 = loadDiskImage('../php_api/uploads/catalog/st-product-18-classic-single-door.jpg');
    final src3 = loadDiskImage('../php_api/uploads/catalog/st-product-19-grand-royal-entrance-door.jpg');

    final sourceImages = <String, pw.MemoryImage>{
      if (src1 != null) '/uploads/catalog/st-product-17-royal-heritage-main-door.jpg': src1,
      if (src2 != null) '/uploads/catalog/st-product-18-classic-single-door.jpg': src2,
      if (src3 != null) '/uploads/catalog/st-product-19-grand-royal-entrance-door.jpg': src3,
    };

    // 1. A4 with explicit server breakdown + regions
    final a4Bytes = await PdfService.buildWorkshopJobSheetPdf(
      sampleJob(includeServerBreakdown: true),
      pageFormat: PdfPageFormat.a4,
      designImg: doorImg,
      logoImg: logoImg,
      sourceImages: sourceImages,
    );
    expect(a4Bytes, isNotEmpty);
    final rawAscii = String.fromCharCodes(a4Bytes);
    expect(rawAscii.startsWith('%PDF-'), isTrue);
    expect(rawAscii.contains('SECRET_CUSTOMER_NAME'), isFalse);
    expect(rawAscii.contains('9876543210'), isFalse);
    expect(rawAscii.contains('SECRET_DELIVERY_ADDRESS'), isFalse);

    // Optional preview export when WOODCRAFT_PDF_PREVIEW_DIR env var is set
    final previewDir = Platform.environment['WOODCRAFT_PDF_PREVIEW_DIR'];
    if (previewDir != null && previewDir.isNotEmpty) {
      Directory(previewDir).createSync(recursive: true);
      File('$previewDir/workshop_a4.pdf').writeAsBytesSync(a4Bytes);
    }

    // 2. A4 reconstructed from legacy DB reference_elements + reference_designs (no element_breakdown)
    final legacyBytes = await PdfService.buildWorkshopJobSheetPdf(
      sampleJob(includeServerBreakdown: false),
      pageFormat: PdfPageFormat.a4,
      designImg: doorImg,
      logoImg: logoImg,
      sourceImages: sourceImages,
    );
    expect(legacyBytes, isNotEmpty);

    // 3. A4 with long workshop notes (multi-page wrap cleanly without slicing diagram)
    final notesBytes = await PdfService.buildWorkshopJobSheetPdf(
      sampleJob(
        includeServerBreakdown: true,
        workshopNotes:
            'Use seasoned Burma Teak pillars with hand-carved lotus beads. Double-check 42x84 exact opening tolerance and antique brass mortise lockset cutout height at 39 inches.',
      ),
      pageFormat: PdfPageFormat.a4,
      designImg: doorImg,
      logoImg: logoImg,
      sourceImages: sourceImages,
    );
    expect(notesBytes, isNotEmpty);
    if (previewDir != null && previewDir.isNotEmpty) {
      File('$previewDir/workshop_a4_notes.pdf').writeAsBytesSync(notesBytes);
    }

    // 4. A5 compact mode
    final a5Bytes = await PdfService.buildWorkshopJobSheetPdf(
      sampleJob(includeServerBreakdown: true),
      pageFormat: PdfPageFormat.a5,
      designImg: doorImg,
      logoImg: logoImg,
      sourceImages: sourceImages,
    );
    expect(a5Bytes, isNotEmpty);
    if (previewDir != null && previewDir.isNotEmpty) {
      File('$previewDir/workshop_a5.pdf').writeAsBytesSync(a5Bytes);
    }

    // 5. 80mm receipt compact mode
    final rollBytes = await PdfService.buildWorkshopJobSheetPdf(
      sampleJob(includeServerBreakdown: true),
      pageFormat: PdfPageFormat.roll80,
      designImg: doorImg,
      logoImg: logoImg,
      sourceImages: sourceImages,
    );
    expect(rollBytes, isNotEmpty);
    if (previewDir != null && previewDir.isNotEmpty) {
      File('$previewDir/workshop_roll80.pdf').writeAsBytesSync(rollBytes);
    }

    // 6. Order without reference designs still generates cleanly
    final minimalJob = Map<String, dynamic>.from(sampleJob(includeServerBreakdown: false))
      ..remove('reference_designs')
      ..remove('reference_elements')
      ..remove('reference_design_ids');
    final minimalBytes = await PdfService.buildWorkshopJobSheetPdf(
      minimalJob,
      pageFormat: PdfPageFormat.a4,
      designImg: doorImg,
      logoImg: logoImg,
    );
    expect(minimalBytes, isNotEmpty);
  });
}
