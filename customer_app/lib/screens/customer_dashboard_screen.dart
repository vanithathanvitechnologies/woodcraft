import 'package:flutter/material.dart';
import '../services/customer_api_service.dart';
import '../widgets/suresh_timbers_showcase.dart';
import 'mobile_login_screen.dart';
import 'order_track_screen.dart';

class CustomerDashboardScreen extends StatefulWidget {
  const CustomerDashboardScreen({super.key});

  @override
  State<CustomerDashboardScreen> createState() => _CustomerDashboardScreenState();
}

class _CustomerDashboardScreenState extends State<CustomerDashboardScreen> {
  static const _woodDark = Color(0xFF2D180A);
  static const _woodPrimary = Color(0xFF6B3E1D);
  static const _brass = Color(0xFFD4A037);
  static const _bg = Color(0xFFF7F4EF);
  static const _border = Color(0xFFEBE4DA);
  static const _success = Color(0xFF1B8A5A);
  static const _danger = Color(0xFFD13B34);

  Map<String, dynamic>? _dashboard;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await CustomerApiService.instance.getDashboard();
      setState(() => _dashboard = data);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await CustomerApiService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MobileLoginScreen()));
  }

  IconData _stageIcon(int stage) {
    switch (stage) {
      case 1:
        return Icons.fiber_new_rounded;
      case 2:
        return Icons.carpenter_rounded;
      case 3:
        return Icons.grid_view_rounded;
      case 4:
        return Icons.auto_awesome_rounded;
      case 5:
        return Icons.handyman_rounded;
      case 6:
        return Icons.brush_rounded;
      case 7:
        return Icons.verified_rounded;
      case 8:
        return Icons.local_shipping_rounded;
      default:
        return Icons.schedule_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final customer = (_dashboard?['customer'] as Map?) ?? CustomerApiService.instance.customer ?? {};
    final summary = (_dashboard?['summary'] as Map?) ?? {};
    final orders = (_dashboard?['orders'] as List?) ?? [];

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _woodDark,
        foregroundColor: Colors.white,
        elevation: 0,
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
                  const Text('Suresh Timbers',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
                  Text(
                    (customer['mobile'] ?? '').toString().isNotEmpty
                        ? 'Since 1983 • ${customer['mobile']}'
                        : 'Since 1983 • 25-Yr Written Warranty',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
          IconButton(tooltip: 'Logout', onPressed: _logout, icon: const Icon(Icons.logout_rounded)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Customer Welcome & Order Summary Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_woodDark, _woodPrimary, Color(0xFF8C5327)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _woodDark.withValues(alpha: 0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: _brass.withValues(alpha: 0.22),
                        child: const Icon(Icons.person_rounded, color: _brass, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, ${customer['name'] ?? 'Valued Customer'}',
                              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
                            ),
                            if ((customer['delivery_address'] ?? '').toString().isNotEmpty)
                              Row(
                                children: [
                                  const Icon(Icons.location_on_rounded, size: 13, color: _brass),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      '${customer['delivery_address']}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _heroStat(Icons.inventory_2_rounded, 'Orders', '${summary['total_orders'] ?? 0}'),
                      const SizedBox(width: 8),
                      _heroStat(Icons.handyman_rounded, 'In Craft', '${summary['in_progress'] ?? 0}'),
                      const SizedBox(width: 8),
                      _heroStat(Icons.verified_rounded, 'Ready', '${summary['completed'] ?? 0}'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // 3. Live Order Tracking Section
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: _woodPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_shipping_rounded, size: 18, color: _woodPrimary),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Live Order Tracking',
                  style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: _woodDark),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 40, color: _danger),
                    const SizedBox(height: 8),
                    Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: _danger, fontSize: 13)),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retry Orders'),
                    ),
                  ],
                ),
              )
            else if (orders.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _border),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.door_front_door_outlined, size: 42, color: Colors.black26),
                    SizedBox(height: 8),
                    Text('No orders found for your mobile number yet.'),
                  ],
                ),
              )
            else
              ...orders.map((raw) {
                          final o = Map<String, dynamic>.from(raw as Map);
                          final stage = int.tryParse('${o['current_stage']}') ?? 1;
                          final isDone = stage == 8;
                          final doneSteps = int.tryParse('${o['process_done_count']}') ?? 0;
                          const totalSteps = 31;
                          final progressRatio = isDone ? 1.0 : (doneSteps / totalSteps).clamp(0.0, 1.0);
                          final pct = (progressRatio * 100).round();

                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _border),
                              boxShadow: [
                                BoxShadow(
                                  color: _woodDark.withValues(alpha: 0.05),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => OrderTrackScreen(orderId: o['id'] as int)),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Door Preview Image
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(14),
                                          child: Container(
                                            width: 72,
                                            height: 102,
                                            padding: const EdgeInsets.all(3),
                                            color: Colors.white,
                                            child: (o['ai_output_image_url'] ?? '').toString().isNotEmpty
                                                ? Image.network(
                                                    CustomerApiService.instance.mediaUrl(o['ai_output_image_url'].toString()),
                                                    fit: BoxFit.contain,
                                                    errorBuilder: (_, __, ___) =>
                                                        const Icon(Icons.door_front_door_rounded, size: 36, color: _woodPrimary),
                                                  )
                                                : const Icon(Icons.door_front_door_rounded, size: 36, color: _woodPrimary),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: _woodDark,
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Text(
                                                      '${o['job_id']}',
                                                      style: const TextStyle(
                                                          color: _brass, fontWeight: FontWeight.w800, fontSize: 11.5),
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  const Icon(Icons.arrow_forward_ios_rounded, size: 15, color: Colors.black38),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                '${o['woodwork_category']}',
                                                style: const TextStyle(
                                                    fontSize: 15.5, fontWeight: FontWeight.w800, color: _woodDark),
                                              ),
                                              const SizedBox(height: 6),
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 6,
                                                children: [
                                                  _miniChip(Icons.forest_rounded, '${o['wood_species']}'),
                                                  _miniChip(Icons.straighten_rounded, '${o['width_inches']}"×${o['height_inches']}"'),
                                                  _miniChip(Icons.event_available_rounded, '${o['expected_delivery_date']}'),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    // Live Stage Progress Box
                                    Container(
                                      padding: const EdgeInsets.all(11),
                                      decoration: BoxDecoration(
                                        color: (isDone ? _success : _woodPrimary).withValues(alpha: 0.06),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: (isDone ? _success : _woodPrimary).withValues(alpha: 0.18),
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            children: [
                                              Icon(_stageIcon(stage), size: 18, color: isDone ? _success : _woodPrimary),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Process $doneSteps/$totalSteps • ${o['current_stage_name']}',
                                                  style: TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: isDone ? _success : _woodPrimary,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                '$pct%',
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w900,
                                                  color: isDone ? _success : _woodPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: LinearProgressIndicator(
                                              value: progressRatio,
                                              minHeight: 7,
                                              color: isDone ? _success : _woodPrimary,
                                              backgroundColor: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.event_available_rounded, size: 15, color: _woodPrimary),
                                            const SizedBox(width: 5),
                                            Text(
                                              'Delivery: ${o['expected_delivery_date'] ?? '-'}',
                                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: (isDone ? _success : _woodPrimary).withValues(alpha: 0.09),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            isDone ? 'Ready for Delivery' : 'Tap for Live Timeline',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w800,
                                              color: isDone ? _success : _woodPrimary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),

            const SizedBox(height: 22),

            // 3. Signature Royal Creations & Certifications Showcase
            const SureshTimbersShowcaseSection(),
          ],
        ),
      ),
    );
  }

  Widget _heroStat(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 17, color: _brass),
            const SizedBox(height: 5),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5),
            ),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _miniChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.5, color: _woodPrimary),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _woodDark)),
        ],
      ),
    );
  }
}
