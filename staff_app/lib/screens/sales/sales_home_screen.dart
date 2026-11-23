import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../login_screen.dart';
import '../shared/customer_orders_tab.dart';
import '../shared/live_production_tracker_tab.dart';
import 'ai_combiner_tab.dart';
import 'billing_estimator_tab.dart';
import 'design_catalog_tab.dart';

class SalesHomeScreen extends StatefulWidget {
  const SalesHomeScreen({super.key});

  @override
  State<SalesHomeScreen> createState() => _SalesHomeScreenState();
}

class _SalesHomeScreenState extends State<SalesHomeScreen> {
  int _tabIndex = 0;

  static const _titles = [
    'Design Catalog',
    'AI Design Combiner',
    'Billing Estimator',
    'Orders & PDF Print',
    'Live Production Track',
  ];

  final _pages = const [
    DesignCatalogTab(),
    AiCombinerTab(),
    BillingEstimatorTab(),
    CustomerOrdersTab(),
    LiveProductionTrackerTab(),
  ];

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
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  Text('Sales Team • ${ApiService.instance.user?['name'] ?? ''}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(tooltip: 'Logout', onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: _pages[_tabIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (idx) => setState(() => _tabIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.grid_view), label: 'Catalog'),
          NavigationDestination(icon: Icon(Icons.auto_awesome), label: 'AI Mix'),
          NavigationDestination(icon: Icon(Icons.calculate), label: 'Billing'),
          NavigationDestination(icon: Icon(Icons.picture_as_pdf), label: 'Orders'),
          NavigationDestination(icon: Icon(Icons.track_changes), label: 'Track'),
        ],
      ),
    );
  }
}
