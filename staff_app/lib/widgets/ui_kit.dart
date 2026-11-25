import 'package:flutter/material.dart';
import '../core/app_theme.dart';

class UiKit {
  static IconData stageIcon(int stage) {
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
        return Icons.work_outline_rounded;
    }
  }

  static Color priorityColor(String? priority) {
    switch (priority) {
      case 'Urgent':
        return AppTheme.danger;
      case 'High':
        return AppTheme.warning;
      default:
        return AppTheme.info;
    }
  }

  static Widget sectionHeader(IconData icon, String title, {Widget? trailing}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppTheme.woodPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 17, color: AppTheme.woodPrimary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: AppTheme.textDark),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  static Widget iconChip(IconData icon, String text, {Color color = AppTheme.woodPrimary}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.5, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }

  static Widget specTile(IconData icon, String label, String value, {Color iconColor = AppTheme.woodPrimary}) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppTheme.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppTheme.textDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget moneyPill(IconData icon, String label, String amount, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 4),
                Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: color)),
              ],
            ),
            const SizedBox(height: 4),
            Text(amount,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      ),
    );
  }

  static Widget cardContainer({required Widget child, EdgeInsets padding = const EdgeInsets.all(14)}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: AppTheme.woodDark.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  /// Opens a responsive full-size HD interactive zoom image popup (zero cropping).
  static void showFullImagePopup(
    BuildContext context, {
    required String imageUrl,
    String? title,
    String? subtitle,
    String? priceText,
    String? badge,
  }) {
    if (imageUrl.isEmpty) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (ctx) => _FullImagePopupDialog(
        imageUrl: imageUrl,
        title: title,
        subtitle: subtitle,
        priceText: priceText,
        badge: badge,
      ),
    );
  }
}

class _FullImagePopupDialog extends StatefulWidget {
  final String imageUrl;
  final String? title;
  final String? subtitle;
  final String? priceText;
  final String? badge;

  const _FullImagePopupDialog({
    required this.imageUrl,
    this.title,
    this.subtitle,
    this.priceText,
    this.badge,
  });

  @override
  State<_FullImagePopupDialog> createState() => _FullImagePopupDialogState();
}

class _FullImagePopupDialogState extends State<_FullImagePopupDialog> {
  final TransformationController _transformCtrl = TransformationController();
  double _zoom = 1.0;

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  void _setZoom(double nextZoom) {
    final clamped = nextZoom.clamp(1.0, 5.0);
    setState(() {
      _zoom = clamped;
      if (clamped == 1.0) {
        _transformCtrl.value = Matrix4.identity();
      } else {
        _transformCtrl.value = Matrix4.diagonal3Values(clamped, clamped, 1.0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final maxW = (size.width * 0.96).clamp(280.0, 1180.0);
    final maxH = (size.height * 0.94).clamp(320.0, 1040.0);
    final hasFooter = (widget.title != null && widget.title!.isNotEmpty) ||
        (widget.subtitle != null && widget.subtitle!.isNotEmpty) ||
        (widget.priceText != null && widget.priceText!.isNotEmpty);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.38),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    GestureDetector(
                      onDoubleTap: () => _setZoom(_zoom > 1.2 ? 1.0 : 2.5),
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(10),
                        child: InteractiveViewer(
                          transformationController: _transformCtrl,
                          minScale: 1.0,
                          maxScale: 5.0,
                          onInteractionEnd: (_) {
                            final scale = _transformCtrl.value.getMaxScaleOnAxis();
                            if ((scale - _zoom).abs() > 0.05) {
                              setState(() => _zoom = scale.clamp(1.0, 5.0));
                            }
                          },
                          child: Center(
                            child: Image.network(
                              widget.imageUrl,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                              isAntiAlias: true,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const Center(child: CircularProgressIndicator());
                              },
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  size: 56,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (widget.badge != null && widget.badge!.isNotEmpty)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.brass,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            widget.badge!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.68),
                          foregroundColor: Colors.white,
                        ),
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, size: 22),
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.68),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              tooltip: 'Zoom Out',
                              onPressed: _zoom > 1.05 ? () => _setZoom(_zoom - 0.6) : null,
                              icon: const Icon(Icons.remove_rounded, size: 18, color: Colors.white),
                            ),
                            InkWell(
                              onTap: () => _setZoom(1.0),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: Text(
                                  '${(_zoom * 100).round()}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              tooltip: 'Zoom In',
                              onPressed: _zoom < 4.9 ? () => _setZoom(_zoom + 0.6) : null,
                              icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (hasFooter)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  decoration: const BoxDecoration(
                    color: AppTheme.bg,
                    border: Border(top: BorderSide(color: AppTheme.border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.title != null && widget.title!.isNotEmpty)
                              Text(
                                widget.title!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.5,
                                  color: AppTheme.woodDark,
                                ),
                              ),
                            if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                widget.subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (widget.priceText != null && widget.priceText!.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Text(
                          widget.priceText!,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: AppTheme.woodPrimary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
