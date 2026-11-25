import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/app_theme.dart';
import '../../core/constants.dart';
import '../../services/api_service.dart';
import '../../services/pdf_service.dart';
import '../../widgets/door_pictorial_guide.dart';
import '../../widgets/ui_kit.dart';

class ProductionJobDetailScreen extends StatefulWidget {
  final int jobId;
  const ProductionJobDetailScreen({super.key, required this.jobId});

  @override
  State<ProductionJobDetailScreen> createState() => _ProductionJobDetailScreenState();
}

class _ProductionJobDetailScreenState extends State<ProductionJobDetailScreen> {
  Map<String, dynamic>? _job;
  bool _loading = true;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.instance.get('/production/jobs/${widget.jobId}');
      setState(() => _job = Map<String, dynamic>.from(res['job'] as Map));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateStage(int stageNumber) async {
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(UiKit.stageIcon(stageNumber), color: AppTheme.woodPrimary),
            const SizedBox(width: 8),
            Text('Stage $stageNumber'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppConstants.stageName(stageNumber), style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Workshop Note (optional)',
                prefixIcon: Icon(Icons.edit_note_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Update Stage')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _updating = true);
    try {
      final res = await ApiService.instance.patch('/production/jobs/${widget.jobId}/stage', {
        'stage_number': stageNumber,
        'notes': noteCtrl.text.trim(),
      });
      setState(() => _job = Map<String, dynamic>.from(res['job'] as Map));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Updated to Stage $stageNumber: ${AppConstants.stageName(stageNumber)}')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _reportBlocker() async {
    final ctrl = TextEditingController();
    final hasBlocker = _job?['has_blocker'] == 1;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(hasBlocker ? 'Resolve Workshop Blocker?' : 'Report Issue / Hold'),
        content: hasBlocker
            ? Text('Current blocker: ${_job?['blocker_note']}\nMark as resolved?')
            : TextField(
                controller: ctrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Describe issue (e.g., timber shortage, missing hardware)',
                ),
              ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: hasBlocker ? AppTheme.success : AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(hasBlocker ? 'Resolve Blocker' : 'Notify Owner'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final res = await ApiService.instance.post('/production/jobs/${widget.jobId}/blocker', {
        'resolved': hasBlocker,
        'blocker_note': ctrl.text.trim(),
      });
      setState(() => _job = Map<String, dynamic>.from(res['job'] as Map));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _uploadProgressPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 80);
    if (file == null) return;

    final captionCtrl = TextEditingController(text: 'Completed ${_job?['current_stage_name'] ?? ''}');
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Upload Workshop Progress Photo'),
        content: TextField(controller: captionCtrl, decoration: const InputDecoration(labelText: 'Caption')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Upload')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _updating = true);
    try {
      final bytes = await file.readAsBytes();
      await ApiService.instance.uploadMultipart(
        endpoint: '/production/jobs/${widget.jobId}/photos',
        fileField: 'photo',
        fileBytes: bytes,
        filename: file.name,
        fields: {
          'stage_number': '${_job?['current_stage'] ?? 1}',
          'caption': captionCtrl.text.trim(),
        },
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Workshop progress photo uploaded!')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  void _openZoomViewer(String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.5,
              child: Center(child: Image.network(imageUrl, fit: BoxFit.contain)),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _job == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Job Specs')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final job = _job!;
    final currentStage = int.tryParse('${job['current_stage']}') ?? 1;
    final refDesigns = (job['reference_designs'] as List?) ?? [];
    final photos = (job['progress_photos'] as List?) ?? [];
    final aiUrl = ApiService.instance.mediaUrl(job['ai_output_image_url']?.toString());

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.handyman_rounded, color: AppTheme.brass, size: 20),
            const SizedBox(width: 8),
            Text('Job ${job['job_id']}', style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Reprint Technical Job Sheet',
            onPressed: () => PdfService.printWorkshopJobSheet(job, context: context),
            icon: const Icon(Icons.print_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            // Target Date & Privacy Header
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppTheme.woodDark, AppTheme.woodPrimary]),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.brass.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.event_available_rounded, color: AppTheme.brass, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Target Delivery: ${job['expected_delivery_date']}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                        const Text('Technical Workshop View • Door Specs Only',
                            style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: UiKit.priorityColor(job['priority']?.toString()),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${job['priority']}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11.5)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (job['has_blocker'] == 1)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.danger.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppTheme.danger),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('ACTIVE BLOCKER: ${job['blocker_note']}',
                          style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),

            // Zoomable Final AI Output Design
            if (aiUrl.isNotEmpty)
              UiKit.cardContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UiKit.sectionHeader(
                      Icons.door_front_door_rounded,
                      'Final AI Output Design',
                      trailing: UiKit.iconChip(Icons.zoom_in_rounded, 'Tap to Zoom', color: AppTheme.info),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => _openZoomViewer(aiUrl),
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: double.infinity,
                            color: Colors.white,
                            padding: const EdgeInsets.all(10),
                            child: Image.network(
                              aiUrl,
                              height: 320,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox(height: 120, child: Icon(Icons.door_front_door_rounded, size: 54)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Icon-Referenced Measurements & Technical Specs ONLY
            UiKit.cardContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UiKit.sectionHeader(Icons.architecture_rounded, 'Measurements & Door Specs'),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (ctx, constraints) {
                      final cols = constraints.maxWidth > 720 ? 4 : 2;
                      return GridView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          mainAxisExtent: 82,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        children: [
                          UiKit.specTile(Icons.door_front_door_rounded, 'Woodwork Type', '${job['woodwork_category']}'),
                          UiKit.specTile(Icons.straighten_rounded, 'Dimensions', '${job['width_inches']}" W × ${job['height_inches']}" H'),
                          UiKit.specTile(Icons.crop_square_rounded, 'Frame Section', '${job['frame_section']}'),
                          UiKit.specTile(Icons.layers_rounded, 'Thickness', '${job['door_thickness']}'),
                          UiKit.specTile(Icons.view_column_rounded, 'Leaf Type', '${job['leaf_type']}'),
                          UiKit.specTile(Icons.forest_rounded, 'Wood Species', '${job['wood_species']}'),
                          UiKit.specTile(Icons.palette_rounded, 'Polish Shade', '${job['polish_shade']}'),
                          UiKit.specTile(Icons.inventory_2_rounded, 'Quantity', '${job['quantity']} Unit(s)'),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  UiKit.specTile(Icons.auto_awesome_rounded, 'Carving Pattern', '${job['carving_pattern'] ?? '-'}'),
                  const SizedBox(height: 8),
                  UiKit.specTile(Icons.vpn_key_rounded, 'Hardware Cutouts', '${job['hardware'] ?? '-'}'),
                  if ((job['workshop_notes'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    UiKit.specTile(Icons.sticky_note_2_rounded, 'Workshop Notes', '${job['workshop_notes']}',
                        iconColor: AppTheme.warning),
                  ],
                ],
              ),
            ),

            // Reference Designs with assigned Combine Element badges (up to 5)
            if (refDesigns.isNotEmpty)
              UiKit.cardContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UiKit.sectionHeader(Icons.collections_rounded, 'Source Reference Designs & Style Mapping'),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 158,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: refDesigns.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, i) {
                          final r = refDesigns[i];
                          final rId = int.tryParse('${r['id']}') ?? -1;
                          final rUrl = ApiService.instance.mediaUrl(r['image_url']?.toString());
                          final refEls = (job['reference_elements'] as List?) ?? [];
                          String? assignedEl;
                          for (final el in refEls) {
                            if (el is Map && int.tryParse('${el['design_id']}') == rId) {
                              assignedEl = el['element']?.toString();
                              break;
                            }
                          }
                          final meta = assignedEl != null ? CombineElementMeta.forLabel(assignedEl) : null;
                          return GestureDetector(
                            onTap: () => _openZoomViewer(rUrl),
                            child: Container(
                              width: 108,
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: meta != null ? meta.color.withValues(alpha: 0.55) : AppTheme.border,
                                  width: meta != null ? 1.6 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.network(rUrl, fit: BoxFit.contain),
                                        if (meta != null)
                                          Positioned(
                                            top: 0,
                                            right: 0,
                                            child: Container(
                                              width: 20,
                                              height: 20,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(color: meta.color, shape: BoxShape.circle),
                                              child: Text(
                                                '${meta.number}',
                                                style: const TextStyle(
                                                    color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (meta != null)
                                    Text(
                                      meta.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: meta.color),
                                    ),
                                  Text(
                                    '${r['title']}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

            // 8-Stage Work Status Updater with Stage Icons
            UiKit.cardContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UiKit.sectionHeader(
                    Icons.timeline_rounded,
                    'Work Status & Stage Updater',
                    trailing: TextButton.icon(
                      onPressed: _reportBlocker,
                      icon: Icon(
                        job['has_blocker'] == 1 ? Icons.check_circle_rounded : Icons.report_problem_rounded,
                        size: 16,
                        color: job['has_blocker'] == 1 ? AppTheme.success : AppTheme.danger,
                      ),
                      label: Text(
                        job['has_blocker'] == 1 ? 'Resolve' : 'Flag Issue',
                        style: TextStyle(color: job['has_blocker'] == 1 ? AppTheme.success : AppTheme.danger),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...AppConstants.productionStages.map((s) {
                    final num = s['number'] as int;
                    final done = num <= currentStage;
                    final isCurrent = num == currentStage;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isCurrent ? AppTheme.woodPrimary.withValues(alpha: 0.08) : AppTheme.bg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isCurrent ? AppTheme.woodPrimary : AppTheme.border),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: isCurrent
                                  ? AppTheme.woodPrimary
                                  : (done ? AppTheme.success : Colors.grey.shade300),
                              child: Icon(UiKit.stageIcon(num), size: 16, color: done ? Colors.white : Colors.black45),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text('${s['number']}. ${s['name']}',
                                  style: TextStyle(fontSize: 13, fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600)),
                            ),
                            if (isCurrent)
                              UiKit.iconChip(Icons.play_circle_fill_rounded, 'Current', color: AppTheme.woodPrimary)
                            else
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  minimumSize: Size.zero,
                                ),
                                onPressed: _updating ? null : () => _updateStage(num),
                                child: Text(done ? 'Revert' : 'Set', style: const TextStyle(fontSize: 12)),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),

            // Workshop Progress Photo Upload
            UiKit.cardContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UiKit.sectionHeader(Icons.photo_camera_rounded, 'Workshop Progress Photos'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _updating ? null : () => _uploadProgressPhoto(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_rounded, size: 18),
                          label: const Text('Capture'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _updating ? null : () => _uploadProgressPhoto(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_rounded, size: 18),
                          label: const Text('Gallery'),
                        ),
                      ),
                    ],
                  ),
                  if (photos.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 125,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: photos.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, i) {
                          final p = photos[i];
                          final pUrl = ApiService.instance.mediaUrl(p['photo_url']?.toString());
                          return GestureDetector(
                            onTap: () => _openZoomViewer(pUrl),
                            child: Column(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(pUrl, width: 112, height: 95, fit: BoxFit.cover),
                                ),
                                const SizedBox(height: 4),
                                Text('${p['stage_name']}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
