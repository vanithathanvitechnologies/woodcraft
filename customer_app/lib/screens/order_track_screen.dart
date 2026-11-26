import 'package:flutter/material.dart';
import '../services/customer_api_service.dart';

class OrderTrackScreen extends StatefulWidget {
  final int orderId;
  const OrderTrackScreen({super.key, required this.orderId});

  @override
  State<OrderTrackScreen> createState() => _OrderTrackScreenState();
}

class _OrderTrackScreenState extends State<OrderTrackScreen> {
  static const _woodDark = Color(0xFF2D180A);
  static const _woodPrimary = Color(0xFF6B3E1D);
  static const _brass = Color(0xFFD4A037);
  static const _bg = Color(0xFFF7F4EF);
  static const _border = Color(0xFFEBE4DA);
  static const _success = Color(0xFF1B8A5A);

  Map<String, dynamic>? _order;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await CustomerApiService.instance.getOrderDetail(widget.orderId);
      setState(() {
        _order = Map<String, dynamic>.from(res['order'] as Map);
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openFullImagePopup(String imageUrl, {String? title}) {
    if (imageUrl.isEmpty) return;
    final size = MediaQuery.sizeOf(context);
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.86),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: (size.width * 0.94).clamp(280.0, 960.0),
            maxHeight: (size.height * 0.90).clamp(320.0, 920.0),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(14),
                        child: InteractiveViewer(
                          minScale: 0.8,
                          maxScale: 5.0,
                          child: Center(
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 54),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black.withValues(alpha: 0.65),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, size: 22),
                        ),
                      ),
                    ],
                  ),
                ),
                if (title != null && title.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      color: _bg,
                      border: Border(top: BorderSide(color: _border)),
                    ),
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _woodDark),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _order == null) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(backgroundColor: _woodDark, foregroundColor: Colors.white, title: const Text('Order Tracking')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final o = _order!;
    final processSteps = (o['process_steps'] as List?) ?? [];
    final photos = (o['progress_photos'] as List?) ?? [];
    final imgUrl = CustomerApiService.instance.mediaUrl(o['ai_output_image_url']?.toString());

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _woodDark,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.local_shipping_rounded, color: _brass, size: 20),
            const SizedBox(width: 8),
            Text('Track ${o['job_id']}', style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Hero Door Design Showcase Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _border),
                boxShadow: [
                  BoxShadow(color: _woodDark.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 6)),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: _woodPrimary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.door_front_door_rounded, size: 18, color: _woodPrimary),
                          ),
                          const SizedBox(width: 8),
                          const Text('Your Finalized Door',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _woodDark)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _woodDark,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.event_available_rounded, size: 13, color: _brass),
                            const SizedBox(width: 5),
                            Text('${o['expected_delivery_date']}',
                                style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (imgUrl.isNotEmpty)
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => _openFullImagePopup(
                          imgUrl,
                          title: '${o['job_id']} • ${o['woodwork_category']} (${o['wood_species']})',
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _border),
                            ),
                            padding: const EdgeInsets.all(10),
                            child: Image.network(
                              imgUrl,
                              height: 300,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                              errorBuilder: (_, __, ___) => const SizedBox(
                                height: 140,
                                child: Center(child: Icon(Icons.door_front_door_rounded, size: 60, color: _woodPrimary)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 36-Row Live Process Status Table
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(Icons.playlist_add_check_rounded, 'Live Process Status (36 Steps)'),
                  const SizedBox(height: 12),
                  if (processSteps.isEmpty)
                    const Text('Process steps will appear shortly.', style: TextStyle(color: Colors.black54))
                  else
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: _border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          Container(
                            color: _woodDark,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            child: const Row(
                              children: [
                                SizedBox(
                                  width: 30,
                                  child: Text('S.No',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                                ),
                                SizedBox(width: 6),
                                Expanded(
                                  flex: 5,
                                  child: Text('Process',
                                      style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
                                ),
                                SizedBox(width: 4),
                                Expanded(
                                  flex: 2,
                                  child: Text('Plan',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: _brass, fontSize: 11, fontWeight: FontWeight.w800)),
                                ),
                                SizedBox(width: 4),
                                Expanded(
                                  flex: 2,
                                  child: Text('Actual',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: _brass, fontSize: 11, fontWeight: FontWeight.w800)),
                                ),
                              ],
                            ),
                          ),
                          ...processSteps.whereType<Map>().map((row) {
                            final sNo = int.tryParse('${row['s_no']}') ?? 0;
                            final isHeaderRow = sNo <= 5 || row['is_readonly'] == 1;
                            final plan = (row['planning_date'] ?? '').toString().trim();
                            final actual = (row['actual_date'] ?? '').toString().trim();
                            final isDone = !isHeaderRow && actual.isNotEmpty && actual != '-';
                            return Container(
                              decoration: BoxDecoration(
                                color: isHeaderRow
                                    ? const Color(0xFFFAF5EE)
                                    : (isDone ? const Color(0xFFEAF7EF) : Colors.white),
                                border: const Border(top: BorderSide(color: _border)),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 30,
                                    child: Text(
                                      '$sNo',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: isHeaderRow ? _woodDark : Colors.black87,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    flex: 5,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${row['process_name'] ?? ''}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: isHeaderRow || isDone ? FontWeight.w700 : FontWeight.w500,
                                              color: isHeaderRow ? _woodDark : Colors.black87,
                                            ),
                                          ),
                                        ),
                                        if (isDone)
                                          const Icon(Icons.check_circle_rounded, size: 14, color: _success),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      isHeaderRow ? '' : (plan.isNotEmpty ? plan : '-'),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      isHeaderRow ? '' : (actual.isNotEmpty ? actual : '-'),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDone ? _success : Colors.black45,
                                        fontWeight: isDone ? FontWeight.w800 : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Icon-Referenced Specification Grid
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(Icons.architecture_rounded, 'Door & Woodwork Specs'),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (ctx, constraints) {
                      final cols = constraints.maxWidth > 720 ? 4 : 2;
                      return GridView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          mainAxisExtent: 80,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        children: [
                          _specTile(Icons.door_front_door_rounded, 'Category', '${o['woodwork_category']}'),
                          _specTile(Icons.straighten_rounded, 'Dimensions', '${o['width_inches']}" × ${o['height_inches']}"'),
                          _specTile(Icons.forest_rounded, 'Wood Species', '${o['wood_species']}'),
                          _specTile(Icons.palette_rounded, 'Polish Shade', '${o['polish_shade']}'),
                          _specTile(Icons.crop_square_rounded, 'Frame Section', '${o['frame_section']}'),
                          _specTile(Icons.layers_rounded, 'Thickness', '${o['door_thickness']}'),
                          _specTile(Icons.view_column_rounded, 'Leaf Type', '${o['leaf_type']}'),
                          _specTile(Icons.inventory_2_rounded, 'Quantity', '${o['quantity']} Unit(s)'),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _specTile(Icons.auto_awesome_rounded, 'Carving Pattern', '${o['carving_pattern'] ?? '-'}'),
                  const SizedBox(height: 8),
                  _specTile(Icons.vpn_key_rounded, 'Hardware & Locks', '${o['hardware'] ?? '-'}'),
                ],
              ),
            ),

            if (photos.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle(Icons.photo_camera_rounded, 'Workshop Progress Photos'),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 135,
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
                                  CustomerApiService.instance.mediaUrl(p['photo_url']?.toString()),
                                  width: 120,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 120,
                                    height: 100,
                                    color: _bg,
                                    child: const Icon(Icons.image_not_supported_rounded),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text('${p['stage_name']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: _woodPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: _woodPrimary),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: _woodDark)),
      ],
    );
  }

  Widget _specTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _woodPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: _woodPrimary),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.w600)),
                Text(value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _woodDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
