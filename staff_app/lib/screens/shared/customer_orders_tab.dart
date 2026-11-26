import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/pdf_service.dart';
import '../../widgets/ui_kit.dart';

class CustomerOrdersTab extends StatefulWidget {
  final String initialFilter; // 'all' | 'pending' | 'due_reached' | 'completed'
  const CustomerOrdersTab({super.key, this.initialFilter = 'all'});

  @override
  State<CustomerOrdersTab> createState() => _CustomerOrdersTabState();
}

class _CustomerOrdersTabState extends State<CustomerOrdersTab> {
  final _searchCtrl = TextEditingController();
  late String _statusFilter;
  List<dynamic> _orders = [];
  List<Map<String, dynamic>> _productionMembers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _statusFilter = widget.initialFilter;
    _load();
  }

  @override
  void didUpdateWidget(covariant CustomerOrdersTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFilter != widget.initialFilter && widget.initialFilter != _statusFilter) {
      _statusFilter = widget.initialFilter;
      _load();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final params = <String>[];
      final q = _searchCtrl.text.trim();
      if (q.isNotEmpty) params.add('search=${Uri.encodeQueryComponent(q)}');
      if (_statusFilter == 'pending') params.add('pending_only=true');
      if (_statusFilter == 'due_reached') params.add('due_reached_only=true');
      if (_statusFilter == 'completed') params.add('completed_only=true');
      final qs = params.isNotEmpty ? '?${params.join('&')}' : '';

      final ordersFuture = ApiService.instance.get('/orders$qs');
      final teamFuture = ApiService.instance
          .get('/production/team')
          .catchError((_) => <String, dynamic>{});

      final results = await Future.wait([ordersFuture, teamFuture]);
      if (!mounted) return;
      final rawTeam = (results[1]['members'] as List?) ?? [];
      setState(() {
        _orders = (results[0]['orders'] as List?) ?? [];
        _productionMembers = rawTeam.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openOrderActions(int orderId) async {
    try {
      final res = await ApiService.instance.get('/orders/$orderId');
      final order = Map<String, dynamic>.from(res['order'] as Map);
      if (!mounted) return;

      int? selectedProdId = int.tryParse('${order['assigned_production_user_id']}');
      final placeCtrl = TextEditingController(text: (order['production_place'] ?? '').toString());
      bool savingAssign = false;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setModalState) => Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MouseRegion(
                        cursor: (order['ai_output_image_url'] ?? '').toString().isNotEmpty
                            ? SystemMouseCursors.click
                            : MouseCursor.defer,
                        child: GestureDetector(
                          onTap: (order['ai_output_image_url'] ?? '').toString().isNotEmpty
                              ? () => UiKit.showFullImagePopup(
                                    ctx,
                                    imageUrl: ApiService.instance.mediaUrl(order['ai_output_image_url'].toString()),
                                    title: '${order['job_id']} • ${order['woodwork_category']}',
                                    subtitle: '${order['wood_species']} • ${order['width_inches']}"×${order['height_inches']}"',
                                  )
                              : null,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 78,
                              height: 112,
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: (order['ai_output_image_url'] ?? '').toString().isNotEmpty
                                  ? Image.network(
                                      ApiService.instance.mediaUrl(order['ai_output_image_url'].toString()),
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.door_front_door_rounded, size: 38),
                                    )
                                  : const Icon(Icons.door_front_door_rounded, size: 38),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(color: AppTheme.woodDark, borderRadius: BorderRadius.circular(8)),
                              child: Text('${order['job_id']}',
                                  style: const TextStyle(color: AppTheme.brass, fontWeight: FontWeight.w800, fontSize: 12)),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.person_rounded, size: 15, color: AppTheme.woodPrimary),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text('${order['customer_name']}',
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                const Icon(Icons.phone_rounded, size: 14, color: AppTheme.info),
                                const SizedBox(width: 5),
                                Text('${order['customer_mobile']}', style: const TextStyle(fontSize: 12.5)),
                              ],
                            ),
                            if ((order['customer_address'] ?? '').toString().isNotEmpty)
                              Row(
                                children: [
                                  const Icon(Icons.location_on_rounded, size: 14, color: AppTheme.textMuted),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text('${order['customer_address']}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      UiKit.iconChip(Icons.door_front_door_rounded, '${order['woodwork_category']}'),
                      UiKit.iconChip(Icons.forest_rounded, '${order['wood_species']}', color: AppTheme.woodAccent),
                      UiKit.iconChip(Icons.straighten_rounded, '${order['width_inches']}"×${order['height_inches']}"'),
                      UiKit.iconChip(Icons.event_available_rounded, '${order['expected_delivery_date']}', color: AppTheme.warning),
                      UiKit.iconChip(
                        UiKit.stageIcon(int.tryParse('${order['current_stage']}') ?? 1),
                        'Stage ${order['current_stage']}/8 • ${order['current_stage_name']}',
                        color: (int.tryParse('${order['current_stage']}') ?? 1) == 8 ? AppTheme.success : AppTheme.woodPrimary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Production Team Member & Place Assignment
                  UiKit.sectionHeader(Icons.engineering_rounded, 'Production Assignment & Place'),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    key: ValueKey('assign_prod_$selectedProdId'),
                    initialValue: _productionMembers.any((m) => int.tryParse('${m['id']}') == selectedProdId)
                        ? selectedProdId
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Production Team Member',
                      prefixIcon: Icon(Icons.person_pin_rounded),
                    ),
                    items: _productionMembers
                        .map((m) => DropdownMenuItem<int>(
                              value: int.tryParse('${m['id']}'),
                              child: Text('${m['name']}'),
                            ))
                        .toList(),
                    onChanged: (v) => setModalState(() => selectedProdId = v),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: placeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Production Place (Optional)',
                      prefixIcon: Icon(Icons.location_city_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: savingAssign
                          ? null
                          : () async {
                              setModalState(() => savingAssign = true);
                              try {
                                await ApiService.instance.patch('/production/jobs/${order['id']}/assign', {
                                  'assigned_production_user_id': selectedProdId,
                                  'production_place': placeCtrl.text.trim(),
                                });
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: AppTheme.success,
                                      content: Text('Assignment saved for ${order['job_id']}'),
                                    ),
                                  );
                                }
                                _load();
                              } catch (e) {
                                setModalState(() => savingAssign = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                                }
                              }
                            },
                      icon: const Icon(Icons.save_rounded, size: 18),
                      label: Text(savingAssign ? 'Saving...' : 'Save Production Assignment'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  UiKit.sectionHeader(Icons.picture_as_pdf_rounded, 'PDF Print & Dispatch'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => PdfService.printCustomerCopy(order, context: context),
                          icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                          label: const Text('Customer Copy'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => PdfService.printWorkshopJobSheet(order, context: context),
                          icon: const Icon(Icons.print_rounded, size: 18),
                          label: const Text('Workshop Sheet'),
                        ),
                      ),
                    ],
                  ),
                  if (order['is_dispatched'] != 1) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
                        onPressed: () async {
                          await ApiService.instance.post('/orders/${order['id']}/dispatch', {
                            'assigned_production_user_id': selectedProdId,
                            'production_place': placeCtrl.text.trim(),
                          });
                          if (ctx.mounted) Navigator.pop(ctx);
                          _load();
                        },
                        icon: const Icon(Icons.send_rounded),
                        label: const Text('Send to Production Team'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Widget _filterChip(String key, String label, IconData icon) {
    final selected = _statusFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: Icon(icon, size: 15, color: selected ? Colors.white : AppTheme.woodPrimary),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppTheme.woodDark,
          ),
        ),
        selected: selected,
        showCheckmark: false,
        selectedColor: key == 'due_reached' ? AppTheme.danger : AppTheme.woodPrimary,
        onSelected: (_) {
          setState(() => _statusFilter = key);
          _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onSubmitted: (_) => _load(),
                  decoration: const InputDecoration(
                    hintText: 'Search Job ID, customer, mobile, place...',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: AppTheme.woodPrimary),
                onPressed: _load,
                icon: const Icon(Icons.search_rounded, color: Colors.white),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: [
              _filterChip('all', 'All Orders', Icons.list_alt_rounded),
              _filterChip('pending', 'Pending', Icons.hourglass_bottom_rounded),
              _filterChip('due_reached', 'Delivery Reached', Icons.warning_amber_rounded),
              _filterChip('completed', 'Completed', Icons.verified_rounded),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _orders.isEmpty
                  ? const Center(child: Text('No orders match this filter.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(14),
                        itemCount: _orders.length,
                        itemBuilder: (_, i) {
                          final o = Map<String, dynamic>.from(_orders[i] as Map);
                          final stage = int.tryParse('${o['current_stage']}') ?? 1;
                          final isReached = o['is_delivery_reached'] == true || o['is_delayed'] == true;
                          final isDueSoon = o['is_due_soon'] == true;
                          final prodMember = (o['assigned_production_user_name'] ?? '').toString().trim();
                          final prodPlace = (o['production_place'] ?? '').toString().trim();
                          final custAddr = (o['customer_address'] ?? '').toString().trim();
                          final areaText = UiKit.formatAreaSqFt(o['width_inches'], o['height_inches']);
                          final lastProgressText = UiKit.formatDateTime(o['last_progress_at'] ?? o['updated_at']);
                          final daysLeft = int.tryParse('${o['days_left']}') ?? 0;

                          return InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => _openOrderActions(o['id'] as int),
                            child: UiKit.cardContainer(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          width: 58,
                                          height: 82,
                                          padding: const EdgeInsets.all(3),
                                          color: Colors.white,
                                          child: (o['ai_output_image_url'] ?? '').toString().isNotEmpty
                                              ? Image.network(
                                                  ApiService.instance.mediaUrl(o['ai_output_image_url'].toString()),
                                                  fit: BoxFit.contain,
                                                  errorBuilder: (_, __, ___) =>
                                                      const Icon(Icons.door_front_door_rounded, size: 32, color: AppTheme.woodPrimary),
                                                )
                                              : const Icon(Icons.door_front_door_rounded, size: 32, color: AppTheme.woodPrimary),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.woodDark,
                                                    borderRadius: BorderRadius.circular(7),
                                                  ),
                                                  child: Text('${o['job_id']}',
                                                      style: const TextStyle(
                                                          color: AppTheme.brass, fontWeight: FontWeight.w800, fontSize: 11)),
                                                ),
                                                const SizedBox(width: 6),
                                                if (isReached)
                                                  UiKit.iconChip(
                                                    Icons.warning_amber_rounded,
                                                    daysLeft == 0 ? 'Due Today' : 'Overdue ${daysLeft.abs()}d',
                                                    color: AppTheme.danger,
                                                  )
                                                else if (isDueSoon)
                                                  UiKit.iconChip(Icons.schedule_rounded, 'Due in ${daysLeft}d', color: AppTheme.warning),
                                                const Spacer(),
                                                const Icon(Icons.picture_as_pdf_rounded, size: 18, color: AppTheme.woodPrimary),
                                              ],
                                            ),
                                            const SizedBox(height: 5),
                                            Text('${o['customer_name']}',
                                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.textDark)),
                                            const SizedBox(height: 4),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 5,
                                              children: [
                                                UiKit.iconChip(Icons.phone_rounded, '${o['customer_mobile']}', color: AppTheme.info),
                                                UiKit.iconChip(Icons.forest_rounded, '${o['wood_species']}'),
                                                UiKit.iconChip(UiKit.stageIcon(stage), '${o['current_stage_name']}',
                                                    color: stage == 8 ? AppTheme.success : AppTheme.woodAccent),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      UiKit.iconChip(
                                        Icons.engineering_rounded,
                                        prodMember.isNotEmpty ? 'Prod: $prodMember' : 'Unassigned',
                                        color: AppTheme.woodPrimary,
                                      ),
                                      if (prodPlace.isNotEmpty)
                                        UiKit.iconChip(Icons.location_city_rounded, prodPlace, color: AppTheme.info),
                                      UiKit.iconChip(
                                        Icons.event_available_rounded,
                                        'Delivery: ${o['expected_delivery_date']}',
                                        color: isReached ? AppTheme.danger : AppTheme.textMuted,
                                      ),
                                      UiKit.iconChip(
                                        Icons.straighten_rounded,
                                        'Area: ${o['width_inches']}"×${o['height_inches']}" ($areaText)',
                                        color: AppTheme.woodDark,
                                      ),
                                      if (custAddr.isNotEmpty)
                                        UiKit.iconChip(Icons.location_on_rounded, 'Location: $custAddr', color: AppTheme.textMuted),
                                      UiKit.iconChip(
                                        Icons.update_rounded,
                                        'Last Progress: $lastProgressText',
                                        color: AppTheme.woodAccent,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}
