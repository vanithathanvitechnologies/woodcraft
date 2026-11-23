import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../login_screen.dart';
import '../shared/customer_orders_tab.dart';
import '../shared/live_production_tracker_tab.dart';
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

  static const _titles = [
    'Welcome, Owner',
    'Orders',
    'Production Tracking',
    'Reports & History',
    'Role Management',
  ];

  void _setTab(int idx) => setState(() => _tabIndex = idx);

  Future<void> _logout() async {
    await ApiService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      OwnerDashboardTab(onNavigateTab: _setTab),
      const CustomerOrdersTab(),
      const LiveProductionTrackerTab(),
      const OwnerReportsTab(),
      const RoleManagementTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
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
          IconButton(tooltip: 'Logout', onPressed: _logout, icon: const Icon(Icons.logout_rounded)),
        ],
      ),
      body: pages[_tabIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: _setTab,
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
