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

  /// Opens a responsive full-size interactive zoom image popup (zero cropping).
  static void showFullImagePopup(
    BuildContext context, {
    required String imageUrl,
    String? title,
    String? subtitle,
    String? priceText,
    String? badge,
  }) {
    if (imageUrl.isEmpty) return;
    final size = MediaQuery.sizeOf(context);
    final maxW = (size.width * 0.94).clamp(280.0, 960.0);
    final maxH = (size.height * 0.90).clamp(320.0, 920.0);
    final hasFooter = (title != null && title.isNotEmpty) ||
        (subtitle != null && subtitle.isNotEmpty) ||
        (priceText != null && priceText.isNotEmpty);

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.86),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
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
                      if (badge != null && badge.isNotEmpty)
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
                              badge,
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
                            backgroundColor: Colors.black.withValues(alpha: 0.65),
                            foregroundColor: Colors.white,
                          ),
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, size: 22),
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
                              if (title != null && title.isNotEmpty)
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14.5,
                                    color: AppTheme.woodDark,
                                  ),
                                ),
                              if (subtitle != null && subtitle.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (priceText != null && priceText.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Text(
                            priceText,
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
      ),
    );
  }
}
