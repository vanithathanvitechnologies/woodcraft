import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_theme.dart';
import '../../core/constants.dart';
import '../../services/api_service.dart';
import '../../services/pdf_service.dart';

class AiCombinerTab extends StatefulWidget {
  const AiCombinerTab({super.key});

  @override
  State<AiCombinerTab> createState() => _AiCombinerTabState();
}

class _AiCombinerTabState extends State<AiCombinerTab> {
  final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  List<dynamic> _catalog = [];
  bool _loadingCatalog = true;

  // Selected 2-3 catalog designs + element per design
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
  String? _aiPromptUsed;

  // Customer & Billing
  final _custNameCtrl = TextEditingController();
  final _custMobileCtrl = TextEditingController();
  final _custAddressCtrl = TextEditingController();
  final _totalCostCtrl = TextEditingController(text: '55000');
  final _advanceCtrl = TextEditingController(text: '20000');
  String _priority = 'Normal';
  DateTime _deliveryDate = DateTime.now().add(const Duration(days: 14));
  bool _savingOrder = false;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    setState(() => _loadingCatalog = true);
    try {
      final res = await ApiService.instance.get('/catalog');
      setState(() => _catalog = (res['designs'] as List?) ?? []);
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
      case 'Main Door & Frame':
        return Icons.door_front_door_rounded;
      case 'Pooja Door':
        return Icons.temple_hindu_rounded;
      case 'Window':
        return Icons.window_rounded;
      case 'Wardrobe':
        return Icons.door_sliding_rounded;
      case 'Kitchen Cabinet':
        return Icons.kitchen_rounded;
      case 'Cot':
        return Icons.bed_rounded;
      default:
        return Icons.chair_rounded;
    }
  }

  void _selectCategory(String newCategory) {
    if (_category == newCategory) return;
    setState(() {
      _category = newCategory;
      _selectedElements.clear();
      _aiImageUrl = null;
      _aiPromptUsed = null;

      // Apply sensible default dimensions & carving hint for the chosen woodwork category
      switch (newCategory) {
        case 'Main Door & Frame':
          _widthCtrl.text = '42';
          _heightCtrl.text = '84';
          _leafType = 'Double Leaf';
          _carvingCtrl.text = 'Royal Lotus & Pillar Carving';
          break;
        case 'Pooja Door':
          _widthCtrl.text = '36';
          _heightCtrl.text = '78';
          _leafType = 'Double Leaf';
          _carvingCtrl.text = 'Traditional Temple Bells & Om Arch';
          break;
        case 'Window':
          _widthCtrl.text = '48';
          _heightCtrl.text = '48';
          _leafType = 'Double Leaf';
          _carvingCtrl.text = 'Beaded Border Arch Frame';
          break;
        case 'Wardrobe':
          _widthCtrl.text = '72';
          _heightCtrl.text = '84';
          _leafType = 'Double Leaf';
          _carvingCtrl.text = 'Minimalist Panel Grooves';
          break;
        case 'Kitchen Cabinet':
          _widthCtrl.text = '96';
          _heightCtrl.text = '30';
          _leafType = 'Double Leaf';
          _carvingCtrl.text = 'Clean Beveled Shutter Trim';
          break;
        case 'Cot':
          _widthCtrl.text = '72';
          _heightCtrl.text = '78';
          _leafType = 'Single Leaf';
          _carvingCtrl.text = 'Carved Heritage Headboard';
          break;
        default:
          _widthCtrl.text = '48';
          _heightCtrl.text = '36';
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
        if (_selectedElements.length >= 3) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Maximum 3 reference designs can be combined.')),
          );
          return;
        }
        final defaultEl = AppConstants.combineElements[_selectedElements.length % AppConstants.combineElements.length];
        _selectedElements[id] = defaultEl;
      }
    });
  }

  Future<void> _generateAiDesign() async {
    if (_selectedElements.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select 1 to 3 reference catalog designs first.')),
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
        _aiPromptUsed = res['prompt_used']?.toString();
        final est = res['cost_estimate'] as Map<String, dynamic>?;
        if (est != null) {
          _totalCostCtrl.text = '${est['total_estimated_cost']}';
        }
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _confirmAndDispatchOrder() async {
    if (_custNameCtrl.text.trim().isEmpty || _custMobileCtrl.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter Customer Name and valid 10-digit Mobile Number')),
      );
      return;
    }

    setState(() => _savingOrder = true);
    try {
      final refElements = _selectedElements.entries
          .map((e) => {'design_id': e.key, 'element': e.value})
          .toList();

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
        'total_cost': double.tryParse(_totalCostCtrl.text) ?? 0,
        'advance_amount': double.tryParse(_advanceCtrl.text) ?? 0,
        'expected_delivery_date': DateFormat('yyyy-MM-dd').format(_deliveryDate),
        'priority': _priority,
        'is_dispatched': true,
      });

      final createdOrder = Map<String, dynamic>.from(res['order'] as Map);
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Order ${createdOrder['job_id']} Dispatched!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Order saved & sent to Production Team Workshop.'),
              const SizedBox(height: 8),
              Text('Customer can now track live progress in the Customer App using mobile: ${createdOrder['customer_mobile']}'),
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
              child: const Text('Done'),
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
    final total = double.tryParse(_totalCostCtrl.text) ?? 0;
    final advance = double.tryParse(_advanceCtrl.text) ?? 0;
    final balance = (total - advance).clamp(0, double.infinity);
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
                        '1. Combine $_category Designs (${_selectedElements.length}/3 selected)',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.woodDark),
                      ),
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
                    itemCount: AppConstants.woodworkCategories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, idx) {
                      final cat = AppConstants.woodworkCategories[idx];
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
                          'Upload designs for this category in the Catalog tab, then tap Refresh.',
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
                        return GestureDetector(
                          onTap: () => _toggleDesign(id),
                          child: Container(
                            width: 110,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected ? AppTheme.woodPrimary : AppTheme.border,
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
                                      Image.network(
                                        ApiService.instance.mediaUrl(d['image_url']?.toString()),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(Icons.door_front_door),
                                      ),
                                      if (selected)
                                        const Positioned(
                                          top: 4,
                                          right: 4,
                                          child: CircleAvatar(
                                            radius: 12,
                                            backgroundColor: AppTheme.woodPrimary,
                                            child: Icon(Icons.check, size: 14, color: Colors.white),
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
                  const Text('Specify element from each selected design:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  ..._selectedElements.entries.map((entry) {
                    final design = _catalog.firstWhere((c) => c['id'] == entry.key, orElse: () => {'title': 'Design #${entry.key}'});
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(child: Text('${design['title']}', style: const TextStyle(fontSize: 12.5))),
                          const SizedBox(width: 8),
                          DropdownButton<String>(
                            value: entry.value,
                            items: AppConstants.combineElements
                                .map((el) => DropdownMenuItem(value: el, child: Text(el, style: const TextStyle(fontSize: 12))))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _selectedElements[entry.key] = v);
                            },
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
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Woodwork Type'),
                  items: AppConstants.woodworkCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
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

        // Step 3: AI Output Preview
        if (_aiImageUrl != null) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('3. AI Generated Design Preview',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.woodDark)),
                  const SizedBox(height: 10),
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        ApiService.instance.mediaUrl(_aiImageUrl),
                        height: 300,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  if (_aiPromptUsed != null) ...[
                    const SizedBox(height: 8),
                    Text(_aiPromptUsed!, style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
                  ],
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),

        // Step 4: Customer Details, Billing & One-Tap Dispatch
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('4. Customer Details, Billing & Dispatch',
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
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _totalCostCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(labelText: 'Total Cost (₹)'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _advanceCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(labelText: 'Advance Paid (₹)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Balance Payable: ${_inr.format(balance)}',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.danger)),
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
                    onPressed: _savingOrder ? null : _confirmAndDispatchOrder,
                    icon: const Icon(Icons.send),
                    label: Text(_savingOrder ? 'Saving...' : 'Confirm Order & Send to Production'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
