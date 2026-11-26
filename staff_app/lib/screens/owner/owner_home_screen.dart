import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/notifications_service.dart';
import '../../widgets/ui_kit.dart';
import '../login_screen.dart';
import '../shared/customer_orders_tab.dart';
import '../shared/live_production_tracker_tab.dart';
import '../shared/notifications_screen.dart';
import 'owner_dashboard_tab.dart';
import 'owner_reports_tab.dart';
import 'role_management_tab.dart';

class OwnerHomeScreen extends StatefulWidget {
  const OwnerHomeScreen({super.key});

  @override
  State<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends State<OwnerHomeScreen> {
  int _tabIndex = 0;
  String _ordersFilter = 'all';
  int _unreadCount = 0;
  int _urgentWatchCount = 0;
  Timer? _notifTimer;

  static const _titles = [
    'Welcome, Owner',
    'Orders',
    'Production Tracking',
    'Reports & History',
    'Role Management',
  ];

  @override
  void initState() {
    super.initState();
    _refreshNotifications();
    _notifTimer = Timer.periodic(const Duration(seconds: 45), (_) => _refreshNotifications());
  }

  @override
  void dispose() {
    _notifTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshNotifications() async {
    try {
      final feed = await NotificationsService.instance.fetchNotifications();
      if (!mounted) return;
      final urgentCount = feed.dueReachedCount + feed.dueSoonCount;
      setState(() {
        _unreadCount = feed.unreadCount;
        _urgentWatchCount = urgentCount;
      });
    } catch (_) {}
  }

  void _setTab(int idx, {String? ordersFilter}) {
    setState(() {
      _tabIndex = idx;
      if (ordersFilter != null) {
        _ordersFilter = ordersFilter;
      }
    });
    _refreshNotifications();
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(
          onOpenOrderForOwner: (n) async {
            final type = n['type']?.toString();
            _setTab(1, ordersFilter: type == 'delivery_reached' ? 'due_reached' : 'pending');
          },
        ),
      ),
    );
    _refreshNotifications();
  }

  Future<void> _logout() async {
    await ApiService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      OwnerDashboardTab(onNavigateTab: _setTab),
      CustomerOrdersTab(initialFilter: _ordersFilter),
      const LiveProductionTrackerTab(),
      const OwnerReportsTab(),
      const RoleManagementTab(),
    ];

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
                  Text(_titles[_tabIndex],
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
                  Text('WoodCraft • ${ApiService.instance.user?['name'] ?? ''}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          UiKit.notificationBellButton(unreadCount: _unreadCount, onPressed: _openNotifications),
          IconButton(tooltip: 'Logout', onPressed: _logout, icon: const Icon(Icons.logout_rounded)),
        ],
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
                              ? '$_unreadCount new delivery alert(s) • Incomplete orders due within 2 days / reached'
                              : '$_urgentWatchCount incomplete order(s) due within 2 days / reached',
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
          Expanded(child: pages[_tabIndex]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (idx) => _setTab(idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.receipt_long_rounded), label: 'Orders'),
          NavigationDestination(icon: Icon(Icons.track_changes_rounded), label: 'Track'),
          NavigationDestination(icon: Icon(Icons.bar_chart_rounded), label: 'Reports'),
          NavigationDestination(icon: Icon(Icons.admin_panel_settings_rounded), label: 'Roles'),
        ],
      ),
    );
  }
}
