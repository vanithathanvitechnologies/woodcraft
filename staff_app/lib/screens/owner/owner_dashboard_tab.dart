import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_theme.dart';
import '../../services/api_service.dart';
import '../../widgets/ui_kit.dart';

class OwnerDashboardTab extends StatefulWidget {
  final void Function(int tabIndex) onNavigateTab;
  const OwnerDashboardTab({super.key, required this.onNavigateTab});

  @override
  State<OwnerDashboardTab> createState() => _OwnerDashboardTabState();
}

class _OwnerDashboardTabState extends State<OwnerDashboardTab> {
  final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  Map<String, dynamic>? _kpis;
  List<dynamic> _recentOrders = [];
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
        ApiService.instance.get('/orders'),
      ]);
      setState(() {
        _kpis = Map<String, dynamic>.from(results[0]['kpis'] as Map);
        _recentOrders = ((results[1]['orders'] as List?) ?? []).take(5).toList();
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final k = _kpis ?? {};

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Total Orders Hero Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.border),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.woodDark.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Orders',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textMuted)),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${k['total_orders'] ?? 0}',
                            style: const TextStyle(
                                fontSize: 32, fontWeight: FontWeight.w900, color: AppTheme.woodDark, height: 1),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _inr.format(double.tryParse('${k['total_revenue']}') ?? 0),
                              style: const TextStyle(
                                  fontSize: 11.5, fontWeight: FontWeight.w800, color: AppTheme.success),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1E0),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.trending_up_rounded, color: Color(0xFFEA580C), size: 30),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Quick Navigation KPI Cards Grid
          LayoutBuilder(
            builder: (ctx, constraints) {
              final cols = constraints.maxWidth > 700 ? 4 : 2;
              return GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisExtent: 134,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                children: [
                  _pastelTile(
                    icon: Icons.people_alt_rounded,
                    iconBg: const Color(0xFFE8F1FD),
                    iconColor: const Color(0xFF2563EB),
                    title: 'Customers',
                    value: '${k['total_customers'] ?? 0}',
                    onTap: () => widget.onNavigateTab(1),
                  ),
                  _pastelTile(
                    icon: Icons.receipt_long_rounded,
                    iconBg: const Color(0xFFFFF1E0),
                    iconColor: const Color(0xFFEA580C),
                    title: 'Live Orders',
                    value: '${k['active_orders'] ?? 0}',
                    onTap: () => widget.onNavigateTab(2),
                  ),
                  _pastelTile(
                    icon: Icons.settings_suggest_rounded,
                    iconBg: const Color(0xFFFEF6DC),
                    iconColor: const Color(0xFFD97706),
                    title: 'Completed',
                    value: '${k['completed_orders'] ?? 0}',
                    onTap: () => widget.onNavigateTab(2),
                  ),
                  _pastelTile(
                    icon: Icons.bar_chart_rounded,
                    iconBg: const Color(0xFFE7F7EE),
                    iconColor: const Color(0xFF16A34A),
                    title: 'Reports',
                    value: 'View',
                    onTap: () => widget.onNavigateTab(3),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),

          // Recent Orders Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Orders',
                  style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: AppTheme.woodDark)),
              TextButton(
                onPressed: () => widget.onNavigateTab(1),
                child: const Text('View All ->', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_recentOrders.isEmpty)
            UiKit.cardContainer(child: const Center(child: Text('No orders yet.')))
          else
            ..._recentOrders.map((raw) {
              final o = Map<String, dynamic>.from(raw as Map);
              final stage = int.tryParse('${o['current_stage']}') ?? 1;
              final statusColor = stage == 8 ? AppTheme.success : (stage >= 4 ? AppTheme.warning : AppTheme.info);
              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => widget.onNavigateTab(2),
                child: UiKit.cardContainer(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 48,
                          height: 66,
                          color: AppTheme.bg,
                          child: (o['ai_output_image_url'] ?? '').toString().isNotEmpty
                              ? Image.network(
                                  ApiService.instance.mediaUrl(o['ai_output_image_url'].toString()),
                                  fit: BoxFit.cover,
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
                            Text('#${o['job_id']}',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: AppTheme.woodDark)),
                            const SizedBox(height: 3),
                            Text('${o['customer_name']} • ${o['wood_species']}',
                                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                            const SizedBox(height: 5),
                            UiKit.iconChip(UiKit.stageIcon(stage), '${o['current_stage_name']}', color: statusColor),
                          ],
                        ),
                      ),
                      Text('${o['expected_delivery_date']}',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
              );
            }),
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
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppTheme.woodDark)),
          ],
        ),
      ),
    );
  }
}
