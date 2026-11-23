import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/pdf_service.dart';
import '../../widgets/ui_kit.dart';

class CustomerOrdersTab extends StatefulWidget {
  const CustomerOrdersTab({super.key});

  @override
  State<CustomerOrdersTab> createState() => _CustomerOrdersTabState();
}

class _CustomerOrdersTabState extends State<CustomerOrdersTab> {
  final _searchCtrl = TextEditingController();
  final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  List<dynamic> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final q = _searchCtrl.text.trim();
      final qs = q.isNotEmpty ? '?search=${Uri.encodeQueryComponent(q)}' : '';
      final res = await ApiService.instance.get('/orders$qs');
      setState(() => _orders = (res['orders'] as List?) ?? []);
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
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.all(20),
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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 76,
                        height: 112,
                        color: AppTheme.bg,
                        child: (order['ai_output_image_url'] ?? '').toString().isNotEmpty
                            ? Image.network(
                                ApiService.instance.mediaUrl(order['ai_output_image_url'].toString()),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.door_front_door_rounded, size: 38),
                              )
                            : const Icon(Icons.door_front_door_rounded, size: 38),
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
                                      maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
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
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    UiKit.moneyPill(Icons.receipt_long_rounded, 'Total',
                        _inr.format(double.tryParse('${order['total_cost']}') ?? 0), AppTheme.woodDark),
                    const SizedBox(width: 8),
                    UiKit.moneyPill(Icons.check_circle_rounded, 'Paid',
                        _inr.format(double.tryParse('${order['advance_amount']}') ?? 0), AppTheme.success),
                    const SizedBox(width: 8),
                    UiKit.moneyPill(Icons.pending_actions_rounded, 'Balance',
                        _inr.format(double.tryParse('${order['balance_amount']}') ?? 0), AppTheme.danger),
                  ],
                ),
                const SizedBox(height: 18),
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
                        await ApiService.instance.post('/orders/${order['id']}/dispatch', {});
                        if (ctx.mounted) Navigator.pop(ctx);
                        _load();
                      },
                      icon: const Icon(Icons.send_rounded),
                      label: const Text('One-Tap Send to Production'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
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
                    hintText: 'Search Job ID, customer, mobile...',
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
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _orders.isEmpty
                  ? const Center(child: Text('No orders found.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(14),
                        itemCount: _orders.length,
                        itemBuilder: (_, i) {
                          final o = Map<String, dynamic>.from(_orders[i] as Map);
                          final stage = int.tryParse('${o['current_stage']}') ?? 1;
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
                                          color: AppTheme.bg,
                                          child: (o['ai_output_image_url'] ?? '').toString().isNotEmpty
                                              ? Image.network(
                                                  ApiService.instance.mediaUrl(o['ai_output_image_url'].toString()),
                                                  fit: BoxFit.cover,
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
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      UiKit.moneyPill(Icons.receipt_long_rounded, 'Total',
                                          _inr.format(double.tryParse('${o['total_cost']}') ?? 0), AppTheme.woodDark),
                                      const SizedBox(width: 8),
                                      UiKit.moneyPill(Icons.pending_actions_rounded, 'Balance',
                                          _inr.format(double.tryParse('${o['balance_amount']}') ?? 0), AppTheme.danger),
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
