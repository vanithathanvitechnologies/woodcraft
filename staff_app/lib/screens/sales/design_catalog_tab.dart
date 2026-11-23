import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../core/app_theme.dart';
import '../../core/constants.dart';
import '../../services/api_service.dart';

class DesignCatalogTab extends StatefulWidget {
  const DesignCatalogTab({super.key});

  @override
  State<DesignCatalogTab> createState() => _DesignCatalogTabState();
}

class _DesignCatalogTabState extends State<DesignCatalogTab> {
  final _searchCtrl = TextEditingController();
  final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  String _selectedCategory = 'All';
  List<dynamic> _designs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.instance.get('/catalog');
      if (!mounted) return;
      setState(() => _designs = (res['designs'] as List?) ?? []);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<dynamic> get _visibleDesigns {
    final q = _searchCtrl.text.trim().toLowerCase();
    final selCat = _selectedCategory.trim().toLowerCase();
    return _designs.where((raw) {
      final d = raw as Map;
      if (_selectedCategory != 'All') {
        final cat = (d['category'] ?? '').toString().trim().toLowerCase();
        if (cat != selCat) return false;
      }
      if (q.isNotEmpty) {
        final hay =
            '${d['title'] ?? ''} ${d['carving_style'] ?? ''} ${d['tags'] ?? ''} ${d['wood_species'] ?? ''} ${d['category'] ?? ''}'
                .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  void _showUploadDialog() {
    final titleCtrl = TextEditingController();
    final carvingCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: '32000');
    final tagsCtrl = TextEditingController();
    String category = AppConstants.woodworkCategories.first;
    String wood = AppConstants.woodSpecies.first;
    bool trending = false;
    XFile? pickedFile;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Upload Door / Woodwork Design'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final picker = ImagePicker();
                    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                    if (img != null) setModalState(() => pickedFile = img);
                  },
                  icon: const Icon(Icons.photo_library),
                  label: Text(pickedFile == null ? 'Pick Design Photo' : 'Selected: ${pickedFile!.name}'),
                ),
                const SizedBox(height: 10),
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Design Title *')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Woodwork Category'),
                  items: AppConstants.woodworkCategories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setModalState(() => category = v ?? category),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: wood,
                  decoration: const InputDecoration(labelText: 'Wood Species'),
                  items: AppConstants.woodSpecies
                      .map((w) => DropdownMenuItem(value: w, child: Text(w)))
                      .toList(),
                  onChanged: (v) => setModalState(() => wood = v ?? wood),
                ),
                const SizedBox(height: 10),
                TextField(controller: carvingCtrl, decoration: const InputDecoration(labelText: 'Carving Style')),
                const SizedBox(height: 10),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Base Price (₹)'),
                ),
                const SizedBox(height: 10),
                TextField(controller: tagsCtrl, decoration: const InputDecoration(labelText: 'Tags (comma separated)')),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Highlight as Trending'),
                  value: trending,
                  onChanged: (v) => setModalState(() => trending = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                try {
                  if (pickedFile != null) {
                    final bytes = await pickedFile!.readAsBytes();
                    await ApiService.instance.uploadMultipart(
                      endpoint: '/catalog',
                      fileField: 'images',
                      fileBytes: bytes,
                      filename: pickedFile!.name,
                      fields: {
                        'title': titleCtrl.text.trim(),
                        'category': category,
                        'wood_species': wood,
                        'carving_style': carvingCtrl.text.trim(),
                        'base_price': priceCtrl.text.trim(),
                        'tags': tagsCtrl.text.trim(),
                        'is_trending': trending ? '1' : '0',
                      },
                    );
                  } else {
                    await ApiService.instance.post('/catalog', {
                      'title': titleCtrl.text.trim(),
                      'category': category,
                      'wood_species': wood,
                      'carving_style': carvingCtrl.text.trim(),
                      'base_price': double.tryParse(priceCtrl.text) ?? 25000,
                      'tags': tagsCtrl.text.trim(),
                      'is_trending': trending,
                    });
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                }
              },
              child: const Text('Save Design'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleTrending(Map<String, dynamic> d) async {
    await ApiService.instance.put('/catalog/${d['id']}', {'is_trending': d['is_trending'] != 1});
    _load();
  }

  Future<void> _archiveDesign(Map<String, dynamic> d) async {
    await ApiService.instance.delete('/catalog/${d['id']}');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.woodPrimary,
        foregroundColor: Colors.white,
        onPressed: _showUploadDialog,
        icon: const Icon(Icons.add_photo_alternate),
        label: const Text('Upload Design'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Search style, wood, tags...',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: AppTheme.woodPrimary),
                  tooltip: 'Refresh Catalog',
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: ['All', ...AppConstants.woodworkCategories].map((c) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(c),
                    selected: _selectedCategory == c,
                    onSelected: (_) {
                      setState(() => _selectedCategory = c);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: LayoutBuilder(
                      builder: (ctx, constraints) {
                        final visible = _visibleDesigns;
                        if (visible.isEmpty) {
                          return ListView(
                            children: const [
                              SizedBox(height: 80),
                              Center(
                                child: Text(
                                  'No designs found in this category.',
                                  style: TextStyle(color: Colors.black54, fontSize: 14),
                                ),
                              ),
                            ],
                          );
                        }
                        final cols = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 600 ? 3 : 2);
                        return GridView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cols,
                            mainAxisExtent: 265,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      itemCount: visible.length,
                      itemBuilder: (_, i) {
                        final d = Map<String, dynamic>.from(visible[i] as Map);
                        final isTrending = d['is_trending'] == 1;
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.network(
                                      ApiService.instance.mediaUrl(d['image_url']?.toString()),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: Colors.brown.shade50,
                                        child: const Icon(Icons.door_front_door, size: 48, color: AppTheme.woodPrimary),
                                      ),
                                    ),
                                    if (isTrending)
                                      Positioned(
                                        top: 8,
                                        left: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppTheme.brass,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Text('TRENDING',
                                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.white)),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${d['title']}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                    Text('${d['wood_species']} • ${d['category']}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11, color: Colors.black54)),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(_inr.format(double.tryParse('${d['base_price']}') ?? 0),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w800, color: AppTheme.woodPrimary)),
                                        Row(
                                          children: [
                                            InkWell(
                                              onTap: () => _toggleTrending(d),
                                              child: Icon(
                                                isTrending ? Icons.star : Icons.star_border,
                                                size: 18,
                                                color: AppTheme.brass,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            InkWell(
                                              onTap: () => _archiveDesign(d),
                                              child: const Icon(Icons.archive_outlined, size: 18, color: Colors.black45),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
