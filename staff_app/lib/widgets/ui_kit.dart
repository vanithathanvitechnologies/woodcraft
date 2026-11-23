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
}
