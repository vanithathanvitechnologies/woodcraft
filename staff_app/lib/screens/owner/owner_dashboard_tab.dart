import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../services/api_service.dart';
import '../../widgets/ui_kit.dart';

class OwnerDashboardTab extends StatefulWidget {
  final void Function(int tabIndex, {String? ordersFilter}) onNavigateTab;
  const OwnerDashboardTab({super.key, required this.onNavigateTab});

  @override
  State<OwnerDashboardTab> createState() => _OwnerDashboardTabState();
}

class _OwnerDashboardTabState extends State<OwnerDashboardTab> {
  Map<String, dynamic>? _kpis;
  List<Map<String, dynamic>> _pendingOrders = [];
  List<Map<String, dynamic>> _dueReachedOrders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.instance.get('/reports/summary'),
        ApiService.instance.get('/orders?pending_only=true'),
      ]);
      final rawPending = (results[1]['orders'] as List?) ?? [];
      final pendingList = rawPending.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      final reachedList = pendingList
          .where((o) => o['is_delivery_reached'] == true || o['is_delayed'] == true)
          .toList();

      setState(() {
        _kpis = Map<String, dynamic>.from(results[0]['kpis'] as Map);
        _pendingOrders = pendingList;
        _dueReachedOrders = reachedList;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _orderPreviewCard(Map<String, dynamic> o, {required bool highlightDueReached}) {
    final stage = int.tryParse('${o['current_stage']}') ?? 1;
    final prodMember = (o['assigned_production_user_name'] ?? '').toString().trim();
    final prodPlace = (o['production_place'] ?? '').toString().trim();
    final custAddr = (o['customer_address'] ?? '').toString().trim();
    final custMobile = (o['customer_mobile'] ?? '').toString().trim();
    final areaText = UiKit.formatAreaSqFt(o['width_inches'], o['height_inches']);
    final lastProgressText = UiKit.formatDateTime(o['last_progress_at'] ?? o['updated_at']);
    final daysLeft = int.tryParse('${o['days_left']}') ?? 0;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => widget.onNavigateTab(1, ordersFilter: highlightDueReached ? 'due_reached' : 'pending'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: highlightDueReached ? const Color(0xFFFFF5F5) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: highlightDueReached ? AppTheme.danger.withValues(alpha: 0.45) : AppTheme.border,
          ),
          boxShadow: [
            BoxShadow(color: AppTheme.woodDark.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 50,
                height: 68,
                padding: const EdgeInsets.all(2),
                color: Colors.white,
                child: (o['ai_output_image_url'] ?? '').toString().isNotEmpty
                    ? Image.network(
                        ApiService.instance.mediaUrl(o['ai_output_image_url'].toString()),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.door_front_door_rounded, color: AppTheme.woodPrimary),
                      )
                    : const Icon(Icons.door_front_door_rounded, color: AppTheme.woodPrimary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('#${o['job_id']}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.woodDark)),
                      if (highlightDueReached) ...[
                        const SizedBox(width: 8),
                        UiKit.iconChip(
                          Icons.warning_amber_rounded,
                          daysLeft == 0 ? 'Reached Today' : 'Overdue ${daysLeft.abs()}d',
                          color: AppTheme.danger,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${o['customer_name']} • ${o['woodwork_category']} (${o['wood_species']})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: [
                      UiKit.iconChip(
                        UiKit.stageIcon(stage),
                        'Stage $stage/8 • ${o['current_stage_name']}',
                        color: stage >= 4 ? AppTheme.warning : AppTheme.info,
                      ),
                      UiKit.iconChip(
                        Icons.event_available_rounded,
                        'Delivery: ${o['expected_delivery_date'] ?? '-'}',
                        color: highlightDueReached ? AppTheme.danger : AppTheme.woodPrimary,
                      ),
                      if (custMobile.isNotEmpty)
                        UiKit.iconChip(Icons.phone_rounded, custMobile, color: AppTheme.info),
                      UiKit.iconChip(
                        Icons.straighten_rounded,
                        'Area: ${o['width_inches']}"×${o['height_inches']}" ($areaText)',
                        color: AppTheme.woodDark,
                      ),
                      if (custAddr.isNotEmpty)
                        UiKit.iconChip(Icons.location_on_rounded, 'Location: $custAddr', color: AppTheme.textMuted),
                      UiKit.iconChip(Icons.update_rounded, 'Last Progress: $lastProgressText', color: AppTheme.woodAccent),
                      if (prodMember.isNotEmpty)
                        UiKit.iconChip(Icons.engineering_rounded, prodMember, color: AppTheme.woodPrimary),
                      if (prodPlace.isNotEmpty)
                        UiKit.iconChip(Icons.location_city_rounded, prodPlace, color: AppTheme.info),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final k = _kpis ?? {};
    final pendingCount = int.tryParse('${k['pending_orders'] ?? k['active_orders']}') ?? _pendingOrders.length;
    final dueReachedCount =
        int.tryParse('${k['delivery_reached_incomplete_orders'] ?? k['delayed_orders']}') ?? _dueReachedOrders.length;
    final dueSoonCount = int.tryParse('${k['due_soon_orders']}') ?? 0;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (dueReachedCount > 0 || dueSoonCount > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: dueReachedCount > 0 ? const Color(0xFFFDECEC) : const Color(0xFFFFF5EB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (dueReachedCount > 0 ? AppTheme.danger : AppTheme.warning).withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    dueReachedCount > 0 ? Icons.warning_amber_rounded : Icons.notifications_active_rounded,
                    color: dueReachedCount > 0 ? AppTheme.danger : AppTheme.warning,
                    size: 26,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dueReachedCount > 0
                              ? '$dueReachedCount Incomplete Order(s) Reached Delivery Date'
                              : '$dueSoonCount Order(s) Due Within 2 Days',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                            color: dueReachedCount > 0 ? AppTheme.danger : AppTheme.woodDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${dueReachedCount > 0 ? "$dueSoonCount due within 2 days • " : ""}Tap to review incomplete deliveries',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => widget.onNavigateTab(1, ordersFilter: dueReachedCount > 0 ? 'due_reached' : 'pending'),
                    child: const Text('View', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),

          // KPI Cards Grid (No amount/revenue details shown)
          LayoutBuilder(
            builder: (ctx, constraints) {
              final cols = constraints.maxWidth > 700 ? 4 : 2;
              return GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisExtent: 132,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                children: [
                  _pastelTile(
                    icon: Icons.hourglass_bottom_rounded,
                    iconBg: const Color(0xFFFFF1E0),
                    iconColor: const Color(0xFFEA580C),
                    title: 'Pending Orders',
                    value: '$pendingCount',
                    onTap: () => widget.onNavigateTab(1, ordersFilter: 'pending'),
                  ),
                  _pastelTile(
                    icon: Icons.warning_amber_rounded,
                    iconBg: const Color(0xFFFDECEC),
                    iconColor: AppTheme.danger,
                    title: 'Delivery Reached',
                    value: '$dueReachedCount',
                    onTap: () => widget.onNavigateTab(1, ordersFilter: 'due_reached'),
                  ),
                  _pastelTile(
                    icon: Icons.verified_rounded,
                    iconBg: const Color(0xFFE7F7EE),
                    iconColor: const Color(0xFF16A34A),
                    title: 'Completed',
                    value: '${k['completed_orders'] ?? 0}',
                    onTap: () => widget.onNavigateTab(1, ordersFilter: 'completed'),
                  ),
                  _pastelTile(
                    icon: Icons.inventory_2_rounded,
                    iconBg: const Color(0xFFE8F1FD),
                    iconColor: const Color(0xFF2563EB),
                    title: 'Total Orders',
                    value: '${k['total_orders'] ?? 0}',
                    onTap: () => widget.onNavigateTab(1, ordersFilter: 'all'),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),

          // Section 1: Delivery Date Reached (Not Completed)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: UiKit.sectionHeader(
                  Icons.warning_amber_rounded,
                  'Delivery Date Reached (Not Completed) (${_dueReachedOrders.length})',
                ),
              ),
              TextButton(
                onPressed: () => widget.onNavigateTab(1, ordersFilter: 'due_reached'),
                child: const Text('All ->', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_dueReachedOrders.isEmpty)
            UiKit.cardContainer(
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: AppTheme.success),
                  SizedBox(width: 10),
                  Expanded(child: Text('No overdue or due-today incomplete orders right now.')),
                ],
              ),
            )
          else
            ..._dueReachedOrders.take(6).map((o) => _orderPreviewCard(o, highlightDueReached: true)),

          const SizedBox(height: 14),

          // Section 2: Pending Orders
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: UiKit.sectionHeader(
                  Icons.hourglass_bottom_rounded,
                  'Pending Orders (${_pendingOrders.length})',
                ),
              ),
              TextButton(
                onPressed: () => widget.onNavigateTab(1, ordersFilter: 'pending'),
                child: const Text('View All ->', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_pendingOrders.isEmpty)
            UiKit.cardContainer(child: const Center(child: Text('All orders are completed!')))
          else
            ..._pendingOrders.take(8).map((o) => _orderPreviewCard(o, highlightDueReached: o['is_delivery_reached'] == true)),
        ],
      ),
    );
  }

  Widget _pastelTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(color: AppTheme.woodDark.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, size: 22, color: iconColor),
            ),
            const SizedBox(height: 8),
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textMuted)),
            const SizedBox(height: 2),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.woodDark)),
          ],
        ),
      ),
    );
  }
}
