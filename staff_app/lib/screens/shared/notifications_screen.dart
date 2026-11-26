import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/notifications_service.dart';
import '../../widgets/ui_kit.dart';
import '../production/production_job_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  final Future<void> Function(Map<String, dynamic> notification)? onOpenOrderForOwner;
  const NotificationsScreen({super.key, this.onOpenOrderForOwner});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  NotificationsFeed? _feed;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final feed = await NotificationsService.instance.fetchNotifications();
      if (mounted) setState(() => _feed = feed);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    try {
      await NotificationsService.instance.markAllRead();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications marked as read')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _onTapNotification(Map<String, dynamic> n) async {
    final id = int.tryParse('${n['id']}');
    final isUnread = n['is_read'] == 0 || n['is_read'] == false;
    if (isUnread && id != null) {
      try {
        await NotificationsService.instance.markOneRead(id);
      } catch (_) {}
    }

    final role = ApiService.instance.role.toLowerCase();
    final orderId = int.tryParse('${n['order_id']}');
    if (orderId != null && mounted) {
      if (role == 'production') {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProductionJobDetailScreen(jobId: orderId)),
        );
      } else if (widget.onOpenOrderForOwner != null) {
        await widget.onOpenOrderForOwner!(n);
        if (mounted) Navigator.pop(context, true);
        return;
      }
    }
    _load();
  }

  Color _typeColor(String? type) {
    switch (type) {
      case 'delivery_reached':
        return AppTheme.danger;
      case 'pre_delivery_2d':
        return AppTheme.warning;
      case 'order_assigned':
        return AppTheme.info;
      default:
        return AppTheme.woodPrimary;
    }
  }

  IconData _typeIcon(String? type) {
    switch (type) {
      case 'delivery_reached':
        return Icons.warning_amber_rounded;
      case 'pre_delivery_2d':
        return Icons.notifications_active_rounded;
      case 'order_assigned':
        return Icons.assignment_turned_in_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String _typeLabel(String? type) {
    switch (type) {
      case 'delivery_reached':
        return 'Delivery Date Reached';
      case 'pre_delivery_2d':
        return '2-Day Alert';
      case 'order_assigned':
        return 'Assigned Job';
      default:
        return 'Alert';
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = _feed;
    final notifs = feed?.notifications ?? const [];
    final watch = feed?.watchOrders ?? const [];
    final urgentWatch = watch.where((o) => (int.tryParse('${o['days_left']}') ?? 99) <= 2).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Alerts & Notifications', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
        actions: [
          if ((feed?.unreadCount ?? 0) > 0)
            TextButton.icon(
              onPressed: _markAllRead,
              icon: const Icon(Icons.done_all_rounded, color: Colors.white, size: 18),
              label: const Text('Mark All', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          IconButton(tooltip: 'Refresh', onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  if (urgentWatch.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF5EB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.45)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.schedule_rounded, color: AppTheme.danger, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Incomplete Orders Due Within 2 Days (${urgentWatch.length})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: AppTheme.woodDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...urgentWatch.map((o) {
                            final dLeft = int.tryParse('${o['days_left']}') ?? 0;
                            final isReached = dLeft <= 0;
                            final dueText = dLeft < 0
                                ? 'Overdue ${dLeft.abs()}d'
                                : (dLeft == 0 ? 'Delivery Reached Today' : 'Due in ${dLeft}d');
                            return InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _onTapNotification({'order_id': o['id'], 'job_id': o['job_id']}),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: (isReached ? AppTheme.danger : AppTheme.warning).withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${o['job_id']} • ${o['woodwork_category']}',
                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Stage ${o['current_stage']}/8 (${o['current_stage_name']})'
                                            '${(o['production_place'] ?? '').toString().isNotEmpty ? ' • Place: ${o['production_place']}' : ''}',
                                            style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                                          ),
                                        ],
                                      ),
                                    ),
                                    UiKit.iconChip(
                                      isReached ? Icons.error_outline_rounded : Icons.notifications_active_rounded,
                                      dueText,
                                      color: isReached ? AppTheme.danger : AppTheme.warning,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],

                  UiKit.sectionHeader(
                    Icons.notifications_rounded,
                    'Notifications (${notifs.length})',
                  ),
                  const SizedBox(height: 10),
                  if (notifs.isEmpty)
                    UiKit.cardContainer(
                      child: const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            'No alerts yet. Incomplete orders automatically trigger reminders 2 days before delivery date.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textMuted),
                          ),
                        ),
                      ),
                    )
                  else
                    ...notifs.map((n) {
                      final type = n['type']?.toString();
                      final color = _typeColor(type);
                      final unread = n['is_read'] == 0 || n['is_read'] == false;
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _onTapNotification(n),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: unread ? const Color(0xFFFFFBF2) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: unread ? color.withValues(alpha: 0.55) : AppTheme.border,
                              width: unread ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 19,
                                backgroundColor: color.withValues(alpha: 0.12),
                                child: Icon(_typeIcon(type), size: 20, color: color),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        UiKit.iconChip(_typeIcon(type), _typeLabel(type), color: color),
                                        const Spacer(),
                                        if (unread)
                                          Container(
                                            width: 9,
                                            height: 9,
                                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${n['title'] ?? ''}',
                                      style: TextStyle(
                                        fontWeight: unread ? FontWeight.w800 : FontWeight.w700,
                                        fontSize: 13.5,
                                        color: AppTheme.woodDark,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${n['message'] ?? ''}',
                                      style: const TextStyle(fontSize: 12.5, color: Colors.black87, height: 1.35),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Delivery: ${n['expected_delivery_date'] ?? '-'} • ${n['created_at'] ?? ''}',
                                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
