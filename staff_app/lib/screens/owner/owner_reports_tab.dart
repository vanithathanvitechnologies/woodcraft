import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_theme.dart';
import '../../services/api_service.dart';
import '../../widgets/ui_kit.dart';

class OwnerReportsTab extends StatefulWidget {
  const OwnerReportsTab({super.key});

  @override
  State<OwnerReportsTab> createState() => _OwnerReportsTabState();
}

class _OwnerReportsTabState extends State<OwnerReportsTab> {
  final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  Map<String, dynamic>? _report;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.instance.get('/reports/summary');
      setState(() => _report = data);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _kpiCard(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(color: AppTheme.woodDark.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 17, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_report == null) return Center(child: ElevatedButton(onPressed: _load, child: const Text('Retry')));

    final kpis = Map<String, dynamic>.from(_report!['kpis'] as Map);
    final byStage = (_report!['by_stage'] as List?) ?? [];
    final byWood = (_report!['by_wood'] as List?) ?? [];
    final maxStage = byStage.fold<int>(1, (m, e) => (int.tryParse('${e['count']}') ?? 1) > m ? (int.tryParse('${e['count']}') ?? 1) : m);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          LayoutBuilder(
            builder: (ctx, constraints) {
              final cols = constraints.maxWidth > 720 ? 4 : 2;
              return GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisExtent: 108,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                children: [
                  _kpiCard(Icons.account_balance_wallet_rounded, 'Total Revenue',
                      _inr.format(double.tryParse('${kpis['total_revenue']}') ?? 0), AppTheme.woodDark),
                  _kpiCard(Icons.check_circle_rounded, 'Advance Paid',
                      _inr.format(double.tryParse('${kpis['total_advance']}') ?? 0), AppTheme.success),
                  _kpiCard(Icons.pending_actions_rounded, 'Balance Due',
                      _inr.format(double.tryParse('${kpis['total_balance']}') ?? 0), AppTheme.danger),
                  _kpiCard(Icons.handyman_rounded, 'Active / Delayed',
                      '${kpis['active_orders']} / ${kpis['delayed_orders']}', AppTheme.warning),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          UiKit.cardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UiKit.sectionHeader(Icons.timeline_rounded, 'Orders by Production Stage'),
                const SizedBox(height: 14),
                if (byStage.isEmpty) const Text('No orders yet.'),
                ...byStage.map((s) {
                  final stNum = int.tryParse('${s['stage_number']}') ?? 1;
                  final cnt = int.tryParse('${s['count']}') ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(UiKit.stageIcon(stNum), size: 16, color: AppTheme.woodPrimary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('${s['stage_number']}. ${s['stage_name']}',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            ),
                            UiKit.iconChip(Icons.work_outline_rounded, '$cnt jobs'),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: cnt / maxStage,
                            minHeight: 7,
                            color: AppTheme.woodPrimary,
                            backgroundColor: AppTheme.bg,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          UiKit.cardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UiKit.sectionHeader(Icons.forest_rounded, 'Revenue by Wood Species'),
                const SizedBox(height: 12),
                if (byWood.isEmpty) const Text('No wood data yet.'),
                ...byWood.map((w) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: AppTheme.bg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.woodAccent.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.forest_rounded, size: 17, color: AppTheme.woodPrimary),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${w['wood_species']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                  Text('${w['order_count']} order(s)',
                                      style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
                                ],
                              ),
                            ),
                            Text(
                              _inr.format(double.tryParse('${w['revenue']}') ?? 0),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900, fontSize: 15, color: AppTheme.woodPrimary),
                            ),
                          ],
                        ),
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
