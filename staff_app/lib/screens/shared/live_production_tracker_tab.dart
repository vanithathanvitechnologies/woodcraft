import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_theme.dart';
import '../../services/api_service.dart';
import '../../widgets/process_steps_table.dart';
import '../../widgets/ui_kit.dart';

class LiveProductionTrackerTab extends StatefulWidget {
  const LiveProductionTrackerTab({super.key});

  @override
  State<LiveProductionTrackerTab> createState() => _LiveProductionTrackerTabState();
}

class _LiveProductionTrackerTabState extends State<LiveProductionTrackerTab> {
  List<dynamic> _orders = [];
  bool _loading = true;
  bool _onlyPending = false;
  bool _onlyDelayed = false;
  bool _onlyBlockers = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final params = <String>[];
      if (_onlyPending) params.add('pending_only=true');
      if (_onlyDelayed) params.add('due_reached_only=true');
      if (_onlyBlockers) params.add('blocker_only=true');
      final qs = params.isNotEmpty ? '?${params.join('&')}' : '';
      final data = await ApiService.instance.get('/orders$qs');
      setState(() => _orders = (data['orders'] as List?) ?? []);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _shareWhatsApp(Map<String, dynamic> order) async {
    final mobile = (order['customer_mobile'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
    final msg = Uri.encodeComponent(
      'Hello ${order['customer_name']}, update on your Wooden Door order (${order['job_id']}): '
      'Current Stage is "${order['current_stage_name']}" (${order['current_stage']}/8). '
      'Expected Delivery: ${order['expected_delivery_date']}.',
    );
    final url = Uri.parse('https://wa.me/91$mobile?text=$msg');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openTimeline(int orderId) async {
    try {
      final res = await ApiService.instance.get('/orders/$orderId');
      var order = Map<String, dynamic>.from(res['order'] as Map);
      final role = ApiService.instance.role.toLowerCase();
      final canEditProcess = role == 'owner' || role == 'admin';
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (ctx) {
          int? busySno;
          return StatefulBuilder(
            builder: (ctx, setModalState) {
              final history = (order['stage_history'] as List?) ?? [];
              final photos = (order['progress_photos'] as List?) ?? [];
              final processSteps = (order['process_steps'] as List?) ?? [];
              return DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.88,
                builder: (_, scrollCtrl) => ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(20),
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    UiKit.sectionHeader(Icons.playlist_add_check_rounded, '${order['job_id']} • Process Sheet (36 Steps)'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        UiKit.iconChip(Icons.person_rounded, '${order['customer_name']}'),
                        UiKit.iconChip(Icons.phone_rounded, '${order['customer_mobile']}', color: AppTheme.info),
                        UiKit.iconChip(Icons.event_available_rounded, '${order['expected_delivery_date']}', color: AppTheme.warning),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (order['has_blocker'] == 1)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: AppTheme.danger.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: AppTheme.danger),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text('WORKSHOP BLOCKER: ${order['blocker_note']}',
                                  style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ),
                    ProcessStepsTable(
                      steps: processSteps,
                      editable: canEditProcess,
                      busySno: busySno,
                      onUpdateStep: (sNo, {String? planningDate, String? actualDate}) async {
                        setModalState(() => busySno = sNo);
                        try {
                          final body = <String, dynamic>{'s_no': sNo};
                          if (planningDate != null) body['planning_date'] = planningDate;
                          if (actualDate != null) body['actual_date'] = actualDate;
                          await ApiService.instance.patch('/production/jobs/$orderId/process', body);
                          final refreshed = await ApiService.instance.get('/orders/$orderId');
                          setModalState(() {
                            order = Map<String, dynamic>.from(refreshed['order'] as Map);
                            busySno = null;
                          });
                          _load();
                        } catch (e) {
                          setModalState(() => busySno = null);
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                        }
                      },
                    ),
                    if (history.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      UiKit.sectionHeader(Icons.history_rounded, 'Timestamped Updates'),
                      const SizedBox(height: 8),
                      ...history.map((h) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 15,
                              backgroundColor: (h['is_blocker'] == 1 ? AppTheme.danger : AppTheme.woodPrimary).withValues(alpha: 0.12),
                              child: Icon(
                                h['is_blocker'] == 1 ? Icons.report_problem_rounded : Icons.schedule_rounded,
                                size: 16,
                                color: h['is_blocker'] == 1 ? AppTheme.danger : AppTheme.woodPrimary,
                              ),
                            ),
                            title: Text('${h['stage_name']} — ${h['notes'] ?? ''}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              '${h['created_at']} ${h['updated_by_name'] != null ? "• ${h['updated_by_name']}" : ""}',
                              style: const TextStyle(fontSize: 11.5),
                            ),
                          )),
                    ],
                    if (photos.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      UiKit.sectionHeader(Icons.photo_camera_rounded, 'Workshop Progress Photos'),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 130,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: photos.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (_, i) {
                            final p = photos[i];
                            return Column(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    ApiService.instance.mediaUrl(p['photo_url']?.toString()),
                                    width: 120,
                                    height: 95,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 120,
                                      height: 95,
                                      color: AppTheme.bg,
                                      child: const Icon(Icons.broken_image_rounded),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text('${p['stage_name']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        avatar: const Icon(Icons.hourglass_bottom_rounded, size: 16),
                        label: const Text('Pending'),
                        selected: _onlyPending,
                        onSelected: (v) {
                          setState(() => _onlyPending = v);
                          _load();
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        avatar: const Icon(Icons.schedule_rounded, size: 16),
                        label: const Text('Delivery Reached'),
                        selected: _onlyDelayed,
                        onSelected: (v) {
                          setState(() => _onlyDelayed = v);
                          _load();
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        avatar: const Icon(Icons.warning_amber_rounded, size: 16),
                        label: const Text('Blockers'),
                        selected: _onlyBlockers,
                        onSelected: (v) {
                          setState(() => _onlyBlockers = v);
                          _load();
                        },
                      ),
                    ],
                  ),
                ),
              ),
              IconButton.filledTonal(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _orders.isEmpty
                  ? const Center(child: Text('No active production jobs match this filter.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(14),
                        itemCount: _orders.length,
                        itemBuilder: (ctx, i) {
                          final o = Map<String, dynamic>.from(_orders[i] as Map);
                          final stage = int.tryParse('${o['current_stage']}') ?? 1;
                          final doneSteps = int.tryParse('${o['process_done_count']}') ?? 0;
                          final totalSteps = int.tryParse('${o['process_total_steps']}') ?? 31;
                          final progressRatio = stage == 8 ? 1.0 : (doneSteps / totalSteps).clamp(0.0, 1.0);
                          final isDelayed = o['is_delivery_reached'] == true || o['is_delayed'] == true;
                          final hasBlocker = o['has_blocker'] == 1;
                          final isDone = stage == 8;
                          final prodMember = (o['assigned_production_user_name'] ?? '').toString().trim();
                          final prodPlace = (o['production_place'] ?? '').toString().trim();

                          return InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => _openTimeline(o['id'] as int),
                            child: UiKit.cardContainer(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppTheme.woodDark,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text('${o['job_id']}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w800, fontSize: 12, color: AppTheme.brass)),
                                      ),
                                      const SizedBox(width: 8),
                                      if (isDelayed) UiKit.iconChip(Icons.warning_amber_rounded, 'Delivery Reached', color: AppTheme.danger),
                                      if (hasBlocker)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 6),
                                          child: UiKit.iconChip(Icons.warning_rounded, 'Blocker', color: AppTheme.warning),
                                        ),
                                      const Spacer(),
                                      UiKit.iconChip(Icons.event_rounded, '${o['expected_delivery_date']}',
                                          color: isDelayed ? AppTheme.danger : AppTheme.textMuted),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      UiKit.iconChip(Icons.person_rounded, '${o['customer_name']}', color: AppTheme.woodDark),
                                      UiKit.iconChip(Icons.door_front_door_rounded, '${o['woodwork_category']}'),
                                      UiKit.iconChip(Icons.forest_rounded, '${o['wood_species']}', color: AppTheme.woodAccent),
                                      if (prodMember.isNotEmpty)
                                        UiKit.iconChip(Icons.engineering_rounded, prodMember, color: AppTheme.woodPrimary),
                                      if (prodPlace.isNotEmpty)
                                        UiKit.iconChip(Icons.location_city_rounded, prodPlace, color: AppTheme.info),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: (isDone ? AppTheme.success : AppTheme.woodPrimary).withValues(alpha: 0.07),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Icon(UiKit.stageIcon(stage),
                                                size: 18, color: isDone ? AppTheme.success : AppTheme.woodPrimary),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Process $doneSteps/$totalSteps • ${o['current_stage_name']}',
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: isDone ? AppTheme.success : AppTheme.woodPrimary,
                                                ),
                                              ),
                                            ),
                                            Text('${(progressRatio * 100).round()}%',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w900,
                                                    color: isDone ? AppTheme.success : AppTheme.woodPrimary)),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: LinearProgressIndicator(
                                            value: progressRatio,
                                            minHeight: 7,
                                            color: isDone ? AppTheme.success : AppTheme.woodPrimary,
                                            backgroundColor: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () => _shareWhatsApp(o),
                                        icon: const Icon(Icons.share_rounded, size: 16),
                                        label: const Text('Notify Customer'),
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
