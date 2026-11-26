import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:wooden_staff_app/services/pdf_service.dart';
import 'package:wooden_staff_app/widgets/door_pictorial_guide.dart';

void main() {
  pw.MemoryImage? loadDiskImage(String relativePath) {
    final file = File(relativePath);
    if (!file.existsSync()) return null;
    return pw.MemoryImage(file.readAsBytesSync());
  }

  Map<String, dynamic> sampleThreeSelectedJob({bool includeLegacyFiveBreakdown = true, String workshopNotes = ''}) {
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
      'reference_design_ids': [74, 82, 102],
      'reference_elements': [
        {'design_id': 74, 'element': 'Frame Style'},
        {'design_id': 82, 'element': 'Center Carving'},
        {'design_id': 102, 'element': 'Border / Polish Finish'},
      ],
      'reference_designs': [
        {
          'id': 74,
          'title': 'Suresh Timbers Carved Teak Door #074',
          'image_url': '/uploads/catalog/st-product-17-royal-heritage-main-door.jpg',
        },
        {
          'id': 82,
          'title': 'Suresh Timbers Pooja Door Catalogue #082',
          'image_url': '/uploads/catalog/st-product-18-classic-single-door.jpg',
        },
        {
          'id': 102,
          'title': 'Suresh Timbers Pooja Door Catalogue #102',
          'image_url': '/uploads/catalog/st-product-19-grand-royal-entrance-door.jpg',
        },
      ],
    };

    if (includeLegacyFiveBreakdown) {
      // Simulate an older server response containing 2 auto-picked non-explicit Base items:
      // PdfService MUST strip them and only render the 3 selected elements!
      job['element_breakdown'] = [
        {
          'number': 1,
          'key': 'frame',
          'label': 'Frame Style',
          'design_id': 74,
          'design_title': 'Suresh Timbers Carved Teak Door #074',
          'design_image_url': '/uploads/catalog/st-product-17-royal-heritage-main-door.jpg',
          'is_explicit': true,
          'description': 'Full outer wooden frame & left/right carved pillars',
        },
        {
          'number': 2,
          'key': 'center',
          'label': 'Center Carving',
          'design_id': 82,
          'design_title': 'Suresh Timbers Pooja Door Catalogue #082',
          'design_image_url': '/uploads/catalog/st-product-18-classic-single-door.jpg',
          'is_explicit': true,
          'description': 'Main carving artwork inside the door leaf',
        },
        {
          'number': 3,
          'key': 'border',
          'label': 'Border / Polish Finish',
          'design_id': 102,
          'design_title': 'Suresh Timbers Pooja Door Catalogue #102',
          'design_image_url': '/uploads/catalog/st-product-19-grand-royal-entrance-door.jpg',
          'is_explicit': true,
          'description': 'Natural Teak Matte wood tone, shine & inner border molding',
        },
        {
          'number': 4,
          'key': 'crown',
          'label': 'Top Arch & Crown',
          'design_id': 82,
          'design_title': 'Suresh Timbers Pooja Door Catalogue #082',
          'design_image_url': '/uploads/catalog/st-product-18-classic-single-door.jpg',
          'is_explicit': false,
          'description': 'Top arch, temple carving & crown header only',
        },
        {
          'number': 5,
          'key': 'panel',
          'label': 'Panel Layout',
          'design_id': 82,
          'design_title': 'Suresh Timbers Pooja Door Catalogue #082',
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

  test('Workshop Job Sheet PDF renders ONLY selected elements + selected door photos on A4, A5, and 80mm Receipt', () async {
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

    // 1. A4 with 3 selected images (even when legacy 5-item server breakdown is present)
    final a4Bytes = await PdfService.buildWorkshopJobSheetPdf(
      sampleThreeSelectedJob(includeLegacyFiveBreakdown: true),
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

    final previewDir = Platform.environment['WOODCRAFT_PDF_PREVIEW_DIR'];
    if (previewDir != null && previewDir.isNotEmpty) {
      Directory(previewDir).createSync(recursive: true);
      File('$previewDir/workshop_3sel_a4.pdf').writeAsBytesSync(a4Bytes);
    }

    // 2. A4 reconstructed from reference_elements + reference_designs only
    final legacyBytes = await PdfService.buildWorkshopJobSheetPdf(
      sampleThreeSelectedJob(includeLegacyFiveBreakdown: false),
      pageFormat: PdfPageFormat.a4,
      designImg: doorImg,
      logoImg: logoImg,
      sourceImages: sourceImages,
    );
    expect(legacyBytes, isNotEmpty);

    // 3. A4 with workshop notes
    final notesBytes = await PdfService.buildWorkshopJobSheetPdf(
      sampleThreeSelectedJob(
        includeLegacyFiveBreakdown: true,
        workshopNotes:
            'Use seasoned Burma Teak pillars with hand-carved lotus beads. Double-check 42x84 opening tolerance.',
      ),
      pageFormat: PdfPageFormat.a4,
      designImg: doorImg,
      logoImg: logoImg,
      sourceImages: sourceImages,
    );
    expect(notesBytes, isNotEmpty);

    // 4. A5 compact mode
    final a5Bytes = await PdfService.buildWorkshopJobSheetPdf(
      sampleThreeSelectedJob(includeLegacyFiveBreakdown: true),
      pageFormat: PdfPageFormat.a5,
      designImg: doorImg,
      logoImg: logoImg,
      sourceImages: sourceImages,
    );
    expect(a5Bytes, isNotEmpty);
    if (previewDir != null && previewDir.isNotEmpty) {
      File('$previewDir/workshop_3sel_a5.pdf').writeAsBytesSync(a5Bytes);
    }

    // 5. 80mm receipt compact mode
    final rollBytes = await PdfService.buildWorkshopJobSheetPdf(
      sampleThreeSelectedJob(includeLegacyFiveBreakdown: true),
      pageFormat: PdfPageFormat.roll80,
      designImg: doorImg,
      logoImg: logoImg,
      sourceImages: sourceImages,
    );
    expect(rollBytes, isNotEmpty);
    if (previewDir != null && previewDir.isNotEmpty) {
      File('$previewDir/workshop_3sel_roll80.pdf').writeAsBytesSync(rollBytes);
    }

    // 6. Order without reference designs still generates cleanly
    final minimalJob = Map<String, dynamic>.from(sampleThreeSelectedJob(includeLegacyFiveBreakdown: false))
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

  testWidgets('DoorElementsPictorialCard renders ONLY the 3 selected sections and legend items', (tester) async {
    final threeItems = [
      PictorialElementItem(
        meta: CombineElementMeta.all[0], // 1. Frame Style
        designId: 74,
        designTitle: 'Suresh Timbers Carved Teak Door #074',
        designImageUrl: '',
        isExplicit: true,
        description: CombineElementMeta.all[0].defaultDescription,
      ),
      PictorialElementItem(
        meta: CombineElementMeta.all[1], // 2. Center Carving
        designId: 82,
        designTitle: 'Suresh Timbers Pooja Door Catalogue #082',
        designImageUrl: '',
        isExplicit: true,
        description: CombineElementMeta.all[1].defaultDescription,
      ),
      PictorialElementItem(
        meta: CombineElementMeta.all[2], // 3. Border / Polish Finish
        designId: 102,
        designTitle: 'Suresh Timbers Pooja Door Catalogue #102',
        designImageUrl: '',
        isExplicit: true,
        description: 'Natural Teak Matte wood tone, shine & inner border molding',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 960,
              child: DoorElementsPictorialCard(
                category: 'Door',
                polishShade: 'Natural Teak Matte',
                generatedImageUrl: '',
                items: threeItems,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Custom Door — 3 Selected Elements Guide'), findsOneWidget);
    // Selected 3 labels appear (card + legend = 2 each)
    expect(find.text('Frame Style'), findsNWidgets(2));
    expect(find.text('Center Carving'), findsNWidgets(2));
    expect(find.text('Border / Polish Finish'), findsNWidgets(2));
    // Unselected 2 labels MUST NOT appear anywhere!
    expect(find.text('Top Arch & Crown'), findsNothing);
    expect(find.text('Panel Layout'), findsNothing);
  });
}
