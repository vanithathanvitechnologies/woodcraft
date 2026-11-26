import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_theme.dart';
import '../../core/constants.dart';
import '../../services/api_service.dart';
import '../../services/pdf_service.dart';
import '../../widgets/door_pictorial_guide.dart';
import '../../widgets/ui_kit.dart';

class AiCombinerTab extends StatefulWidget {
  const AiCombinerTab({super.key});

  @override
  State<AiCombinerTab> createState() => _AiCombinerTabState();
}

class _AiCombinerTabState extends State<AiCombinerTab> {
  List<dynamic> _catalog = [];
  List<Map<String, dynamic>> _productionMembers = [];
  List<String> _categories = List<String>.from(AppConstants.woodworkCategories);
  bool _loadingCatalog = true;

  // Selected 1-5 catalog designs + element per design
  final Map<int, String> _selectedElements = {};

  // Specifications
  String _category = AppConstants.woodworkCategories.first;
  final _widthCtrl = TextEditingController(text: '42');
  final _heightCtrl = TextEditingController(text: '84');
  String _frameSection = AppConstants.frameSections[2];
  String _doorThickness = AppConstants.doorThicknesses[2];
  String _leafType = 'Double Leaf';
  String _woodSpecies = AppConstants.woodSpecies.first;
  String _polishShade = AppConstants.polishShades.first;
  final _carvingCtrl = TextEditingController(text: 'Royal Lotus & Pillar Carving');
  final _hardwareCtrl = TextEditingController(text: 'Antique Brass Handles & Mortise Lock');
  final _qtyCtrl = TextEditingController(text: '1');
  final _notesCtrl = TextEditingController();

  // AI Output
  bool _generating = false;
  String? _aiImageUrl;
  String? _aiGuideImageUrl;
  String? _aiPromptUsed;
  Map<String, Rect>? _aiElementRegions;
  List<PictorialElementItem> _aiBreakdownItems = [];
  double _aiOutputAspect = 0.75;

  // Customer & Production Assignment (Zero amount fields)
  final _custNameCtrl = TextEditingController();
  final _custMobileCtrl = TextEditingController();
  final _custAddressCtrl = TextEditingController();
  final _productionPlaceCtrl = TextEditingController();
  int? _selectedProductionUserId;
  String _priority = 'Normal';
  DateTime _deliveryDate = DateTime.now().add(const Duration(days: 14));
  bool _savingOrder = false;
  Map<String, dynamic>? _lastSavedOrder;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _widthCtrl.dispose();
    _heightCtrl.dispose();
    _carvingCtrl.dispose();
    _hardwareCtrl.dispose();
    _qtyCtrl.dispose();
    _notesCtrl.dispose();
    _custNameCtrl.dispose();
    _custMobileCtrl.dispose();
    _custAddressCtrl.dispose();
    _productionPlaceCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    setState(() => _loadingCatalog = true);
    try {
      final catalogFuture = ApiService.instance.get('/catalog');
      final categoriesFuture = ApiService.instance
          .get('/categories')
          .catchError((_) => <String, dynamic>{});
      final teamFuture = ApiService.instance
          .get('/production/team')
          .catchError((_) => <String, dynamic>{});

      final results = await Future.wait([catalogFuture, categoriesFuture, teamFuture]);
      if (!mounted) return;

      final designs = (results[0]['designs'] as List?) ?? [];
      final rawCats = (results[1]['categories'] as List?) ?? [];
      final rawTeam = (results[2]['members'] as List?) ?? [];
      final teamList = rawTeam.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();

      final dynamicCats = rawCats
          .map((c) => (c is Map ? (c['name'] ?? '') : c).toString().trim())
          .where((name) => name.isNotEmpty)
          .toList();

      List<String> mergedCats;
      if (dynamicCats.isNotEmpty) {
        mergedCats = dynamicCats;
      } else {
        mergedCats = List<String>.from(AppConstants.woodworkCategories);
        for (final raw in designs) {
          final cat = ((raw as Map)['category'] ?? '').toString().trim();
          if (cat.isNotEmpty && !mergedCats.any((e) => e.toLowerCase() == cat.toLowerCase())) {
            mergedCats.add(cat);
          }
        }
      }

      setState(() {
        _catalog = designs;
        _productionMembers = teamList;
        if (_selectedProductionUserId != null &&
            !_productionMembers.any((m) => int.tryParse('${m['id']}') == _selectedProductionUserId)) {
          _selectedProductionUserId = null;
        }
        _categories = mergedCats;
        if (_categories.isNotEmpty) {
          final matchedIdx = _categories.indexWhere((c) => c.toLowerCase() == _category.toLowerCase());
          if (matchedIdx >= 0) {
            _category = _categories[matchedIdx];
          } else {
            _category = _categories.first;
            _selectedElements.clear();
          }
        }
      });
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingCatalog = false);
    }
  }

  List<dynamic> get _filteredCatalog {
    final target = _category.trim().toLowerCase();
    return _catalog.where((raw) {
      final cat = (raw['category'] ?? '').toString().trim().toLowerCase();
      return cat == target;
    }).toList();
  }

  int _categoryCount(String cat) {
    final target = cat.trim().toLowerCase();
    return _catalog.where((raw) => (raw['category'] ?? '').toString().trim().toLowerCase() == target).length;
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'Door':
        return Icons.door_front_door_rounded;
      case 'Wood Frames':
        return Icons.crop_portrait_rounded;
      case 'Hard Wood':
        return Icons.forest_rounded;
      default:
        return Icons.door_front_door_rounded;
    }
  }

  void _selectCategory(String newCategory) {
    if (_category == newCategory) return;
    setState(() {
      _category = newCategory;
      _selectedElements.clear();
      _aiImageUrl = null;
      _aiGuideImageUrl = null;
      _aiPromptUsed = null;
      _aiElementRegions = null;
      _aiBreakdownItems = [];

      // Apply sensible default dimensions & carving hint for the chosen woodwork category
      switch (newCategory) {
        case 'Door':
          _widthCtrl.text = '42';
          _heightCtrl.text = '84';
          _leafType = 'Double Leaf';
          _carvingCtrl.text = 'Royal Lotus & Pillar Carving';
          break;
        case 'Wood Frames':
          _widthCtrl.text = '42';
          _heightCtrl.text = '84';
          _leafType = 'Single Leaf';
          _carvingCtrl.text = 'Hand-Carved Teak Nilai Frame';
          break;
        case 'Hard Wood':
          _widthCtrl.text = '48';
          _heightCtrl.text = '96';
          _leafType = 'Single Leaf';
          _carvingCtrl.text = 'Seasoned A-Grade Burma Teak';
          break;
        default:
          _widthCtrl.text = '42';
          _heightCtrl.text = '84';
          _leafType = 'Single Leaf';
          _carvingCtrl.text = 'Custom Handcrafted Carving';
          break;
      }
    });
  }

  void _toggleDesign(int id) {
    setState(() {
      if (_selectedElements.containsKey(id)) {
        _selectedElements.remove(id);
      } else {
        if (_selectedElements.length >= 5) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Maximum 5 reference designs can be combined.')),
          );
          return;
        }
        // Automatically assign the first unused combine element among the 5 elements
        final used = _selectedElements.values.toSet();
        final defaultEl = AppConstants.combineElements.firstWhere(
          (el) => !used.contains(el),
          orElse: () => AppConstants.combineElements[_selectedElements.length % AppConstants.combineElements.length],
        );
        _selectedElements[id] = defaultEl;
      }
    });
  }

  /// Assigns [newElement] cleanly to [designId] as the LATEST selection:
  /// removes any earlier design holding the exact same element so designs
  /// never stack or conflict on top of each other.
  void _assignElement(int designId, String newElement) {
    setState(() {
      final duplicateIds = _selectedElements.entries
          .where((e) => e.key != designId && e.value == newElement)
          .map((e) => e.key)
          .toList();
      for (final oldId in duplicateIds) {
        _selectedElements.remove(oldId);
      }
      // Move updated design to the end so backend strictly treats it as the latest choice
      _selectedElements.remove(designId);
      _selectedElements[designId] = newElement;
    });
  }

  void _clearAllSelections() {
    setState(() {
      _selectedElements.clear();
      _aiImageUrl = null;
      _aiGuideImageUrl = null;
      _aiPromptUsed = null;
      _aiElementRegions = null;
      _aiBreakdownItems = [];
    });
  }

  Map<String, Rect>? _parseElementRegions(dynamic raw) {
    if (raw is! Map) return null;
    final out = <String, Rect>{};
    raw.forEach((key, val) {
      if (val is Map) {
        final x = (val['x'] as num?)?.toDouble();
        final y = (val['y'] as num?)?.toDouble();
        final w = (val['w'] as num?)?.toDouble();
        final h = (val['h'] as num?)?.toDouble();
        if (x != null && y != null && w != null && h != null) {
          out[key.toString()] = Rect.fromLTWH(x, y, w, h);
        }
      }
    });
    return out.isEmpty ? null : out;
  }

  List<PictorialElementItem> _buildBreakdownItems(dynamic serverBreakdown) {
    // Index server breakdown entries by key for metadata lookup, but strictly render
    // ONLY the elements explicitly selected by the user (1..5 images -> 1..5 sections).
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

    if (_selectedElements.isNotEmpty) {
      final selectedByKey = <String, PictorialElementItem>{};
      for (final e in _selectedElements.entries) {
        final did = e.key;
        final meta = CombineElementMeta.forLabel(e.value);
        final design = _catalog.cast<Map?>().firstWhere(
              (c) => c != null && c['id'] == did,
              orElse: () => null,
            );
        final srv = serverByKey[meta.key];
        final srvMatchesDesign = srv != null && int.tryParse('${srv['design_id']}') == did;

        final defaultDesc = meta.key == 'border'
            ? '$_polishShade wood tone, shine & inner border molding'
            : meta.defaultDescription;

        final rawTitle = design?['title']?.toString() ??
            (srvMatchesDesign ? srv['design_title']?.toString() : null) ??
            'Design #$did';
        final rawImg = design?['image_url']?.toString() ??
            (srvMatchesDesign ? srv['design_image_url']?.toString() : null) ??
            '';
        final desc = srvMatchesDesign
            ? (srv['description']?.toString() ?? defaultDesc)
            : defaultDesc;

        selectedByKey[meta.key] = PictorialElementItem(
          meta: meta,
          designId: did,
          designTitle: rawTitle,
          designImageUrl: ApiService.instance.mediaUrl(rawImg),
          isExplicit: true,
          description: desc,
        );
      }

      final result = selectedByKey.values.toList()
        ..sort((a, b) => a.meta.number.compareTo(b.meta.number));
      return result;
    }

    if (serverBreakdown is List && serverBreakdown.isNotEmpty) {
      final explicitOnly = serverBreakdown
          .whereType<Map>()
          .where((m) => m['is_explicit'] == true)
          .toList();
      final source = explicitOnly.isNotEmpty ? explicitOnly : serverBreakdown.whereType<Map>().toList();
      return source.map((raw) {
        final m = Map<String, dynamic>.from(raw);
        final key = (m['key'] ?? 'frame').toString();
        final meta = CombineElementMeta.forKey(key);
        return PictorialElementItem(
          meta: meta,
          designId: int.tryParse('${m['design_id']}') ?? 0,
          designTitle: (m['design_title'] ?? 'Catalog Design').toString(),
          designImageUrl: ApiService.instance.mediaUrl(m['design_image_url']?.toString()),
          isExplicit: true,
          description: (m['description'] ?? meta.defaultDescription).toString(),
        );
      }).toList()
        ..sort((a, b) => a.meta.number.compareTo(b.meta.number));
    }

    return [];
  }

  Future<void> _generateAiDesign() async {
    if (_selectedElements.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select 1 to 5 reference catalog designs first.')),
      );
      return;
    }

    setState(() => _generating = true);
    try {
      final refElements = _selectedElements.entries
          .map((e) => {'design_id': e.key, 'element': e.value})
          .toList();

      final res = await ApiService.instance.post('/catalog/ai-combine', {
        'reference_design_ids': _selectedElements.keys.toList(),
        'reference_elements': refElements,
        'woodwork_category': _category,
        'width_inches': double.tryParse(_widthCtrl.text) ?? 36,
        'height_inches': double.tryParse(_heightCtrl.text) ?? 84,
        'frame_section': _frameSection,
        'door_thickness': _doorThickness,
        'leaf_type': _leafType,
        'wood_species': _woodSpecies,
        'carving_pattern': _carvingCtrl.text.trim(),
        'polish_shade': _polishShade,
        'hardware': _hardwareCtrl.text.trim(),
        'quantity': int.tryParse(_qtyCtrl.text) ?? 1,
        'custom_notes': _notesCtrl.text.trim(),
      });

      setState(() {
        _aiImageUrl = res['ai_output_image_url']?.toString();
        _aiGuideImageUrl = res['ai_guide_image_url']?.toString();
        _aiPromptUsed = res['prompt_used']?.toString();
        _aiElementRegions = _parseElementRegions(res['element_regions']);
        _aiBreakdownItems = _buildBreakdownItems(res['element_breakdown']);
        _aiOutputAspect = (res['output_aspect'] as num?)?.toDouble() ?? 0.75;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  String _selectedProductionMemberName() {
    if (_selectedProductionUserId == null) return 'Production Team Workshop';
    final matched = _productionMembers.firstWhere(
      (m) => int.tryParse('${m['id']}') == _selectedProductionUserId,
      orElse: () => <String, dynamic>{},
    );
    return (matched['name'] ?? 'Production Team').toString();
  }

  Future<void> _submitOrderFlow() async {
    final custName = _custNameCtrl.text.trim();
    final custMobile = _custMobileCtrl.text.trim();
    if (custName.isEmpty || custMobile.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter Customer Name and valid 10-digit Mobile Number')),
      );
      return;
    }

    if (_productionMembers.isNotEmpty && _selectedProductionUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Production Team member to send this order to')),
      );
      return;
    }

    final place = _productionPlaceCtrl.text.trim();
    final memberName = _selectedProductionMemberName();

    // Step A: Review & click Done to save
    final confirmedDone = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.fact_check_rounded, color: AppTheme.woodPrimary),
            SizedBox(width: 8),
            Expanded(child: Text('Confirm Order Submission', style: TextStyle(fontSize: 16.5))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: $custName ($custMobile)', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Category: $_category • $_woodSpecies (${_widthCtrl.text}" × ${_heightCtrl.text}")'),
            const SizedBox(height: 6),
            Text('Send To (Production): $memberName',
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.woodPrimary)),
            const SizedBox(height: 4),
            Text('Production Place: ${place.isNotEmpty ? place : 'Optional — Not specified'}'),
            const SizedBox(height: 4),
            Text('Delivery Date: ${DateFormat('yyyy-MM-dd').format(_deliveryDate)} • $_priority'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Back')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check_circle_rounded, size: 18),
            label: const Text('Done'),
          ),
        ],
      ),
    );

    if (confirmedDone == true) {
      await _saveAndNotifyOrder();
    }
  }

  Future<void> _saveAndNotifyOrder() async {
    setState(() => _savingOrder = true);
    try {
      final refElements = _selectedElements.entries
          .map((e) => {'design_id': e.key, 'element': e.value})
          .toList();
      final place = _productionPlaceCtrl.text.trim();

      final res = await ApiService.instance.post('/orders', {
        'customer_name': _custNameCtrl.text.trim(),
        'customer_mobile': _custMobileCtrl.text.trim(),
        'delivery_address': _custAddressCtrl.text.trim(),
        'woodwork_category': _category,
        'width_inches': double.tryParse(_widthCtrl.text) ?? 36,
        'height_inches': double.tryParse(_heightCtrl.text) ?? 84,
        'frame_section': _frameSection,
        'door_thickness': _doorThickness,
        'leaf_type': _leafType,
        'wood_species': _woodSpecies,
        'carving_pattern': _carvingCtrl.text.trim(),
        'polish_shade': _polishShade,
        'hardware': _hardwareCtrl.text.trim(),
        'quantity': int.tryParse(_qtyCtrl.text) ?? 1,
        'custom_notes': _notesCtrl.text.trim(),
        'workshop_notes': _notesCtrl.text.trim(),
        'reference_design_ids': _selectedElements.keys.toList(),
        'reference_elements': refElements,
        'ai_output_image_url': _aiImageUrl ?? '',
        'assigned_production_user_id': _selectedProductionUserId,
        'production_place': place,
        'expected_delivery_date': DateFormat('yyyy-MM-dd').format(_deliveryDate),
        'priority': _priority,
        'is_dispatched': true,
      });

      final createdOrder = Map<String, dynamic>.from(res['order'] as Map);
      final breakdownItems = _aiBreakdownItems.isNotEmpty ? _aiBreakdownItems : _buildBreakdownItems(null);
      if ((createdOrder['element_breakdown'] as List?)?.isNotEmpty != true && breakdownItems.isNotEmpty) {
        createdOrder['element_breakdown'] = breakdownItems
            .map((it) => {
                  'number': it.meta.number,
                  'key': it.meta.key,
                  'label': it.meta.label,
                  'design_id': it.designId,
                  'design_title': it.designTitle,
                  'design_image_url': it.designImageUrl,
                  'is_explicit': it.isExplicit,
                  'description': it.description,
                })
            .toList();
      }
      if (createdOrder['element_regions'] == null && _aiElementRegions != null && _aiElementRegions!.isNotEmpty) {
        createdOrder['element_regions'] = _aiElementRegions!.map(
          (k, r) => MapEntry(k, {'x': r.left, 'y': r.top, 'w': r.width, 'h': r.height}),
        );
      }
      createdOrder['output_aspect'] ??= _aiOutputAspect;
      if ((createdOrder['ai_guide_image_url'] ?? '').toString().isEmpty &&
          _aiGuideImageUrl != null &&
          _aiGuideImageUrl!.isNotEmpty) {
        createdOrder['ai_guide_image_url'] = _aiGuideImageUrl;
      }
      if (!mounted) return;

      final assignedLabel = (createdOrder['assigned_production_user_name'] ?? _selectedProductionMemberName()).toString();
      final savedPlace = (createdOrder['production_place'] ?? place).toString().trim();

      setState(() {
        _lastSavedOrder = createdOrder;
        _custNameCtrl.clear();
        _custMobileCtrl.clear();
        _custAddressCtrl.clear();
        _productionPlaceCtrl.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.success,
          content: Text('Order ${createdOrder['job_id']} saved successfully & sent to $assignedLabel!'),
        ),
      );

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppTheme.success),
              const SizedBox(width: 8),
              Expanded(child: Text('Order ${createdOrder['job_id']} Saved!')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Order saved successfully and dispatched to the Production Team.',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Assigned Production Member: $assignedLabel'),
              if (savedPlace.isNotEmpty) Text('Production Place: $savedPlace'),
              const SizedBox(height: 8),
              Text('Customer can track live progress in the Customer App using mobile: ${createdOrder['customer_mobile']}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => PdfService.printCustomerCopy(createdOrder, context: ctx),
              child: const Text('Print Customer Copy'),
            ),
            TextButton(
              onPressed: () => PdfService.printWorkshopJobSheet(createdOrder, context: ctx),
              child: const Text('Print Workshop Sheet'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _savingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredCatalog = _filteredCatalog;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Step 1: Select Woodwork Category & Combine Catalog Designs
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '1. Combine $_category Designs (${_selectedElements.length}/5 selected)',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.woodDark),
                      ),
                    ),
                    if (_selectedElements.isNotEmpty)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.danger,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        onPressed: _clearAllSelections,
                        icon: const Icon(Icons.clear_all_rounded, size: 17),
                        label: const Text('Clear', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    IconButton(
                      tooltip: 'Refresh Catalog',
                      onPressed: _loadCatalog,
                      icon: const Icon(Icons.refresh_rounded, size: 20, color: AppTheme.woodPrimary),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Woodwork Category Tabs
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, idx) {
                      final cat = _categories[idx];
                      final isActive = _category == cat;
                      final count = _categoryCount(cat);
                      return ChoiceChip(
                        avatar: Icon(
                          _categoryIcon(cat),
                          size: 16,
                          color: isActive ? Colors.white : AppTheme.woodPrimary,
                        ),
                        label: Text(
                          '$cat ($count)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                            color: isActive ? Colors.white : AppTheme.woodDark,
                          ),
                        ),
                        selected: isActive,
                        showCheckmark: false,
                        selectedColor: AppTheme.woodPrimary,
                        backgroundColor: const Color(0xFFF6EFE6),
                        side: BorderSide(color: isActive ? AppTheme.woodPrimary : AppTheme.border),
                        onSelected: (_) => _selectCategory(cat),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),

                if (_loadingCatalog)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (filteredCatalog.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF6F0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      children: [
                        Icon(_categoryIcon(_category), size: 34, color: AppTheme.woodAccent),
                        const SizedBox(height: 8),
                        Text(
                          'No catalog designs uploaded under "$_category" yet.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.woodDark),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Ask Admin to upload designs for this category in the Admin Panel, then tap Refresh.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11.5, color: Colors.black54),
                        ),
                      ],
                    ),
                  )
                else
                  SizedBox(
                    height: 145,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: filteredCatalog.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        final d = Map<String, dynamic>.from(filteredCatalog[i] as Map);
                        final id = d['id'] as int;
                        final selected = _selectedElements.containsKey(id);
                        final elMeta = selected ? CombineElementMeta.forLabel(_selectedElements[id]!) : null;
                        return GestureDetector(
                          onTap: () => _toggleDesign(id),
                          child: Container(
                            width: 114,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected ? (elMeta?.color ?? AppTheme.woodPrimary) : AppTheme.border,
                                width: selected ? 2.5 : 1,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                Expanded(
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Container(
                                        color: Colors.white,
                                        padding: const EdgeInsets.all(4),
                                        child: Image.network(
                                          ApiService.instance.mediaUrl(d['image_url']?.toString()),
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) => const Icon(Icons.door_front_door),
                                        ),
                                      ),
                                      Positioned(
                                        top: 4,
                                        left: 4,
                                        child: GestureDetector(
                                          onTap: () => UiKit.showFullImagePopup(
                                            context,
                                            imageUrl: ApiService.instance.mediaUrl(d['image_url']?.toString()),
                                            title: '${d['title'] ?? ''}',
                                            subtitle: '${d['wood_species'] ?? ''} • ${d['category'] ?? ''}',
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.55),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.zoom_in_rounded, size: 13, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                      if (selected && elMeta != null)
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: Container(
                                            width: 24,
                                            height: 24,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: elMeta.color,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white, width: 1.8),
                                            ),
                                            child: Text(
                                              '${elMeta.number}',
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(5),
                                  child: Text('${d['title']}',
                                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                if (_selectedElements.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Specify element from each selected design (color-coded in output):',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.woodDark)),
                  const SizedBox(height: 8),
                  ..._selectedElements.entries.map((entry) {
                    final design = _catalog.firstWhere(
                      (c) => c['id'] == entry.key,
                      orElse: () => {'title': 'Design #${entry.key}', 'image_url': ''},
                    );
                    final meta = CombineElementMeta.forLabel(entry.value);
                    final thumbUrl = ApiService.instance.mediaUrl(design['image_url']?.toString());
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: meta.color.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: meta.color.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: meta.color, shape: BoxShape.circle),
                            child: Text(
                              '${meta.number}',
                              style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w900),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              width: 30,
                              height: 38,
                              color: Colors.white,
                              padding: const EdgeInsets.all(2),
                              child: thumbUrl.isNotEmpty
                                  ? Image.network(thumbUrl, fit: BoxFit.contain)
                                  : const Icon(Icons.door_front_door_rounded, size: 18),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${design['title']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 8),
                          DropdownButton<String>(
                            value: entry.value,
                            underline: const SizedBox.shrink(),
                            items: AppConstants.combineElements.map((el) {
                              final m = CombineElementMeta.forLabel(el);
                              return DropdownMenuItem(
                                value: el,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(color: m.color, shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 6),
                                    Text('${m.number}. $el', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) _assignElement(entry.key, v);
                            },
                          ),
                          IconButton(
                            tooltip: 'Remove design',
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            onPressed: () => setState(() => _selectedElements.remove(entry.key)),
                            icon: const Icon(Icons.close_rounded, size: 17, color: Colors.black45),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Step 2: Full Specifications
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('2. Full Woodwork Specifications',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.woodDark)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey('cat_$_category'),
                  initialValue: _categories.contains(_category) ? _category : (_categories.isNotEmpty ? _categories.first : null),
                  decoration: const InputDecoration(labelText: 'Woodwork Type'),
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) {
                    if (v != null) _selectCategory(v);
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _widthCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Width (inches)'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _heightCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Height (inches)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _frameSection,
                        decoration: const InputDecoration(labelText: 'Frame Section'),
                        items: AppConstants.frameSections.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                        onChanged: (v) => setState(() => _frameSection = v ?? _frameSection),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _doorThickness,
                        decoration: const InputDecoration(labelText: 'Door Thickness'),
                        items: AppConstants.doorThicknesses.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (v) => setState(() => _doorThickness = v ?? _doorThickness),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('leaf_$_leafType'),
                        initialValue: _leafType,
                        decoration: const InputDecoration(labelText: 'Leaf Type'),
                        items: const [
                          DropdownMenuItem(value: 'Single Leaf', child: Text('Single Leaf')),
                          DropdownMenuItem(value: 'Double Leaf', child: Text('Double Leaf')),
                        ],
                        onChanged: (v) => setState(() => _leafType = v ?? _leafType),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _woodSpecies,
                        decoration: const InputDecoration(labelText: 'Wood Species'),
                        items: AppConstants.woodSpecies.map((w) => DropdownMenuItem(value: w, child: Text(w))).toList(),
                        onChanged: (v) => setState(() => _woodSpecies = v ?? _woodSpecies),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _polishShade,
                  decoration: const InputDecoration(labelText: 'Color / Polish Shade'),
                  items: AppConstants.polishShades.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                  onChanged: (v) => setState(() => _polishShade = v ?? _polishShade),
                ),
                const SizedBox(height: 10),
                TextField(controller: _carvingCtrl, decoration: const InputDecoration(labelText: 'Carving Pattern')),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(controller: _hardwareCtrl, decoration: const InputDecoration(labelText: 'Hardware & Cutouts')),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _qtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Qty'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Custom / Workshop Notes'),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _generating ? null : _generateAiDesign,
                    icon: _generating
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: Text(_aiImageUrl == null ? 'Generate Unified AI $_category Design' : 'Regenerate AI Preview'),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Step 3: AI Output Result — Clean Final Combined Image + Section Details Breakdown
        if (_aiImageUrl != null) ...[
          const SizedBox(height: 12),

          // 3A. Clean Final Combined Output Image (NO boxes / lines / overlays)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '3. Final Combined Output',
                              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: AppTheme.woodDark),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Clean final combined door image — tap to inspect in full HD',
                              style: TextStyle(fontSize: 11.5, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => UiKit.showFullImagePopup(
                          context,
                          imageUrl: ApiService.instance.mediaUrl(_aiImageUrl),
                          title: 'Final Combined $_category Design',
                          subtitle: '$_woodSpecies • $_polishShade • $_leafType',
                          badge: 'FINAL OUTPUT',
                        ),
                        icon: const Icon(Icons.fullscreen_rounded, size: 17),
                        label: const Text('Full Size'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (ctx, box) {
                      final isWide = box.maxWidth > 620;
                      final previewHeight = isWide ? 540.0 : 440.0;
                      return MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => UiKit.showFullImagePopup(
                            context,
                            imageUrl: ApiService.instance.mediaUrl(_aiImageUrl),
                            title: 'Final Combined $_category Design',
                            subtitle: '$_woodSpecies • $_polishShade • $_leafType',
                            badge: 'FINAL OUTPUT',
                          ),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(horizontal: isWide ? 24 : 10, vertical: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF6F0),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Center(
                              child: Container(
                                height: previewHeight,
                                constraints: const BoxConstraints(maxWidth: 500),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppTheme.border),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.woodDark.withValues(alpha: 0.08),
                                      blurRadius: 18,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Image.network(
                                  ApiService.instance.mediaUrl(_aiImageUrl),
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.high,
                                  isAntiAlias: true,
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) return child;
                                    return const Center(child: CircularProgressIndicator());
                                  },
                                  errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(Icons.broken_image_outlined, size: 48, color: AppTheme.textMuted),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 3B. Section Details — 5 Elements Pictorial Breakdown
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Section Details — Style Source Guide',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.woodDark),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Shows which selected catalog design contributed each marked section',
                              style: TextStyle(fontSize: 11.5, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      if (_aiGuideImageUrl != null && _aiGuideImageUrl!.isNotEmpty)
                        ElevatedButton.icon(
                          onPressed: () => UiKit.showFullImagePopup(
                            context,
                            imageUrl: ApiService.instance.mediaUrl(_aiGuideImageUrl),
                            title: 'AI Combined $_category — 5 Elements Breakdown',
                            subtitle: '$_woodSpecies • $_polishShade • $_leafType',
                            badge: 'HD PICTORIAL GUIDE',
                          ),
                          icon: const Icon(Icons.account_tree_rounded, size: 16),
                          label: const Text('Full Guide'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DoorElementsPictorialCard(
                    category: _category,
                    polishShade: _polishShade,
                    generatedImageUrl: ApiService.instance.mediaUrl(_aiImageUrl),
                    items: _aiBreakdownItems.isNotEmpty ? _aiBreakdownItems : _buildBreakdownItems(null),
                    normalizedRegions: _aiElementRegions,
                    imageAspect: _aiOutputAspect,
                    onTapMainImage: () => UiKit.showFullImagePopup(
                      context,
                      imageUrl: ApiService.instance.mediaUrl(
                        (_aiGuideImageUrl != null && _aiGuideImageUrl!.isNotEmpty)
                            ? _aiGuideImageUrl
                            : _aiImageUrl,
                      ),
                      title: 'AI Combined $_category — 5 Elements Breakdown',
                      subtitle: '$_woodSpecies • $_polishShade • $_leafType',
                      badge: 'HD PICTORIAL GUIDE',
                    ),
                  ),
                  if (_aiPromptUsed != null) ...[
                    const SizedBox(height: 10),
                    Text(_aiPromptUsed!, style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
                  ],
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),

        // Step 4: Customer Details, Production Assignment & Submit (Zero Amounts)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('4. Customer Details & Send to Production',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.woodDark)),
                const Text('Customer mobile number automatically enables Customer App OTP login',
                    style: TextStyle(fontSize: 11.5, color: Colors.black54)),
                const SizedBox(height: 12),
                TextField(controller: _custNameCtrl, decoration: const InputDecoration(labelText: 'Customer Name *')),
                const SizedBox(height: 10),
                TextField(
                  controller: _custMobileCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Customer Mobile Number (10 digits) *'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _custAddressCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Delivery Address'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  key: ValueKey('prod_member_$_selectedProductionUserId'),
                  initialValue: _productionMembers.any((m) => int.tryParse('${m['id']}') == _selectedProductionUserId)
                      ? _selectedProductionUserId
                      : null,
                  decoration: InputDecoration(
                    labelText: 'Send to Production Team Member${_productionMembers.isNotEmpty ? ' *' : ''}',
                    prefixIcon: const Icon(Icons.engineering_rounded),
                  ),
                  hint: Text(_productionMembers.isEmpty
                      ? 'No active production members found'
                      : 'Select production team member'),
                  items: _productionMembers.map((m) {
                    final id = int.tryParse('${m['id']}') ?? 0;
                    final phone = (m['phone'] ?? '').toString().trim();
                    final label = phone.isNotEmpty ? '${m['name']} ($phone)' : '${m['name']}';
                    return DropdownMenuItem<int>(value: id, child: Text(label));
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedProductionUserId = v),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _productionPlaceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Production Place (Optional)',
                    hintText: 'e.g. Workshop Bay 2 / Timber Unit',
                    prefixIcon: Icon(Icons.location_city_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _deliveryDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) setState(() => _deliveryDate = picked);
                        },
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text('Delivery: ${DateFormat('yyyy-MM-dd').format(_deliveryDate)}'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    DropdownButton<String>(
                      value: _priority,
                      items: const [
                        DropdownMenuItem(value: 'Normal', child: Text('Normal')),
                        DropdownMenuItem(value: 'High', child: Text('High')),
                        DropdownMenuItem(value: 'Urgent', child: Text('Urgent')),
                      ],
                      onChanged: (v) => setState(() => _priority = v ?? 'Normal'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
                    onPressed: _savingOrder ? null : _submitOrderFlow,
                    icon: const Icon(Icons.send_rounded),
                    label: Text(_savingOrder ? 'Saving...' : 'Submit Order'),
                  ),
                ),
                if (_lastSavedOrder != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.success.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Saved: Order ${_lastSavedOrder!['job_id']} sent to ${_lastSavedOrder!['assigned_production_user_name'] ?? 'Production Team'}!',
                                style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.success, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => PdfService.printCustomerCopy(_lastSavedOrder!, context: context),
                              icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                              label: const Text('Customer Copy'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => PdfService.printWorkshopJobSheet(_lastSavedOrder!, context: context),
                              icon: const Icon(Icons.print_rounded, size: 16),
                              label: const Text('Workshop Sheet'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
