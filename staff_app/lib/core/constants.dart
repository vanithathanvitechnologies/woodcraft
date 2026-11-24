class AppConstants {
  static const List<Map<String, dynamic>> productionStages = [
    {'number': 1, 'name': 'Pending / New Job', 'short': 'New Job'},
    {'number': 2, 'name': 'Timber Cutting', 'short': 'Cutting'},
    {'number': 3, 'name': 'Frame Fabrication', 'short': 'Frame'},
    {'number': 4, 'name': 'Carving / CNC Work', 'short': 'Carving'},
    {'number': 5, 'name': 'Door Assembly', 'short': 'Assembly'},
    {'number': 6, 'name': 'Sanding & Polishing', 'short': 'Polishing'},
    {'number': 7, 'name': 'Quality Check', 'short': 'QC'},
    {'number': 8, 'name': 'Completed / Ready for Delivery', 'short': 'Ready'},
  ];

  static const List<String> woodworkCategories = [
    'Door',
    'Wood Frames',
    'Hard Wood',
  ];

  static const List<String> woodSpecies = [
    'Burma Teak',
    'Ghana Teak',
    'Nilambur Teak',
    'Indian Rosewood',
    'Mahogany',
    'Sal Wood',
    'Vengai Wood',
  ];

  static const List<String> polishShades = [
    'Natural Teak Matte',
    'Honey Gold Gloss',
    'Dark Walnut Satin',
    'Royal Rosewood Gloss',
    'Antique Heritage Finish',
    'Natural PU Clear',
  ];

  static const List<String> frameSections = [
    '4 x 3 inch',
    '5 x 3 inch',
    '5 x 3.5 inch',
    '6 x 3.5 inch',
    '6 x 4 inch',
  ];

  static const List<String> doorThicknesses = [
    '1.25 inch (32mm)',
    '1.5 inch (38mm)',
    '1.75 inch (45mm)',
    '2 inch (50mm)',
  ];

  static const List<String> combineElements = [
    'Frame Style',
    'Center Carving',
    'Border / Polish Finish',
    'Top Arch & Crown',
    'Panel Layout',
  ];

  static String stageName(int stage) {
    final found = productionStages.where((s) => s['number'] == stage);
    return found.isNotEmpty ? found.first['name'] as String : 'Pending / New Job';
  }
}
