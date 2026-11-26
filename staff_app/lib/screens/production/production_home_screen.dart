import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/notifications_service.dart';
import '../../widgets/ui_kit.dart';
import '../login_screen.dart';
import '../shared/notifications_screen.dart';
import 'production_job_detail_screen.dart';

class ProductionHomeScreen extends StatefulWidget {
  const ProductionHomeScreen({super.key});

  @override
  State<ProductionHomeScreen> createState() => _ProductionHomeScreenState();
}

class _ProductionHomeScreenState extends State<ProductionHomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<dynamic> _jobs = [];
  bool _loading = true;
  String _filter = 'new';
  int _unreadCount = 0;
  int _urgentWatchCount = 0;
  Timer? _notifTimer;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (_tabCtrl.indexIsChanging) return;
      final filters = ['new', 'in_progress', 'completed'];
      _filter = filters[_tabCtrl.index];
      _loadJobs();
    });
    _loadJobs();
    _refreshNotifications();
    _notifTimer = Timer.periodic(const Duration(seconds: 45), (_) => _refreshNotifications());
  }

  @override
  void dispose() {
    _notifTimer?.cancel();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshNotifications() async {
    try {
      final feed = await NotificationsService.instance.fetchNotifications();
      if (!mounted) return;
      setState(() {
        _unreadCount = feed.unreadCount;
        _urgentWatchCount = feed.dueReachedCount + feed.dueSoonCount;
      });
    } catch (_) {}
  }

  Future<void> _loadJobs() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.instance.get('/production/jobs?filter=$_filter');
      setState(() => _jobs = (res['jobs'] as List?) ?? []);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    _refreshNotifications();
    _loadJobs();
  }

  void _openJobIdLookup() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('QR / Job ID Quick Open'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Enter or Scan Job ID (e.g. SUW-2026-0001)',
            prefixIcon: Icon(Icons.qr_code_rounded),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                final res = await ApiService.instance.get('/production/jobs/by-job-id/${ctrl.text.trim()}');
                final job = res['job'] as Map<String, dynamic>;
                if (ctx.mounted) Navigator.pop(ctx);
                if (!mounted) return;
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProductionJobDetailScreen(jobId: job['id'] as int)),
                );
                _loadJobs();
                _refreshNotifications();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
              }
            },
            child: const Text('Open Job'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    await ApiService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 82,
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.asset('assets/images/app_logo.png', fit: BoxFit.contain),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Workshop Job Queue',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
                  Text('${ApiService.instance.user?['name'] ?? ''} • Door Specs Only',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          UiKit.notificationBellButton(unreadCount: _unreadCount, onPressed: _openNotifications),
          IconButton(tooltip: 'QR / Job ID Lookup', onPressed: _openJobIdLookup, icon: const Icon(Icons.qr_code_scanner_rounded)),
          IconButton(tooltip: 'Logout', onPressed: _logout, icon: const Icon(Icons.logout_rounded)),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppTheme.brass,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.fiber_new_rounded, size: 18), text: 'New'),
            Tab(icon: Icon(Icons.build_circle_rounded, size: 18), text: 'In Progress'),
            Tab(icon: Icon(Icons.verified_rounded, size: 18), text: 'Completed'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_unreadCount > 0 || _urgentWatchCount > 0)
            Material(
              color: const Color(0xFFFFF4E5),
              child: InkWell(
                onTap: _openNotifications,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppTheme.warning.withValues(alpha: 0.4))),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_active_rounded, color: AppTheme.danger, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _unreadCount > 0
                              ? '$_unreadCount unread alert(s) • Check 2-day delivery reminders & assigned jobs'
                              : '$_urgentWatchCount incomplete job(s) due within 2 days / reached',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.woodDark),
                        ),
                      ),
                      const Text('View ->',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.danger)),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _jobs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.inventory_2_outlined, size: 48, color: Colors.black26),
                            const SizedBox(height: 8),
                            const Text('No jobs in this queue.'),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: () {
                                _loadJobs();
                                _refreshNotifications();
                              },
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Refresh'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          await _loadJobs();
                          await _refreshNotifications();
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.all(14),
                          itemCount: _jobs.length,
                          itemBuilder: (_, i) {
                            final j = Map<String, dynamic>.from(_jobs[i] as Map);
                            final stage = int.tryParse('${j['current_stage']}') ?? 1;
                            final doneSteps = int.tryParse('${j['process_done_count']}') ?? 0;
                            final totalSteps = int.tryParse('${j['process_total_steps']}') ?? 31;
                            final pColor = UiKit.priorityColor(j['priority']?.toString());
                            final prodPlace = (j['production_place'] ?? '').toString().trim();
                            final isReached = j['is_delivery_reached'] == true;
                            final isDueSoon = j['is_due_soon'] == true;
                            final daysLeft = int.tryParse('${j['days_left']}') ?? 0;
                            final lastProgressText = UiKit.formatDateTime(j['last_progress_at'] ?? j['updated_at']);
                            final completedText = UiKit.formatDateTime(j['completed_at'] ?? j['last_progress_at'] ?? j['updated_at']);

                            return InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => ProductionJobDetailScreen(jobId: j['id'] as int)),
                                );
                                _loadJobs();
                                _refreshNotifications();
                              },
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
                                            width: 62,
                                            height: 88,
                                            padding: const EdgeInsets.all(3),
                                            color: Colors.white,
                                            child: (j['ai_output_image_url'] ?? '').toString().isNotEmpty
                                                ? Image.network(
                                                    ApiService.instance.mediaUrl(j['ai_output_image_url'].toString()),
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
                                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: AppTheme.woodDark,
                                                      borderRadius: BorderRadius.circular(7),
                                                    ),
                                                    child: Text('${j['job_id']}',
                                                        style: const TextStyle(
                                                            color: AppTheme.brass, fontWeight: FontWeight.w800, fontSize: 11.5)),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  UiKit.iconChip(Icons.flag_rounded, '${j['priority']}', color: pColor),
                                                  const Spacer(),
                                                  const Icon(Icons.arrow_forward_ios_rounded, size: 15, color: Colors.black38),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text('${j['woodwork_category']}',
                                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
                                              const SizedBox(height: 6),
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 6,
                                                children: [
                                                  UiKit.iconChip(Icons.forest_rounded, '${j['wood_species']}'),
                                                  UiKit.iconChip(Icons.straighten_rounded, '${j['width_inches']}"×${j['height_inches']}"'),
                                                  UiKit.iconChip(Icons.inventory_2_rounded, 'Qty ${j['quantity']}', color: AppTheme.info),
                                                  UiKit.iconChip(
                                                    Icons.event_available_rounded,
                                                    'Delivery Date: ${j['expected_delivery_date'] ?? '-'}',
                                                    color: isReached ? AppTheme.danger : (isDueSoon ? AppTheme.warning : AppTheme.woodPrimary),
                                                  ),
                                                  if (prodPlace.isNotEmpty)
                                                    UiKit.iconChip(Icons.location_city_rounded, prodPlace, color: AppTheme.woodPrimary),
                                                  if (isReached)
                                                    UiKit.iconChip(
                                                      Icons.warning_amber_rounded,
                                                      daysLeft == 0 ? 'Due Today' : 'Overdue ${daysLeft.abs()}d',
                                                      color: AppTheme.danger,
                                                    )
                                                  else if (isDueSoon)
                                                    UiKit.iconChip(Icons.schedule_rounded, 'Due in ${daysLeft}d', color: AppTheme.warning),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        UiKit.iconChip(
                                          UiKit.stageIcon(stage),
                                          'Steps $doneSteps/$totalSteps • ${j['current_stage_name']}',
                                          color: stage == 8 ? AppTheme.success : AppTheme.woodPrimary,
                                        ),
                                        if (stage == 8)
                                          UiKit.iconChip(
                                            Icons.task_alt_rounded,
                                            'Completed Date: $completedText',
                                            color: AppTheme.success,
                                          )
                                        else
                                          UiKit.iconChip(
                                            Icons.update_rounded,
                                            'Last Progress: $lastProgressText',
                                            color: AppTheme.info,
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
      ),
    );
  }
}
