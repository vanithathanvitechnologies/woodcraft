import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import 'ui_kit.dart';

/// Metadata for each of the 5 AI Combine Elements matching the color-coded guide.
class CombineElementMeta {
  final int number;
  final String key;
  final String label;
  final Color color;
  final String defaultDescription;

  const CombineElementMeta({
    required this.number,
    required this.key,
    required this.label,
    required this.color,
    required this.defaultDescription,
  });

  static const List<CombineElementMeta> all = [
    CombineElementMeta(
      number: 1,
      key: 'frame',
      label: 'Frame Style',
      color: Color(0xFF2563EB), // Blue
      defaultDescription: 'Full outer wooden frame & left/right carved pillars',
    ),
    CombineElementMeta(
      number: 2,
      key: 'center',
      label: 'Center Carving',
      color: Color(0xFFEA580C), // Orange
      defaultDescription: 'Main carving artwork inside the door leaf',
    ),
    CombineElementMeta(
      number: 3,
      key: 'border',
      label: 'Border / Polish Finish',
      color: Color(0xFF9333EA), // Purple
      defaultDescription: 'Wood tone, polish shine & inner border molding',
    ),
    CombineElementMeta(
      number: 4,
      key: 'crown',
      label: 'Top Arch & Crown',
      color: Color(0xFFDC2626), // Red
      defaultDescription: 'Curved top arch, temple carving & crown header only',
    ),
    CombineElementMeta(
      number: 5,
      key: 'panel',
      label: 'Panel Layout',
      color: Color(0xFF16A34A), // Green
      defaultDescription: 'Full inner door shutter & panel layout',
    ),
  ];

  static CombineElementMeta forLabel(String label) {
    final low = label.trim().toLowerCase();
    if (low.contains('frame')) return all[0];
    if (low.contains('center') || low.contains('carving')) return all[1];
    if (low.contains('border') || low.contains('polish') || low.contains('finish')) return all[2];
    if (low.contains('arch') || low.contains('crown') || low.contains('top')) return all[3];
    if (low.contains('panel') || low.contains('layout')) return all[4];
    return all[0];
  }

  static CombineElementMeta forKey(String key) {
    return all.firstWhere((e) => e.key == key, orElse: () => all[0]);
  }
}

/// Resolved source catalog mapping for a single combine element slot.
class PictorialElementItem {
  final CombineElementMeta meta;
  final int designId;
  final String designTitle;
  final String designImageUrl;
  final bool isExplicit;
  final String description;

  const PictorialElementItem({
    required this.meta,
    required this.designId,
    required this.designTitle,
    required this.designImageUrl,
    required this.isExplicit,
    required this.description,
  });
}

/// Interactive Pictorial Breakdown matching the 5-Combine-Elements Guide diagram:
/// Shows the generated HD door in the center with exact color-coded zone boxes,
/// numbered circular badges (1..5), leader callout lines, and source catalog
/// thumbnails + titles for each style element.
class DoorElementsPictorialCard extends StatefulWidget {
  final String category;
  final String polishShade;
  final String generatedImageUrl;
  final List<PictorialElementItem> items;
  final Map<String, Rect>? normalizedRegions;
  final double imageAspect;
  final VoidCallback? onTapMainImage;

  const DoorElementsPictorialCard({
    super.key,
    required this.category,
    required this.polishShade,
    required this.generatedImageUrl,
    required this.items,
    this.normalizedRegions,
    this.imageAspect = 0.75,
    this.onTapMainImage,
  });

  @override
  State<DoorElementsPictorialCard> createState() => _DoorElementsPictorialCardState();
}

class _DoorElementsPictorialCardState extends State<DoorElementsPictorialCard> {
  String? _activeKey;

  Map<String, PictorialElementItem> get _byKey {
    final m = <String, PictorialElementItem>{};
    for (final it in widget.items) {
      m[it.meta.key] = it;
    }
    return m;
  }

  Map<String, Rect> get _regions {
    const defaults = <String, Rect>{
      'crown': Rect.fromLTWH(0.03, 0.02, 0.94, 0.16),
      'frame': Rect.fromLTWH(0.05, 0.17, 0.90, 0.80),
      'panel': Rect.fromLTWH(0.16, 0.18, 0.68, 0.77),
      'center': Rect.fromLTWH(0.22, 0.24, 0.56, 0.64),
      'border': Rect.fromLTWH(0.80, 0.62, 0.09, 0.27),
    };
    if (widget.normalizedRegions == null || widget.normalizedRegions!.isEmpty) {
      return defaults;
    }
    return {
      for (final k in defaults.keys) k: widget.normalizedRegions![k] ?? defaults[k]!,
    };
  }

  @override
  Widget build(BuildContext context) {
    final byKey = _byKey;
    final regions = _regions;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: AppTheme.woodDark.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Dark wood header banner (matching reference guide)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2D1609), Color(0xFF472410), Color(0xFF2D1609)],
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Custom ${widget.category} — ${widget.items.length} Selected ${widget.items.length == 1 ? 'Element' : 'Elements'} Guide',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Each color highlights only the exact areas & source catalog designs you selected',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),

          // Responsive Diagram Body
          LayoutBuilder(
            builder: (ctx, constraints) {
              final isWide = constraints.maxWidth >= 760;
              if (isWide) {
                return _buildWideDiagram(byKey, regions, constraints.maxWidth);
              }
              return _buildCompactDiagram(byKey, regions);
            },
          ),

          // Bottom Legend Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF3ECE2),
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 6,
              children: CombineElementMeta.all.where((m) => byKey.containsKey(m.key)).map((m) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: m.color, shape: BoxShape.circle),
                      child: Text(
                        '${m.number}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      m.label,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.woodDark),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Desktop / Tablet 3-column pictorial layout identical to the reference diagram:
  /// Left callouts (4, 1, 5) — Center HD door with color zones + leader lines — Right callouts (2, 3)
  Widget _buildWideDiagram(
    Map<String, PictorialElementItem> byKey,
    Map<String, Rect> regions,
    double totalWidth,
  ) {
    final diagramHeight = (totalWidth * 0.64).clamp(560.0, 720.0);
    final sideCardW = (totalWidth * 0.275).clamp(220.0, 315.0);
    final gapW = (totalWidth * 0.032).clamp(22.0, 42.0);
    final doorBoxW = (totalWidth - (sideCardW * 2) - (gapW * 2) - 32).clamp(280.0, 480.0);
    final doorBoxH = diagramHeight - 36;
    final doorLeft = (totalWidth - doorBoxW) / 2.0;
    const doorTop = 18.0;

    const cardH = 148.0;
    final leftX = 16.0;
    final rightX = totalWidth - 16.0 - sideCardW;

    final crownCardY = 26.0;
    final frameCardY = (diagramHeight - cardH) / 2.0;
    final panelCardY = diagramHeight - cardH - 26.0;
    final centerCardY = diagramHeight * 0.20;
    final borderCardY = diagramHeight * 0.58;

    final doorRect = Rect.fromLTWH(doorLeft, doorTop, doorBoxW, doorBoxH);
    final cardRects = <String, Rect>{
      'crown': Rect.fromLTWH(leftX, crownCardY, sideCardW, cardH),
      'frame': Rect.fromLTWH(leftX, frameCardY, sideCardW, cardH),
      'panel': Rect.fromLTWH(leftX, panelCardY, sideCardW, cardH),
      'center': Rect.fromLTWH(rightX, centerCardY, sideCardW, cardH),
      'border': Rect.fromLTWH(rightX, borderCardY, sideCardW, cardH),
    };

    return SizedBox(
      height: diagramHeight,
      width: totalWidth,
      child: Stack(
        children: [
          // Center HD Generated Door Container
          Positioned.fromRect(
            rect: doorRect,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onTapMainImage,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.woodDark.withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Image.network(
                    widget.generatedImageUrl,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    isAntiAlias: true,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image_outlined, size: 48, color: AppTheme.textMuted),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Vector Zone Overlays + Leader Callout Lines + Numbered Door Badges
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _PictorialOverlayPainter(
                  doorContainerRect: doorRect.deflate(10),
                  regions: regions,
                  cardRects: cardRects,
                  visibleKeys: byKey.keys.toSet(),
                  activeKey: _activeKey,
                  drawLeaderLines: true,
                  doorAspect: widget.imageAspect,
                ),
              ),
            ),
          ),

          // Left & Right Interactive Color-Coded Source Cards
          for (final entry in cardRects.entries)
            if (byKey.containsKey(entry.key))
              Positioned.fromRect(
                rect: entry.value,
                child: _buildCalloutCard(byKey[entry.key]!),
              ),
        ],
      ),
    );
  }

  /// Mobile-friendly vertical pictorial layout:
  /// Annotated HD Door at top with all 5 numbered zone overlays + 5 source cards underneath.
  Widget _buildCompactDiagram(
    Map<String, PictorialElementItem> byKey,
    Map<String, Rect> regions,
  ) {
    final orderedKeys = ['crown', 'frame', 'panel', 'center', 'border'];
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onTapMainImage,
              child: Container(
                height: 430,
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border, width: 1.5),
                ),
                child: LayoutBuilder(
                  builder: (ctx, box) {
                    final innerRect = Rect.fromLTWH(0, 0, box.maxWidth, box.maxHeight);
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          widget.generatedImageUrl,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          isAntiAlias: true,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(child: CircularProgressIndicator());
                          },
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image_outlined, size: 48, color: AppTheme.textMuted),
                          ),
                        ),
                        IgnorePointer(
                          child: CustomPaint(
                            painter: _PictorialOverlayPainter(
                              doorContainerRect: innerRect,
                              regions: regions,
                              cardRects: const {},
                              visibleKeys: byKey.keys.toSet(),
                              activeKey: _activeKey,
                              drawLeaderLines: false,
                              doorAspect: widget.imageAspect,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...orderedKeys.where(byKey.containsKey).map(
                (k) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildCalloutCard(byKey[k]!, compact: true),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildCalloutCard(PictorialElementItem item, {bool compact = false}) {
    final color = item.meta.color;
    final isHighlighted = _activeKey == item.meta.key;
    final prefix = item.isExplicit ? 'From:' : 'Base:';

    return MouseRegion(
      onEnter: (_) => setState(() => _activeKey = item.meta.key),
      onExit: (_) => setState(() => _activeKey = null),
      child: GestureDetector(
        onTap: () {
          setState(() => _activeKey = isHighlighted ? null : item.meta.key);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: color,
              width: isHighlighted ? 2.8 : 1.9,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: isHighlighted ? 0.22 : 0.08),
                blurRadius: isHighlighted ? 14 : 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Clickable mini source catalog thumbnail
              MouseRegion(
                cursor: item.designImageUrl.isNotEmpty ? SystemMouseCursors.click : MouseCursor.defer,
                child: GestureDetector(
                  onTap: item.designImageUrl.isNotEmpty
                      ? () => UiKit.showFullImagePopup(
                            context,
                            imageUrl: item.designImageUrl,
                            title: item.designTitle,
                            subtitle: '${item.meta.number}. ${item.meta.label}',
                            badge: item.meta.label.toUpperCase(),
                          )
                      : null,
                  child: Container(
                    width: compact ? 62 : 64,
                    height: compact ? 86 : 118,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDFAF6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withValues(alpha: 0.35)),
                    ),
                    child: item.designImageUrl.isNotEmpty
                        ? Image.network(
                            item.designImageUrl,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.medium,
                            errorBuilder: (_, __, ___) => Icon(Icons.door_front_door_rounded, color: color, size: 28),
                          )
                        : Icon(Icons.door_front_door_rounded, color: color, size: 28),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          child: Text(
                            '${item.meta.number}',
                            style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            item.meta.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.woodDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$prefix ${item.designTitle}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: color,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Colors.black54,
                        height: 1.25,
                      ),
                    ),
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

class _PictorialOverlayPainter extends CustomPainter {
  final Rect doorContainerRect;
  final Map<String, Rect> regions;
  final Map<String, Rect> cardRects;
  final Set<String> visibleKeys;
  final String? activeKey;
  final bool drawLeaderLines;
  final double doorAspect;

  _PictorialOverlayPainter({
    required this.doorContainerRect,
    required this.regions,
    required this.cardRects,
    required this.visibleKeys,
    required this.activeKey,
    required this.drawLeaderLines,
    this.doorAspect = 0.75,
  });

  Rect _mapRect(String key) {
    final norm = regions[key] ?? const Rect.fromLTWH(0.1, 0.1, 0.8, 0.8);
    // Use exact server-reported rendered aspect ratio so zone boxes hug the door pixel-perfectly
    final cW = doorContainerRect.width;
    final cH = doorContainerRect.height;
    final aspect = doorAspect.clamp(0.45, 1.35);
    double rw = cW;
    double rh = rw / aspect;
    if (rh > cH) {
      rh = cH;
      rw = rh * aspect;
    }
    final ox = doorContainerRect.left + (cW - rw) / 2.0;
    final oy = doorContainerRect.top + (cH - rh) / 2.0;
    return Rect.fromLTWH(
      ox + norm.left * rw,
      oy + norm.top * rh,
      norm.width * rw,
      norm.height * rh,
    );
  }

  void _drawDashedRRect(Canvas canvas, Rect rect, Paint paint) {
    const dash = 8.0;
    const gap = 5.0;
    void drawSeg(Offset a, Offset b) {
      final total = (b - a).distance;
      final dir = (b - a) / (total == 0 ? 1 : total);
      double dist = 0;
      while (dist < total) {
        final end = (dist + dash).clamp(0.0, total);
        canvas.drawLine(a + dir * dist, a + dir * end, paint);
        dist += dash + gap;
      }
    }

    drawSeg(rect.topLeft, rect.topRight);
    drawSeg(rect.topRight, rect.bottomRight);
    drawSeg(rect.bottomRight, rect.bottomLeft);
    drawSeg(rect.bottomLeft, rect.topLeft);
  }

  void _drawNumberBadge(Canvas canvas, Offset center, int number, Color color, bool highlight) {
    final r = highlight ? 14.5 : 12.5;
    canvas.drawCircle(center, r + 2.2, Paint()..color = Colors.white);
    canvas.drawCircle(center, r, Paint()..color = color);
    final tp = TextPainter(
      text: TextSpan(
        text: '$number',
        style: TextStyle(
          color: Colors.white,
          fontSize: highlight ? 13 : 11.5,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final zCrown = _mapRect('crown');
    final zFrame = _mapRect('frame');
    final zPanel = _mapRect('panel');
    final zCenter = _mapRect('center');
    final zBorder = _mapRect('border');

    void drawZone(String key, Rect rect, Color color, {bool dashed = false}) {
      final isActive = activeKey == key;
      final strokeW = isActive ? 3.4 : 2.2;
      if (isActive) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(6)),
          Paint()..color = color.withValues(alpha: 0.14),
        );
      }
      final paint = Paint()
        ..color = color.withValues(alpha: activeKey == null || isActive ? 0.95 : 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW;
      if (dashed) {
        _drawDashedRRect(canvas, rect, paint);
      } else {
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), paint);
      }
    }

    if (visibleKeys.contains('frame')) drawZone('frame', zFrame, CombineElementMeta.all[0].color, dashed: true);
    if (visibleKeys.contains('panel')) drawZone('panel', zPanel, CombineElementMeta.all[4].color, dashed: true);
    if (visibleKeys.contains('center')) drawZone('center', zCenter, CombineElementMeta.all[1].color, dashed: false);
    if (visibleKeys.contains('border')) drawZone('border', zBorder, CombineElementMeta.all[2].color, dashed: false);
    if (visibleKeys.contains('crown')) drawZone('crown', zCrown, CombineElementMeta.all[3].color, dashed: false);

    // Bent leader lines connecting side callout cards to door zones (wide view)
    if (drawLeaderLines && cardRects.isNotEmpty) {
      final targets = <String, Offset>{
        'crown': Offset(zCrown.left + 12, zCrown.center.dy),
        'frame': Offset(zFrame.left, zFrame.top + zFrame.height * 0.36),
        'panel': Offset(zPanel.left + 6, zPanel.bottom - 26),
        'center': Offset(zCenter.right - 6, zCenter.top + zCenter.height * 0.34),
        'border': Offset(zBorder.right, zBorder.center.dy),
      };

      for (final m in CombineElementMeta.all) {
        if (!visibleKeys.contains(m.key)) continue;
        final card = cardRects[m.key];
        final target = targets[m.key];
        if (card == null || target == null) continue;

        final isLeft = card.center.dx < doorContainerRect.center.dx;
        final isActive = activeKey == m.key;
        final alpha = (activeKey == null || isActive) ? 0.95 : 0.28;
        final linePaint = Paint()
          ..color = m.color.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isActive ? 3.0 : 2.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

        final start = isLeft ? Offset(card.right, card.center.dy) : Offset(card.left, card.center.dy);
        final elbow = isLeft ? Offset(card.right + 16, card.center.dy) : Offset(card.left - 16, card.center.dy);
        final path = Path()
          ..moveTo(start.dx, start.dy)
          ..lineTo(elbow.dx, elbow.dy)
          ..lineTo(target.dx, target.dy);
        canvas.drawPath(path, linePaint);

        // White-ringed target dot on the door zone
        canvas.drawCircle(target, 6.0, Paint()..color = Colors.white);
        canvas.drawCircle(target, 3.8, Paint()..color = m.color.withValues(alpha: alpha));
      }
    }

    // Numbered badges right on each selected zone of the door
    if (visibleKeys.contains('crown')) {
      _drawNumberBadge(canvas, zCrown.center, 4, CombineElementMeta.all[3].color, activeKey == 'crown');
    }
    if (visibleKeys.contains('frame')) {
      _drawNumberBadge(
        canvas,
        Offset(zFrame.left + ((zPanel.left - zFrame.left) * 0.52).clamp(12.0, 26.0), zFrame.top + zFrame.height * 0.48),
        1,
        CombineElementMeta.all[0].color,
        activeKey == 'frame',
      );
    }
    if (visibleKeys.contains('panel')) {
      _drawNumberBadge(
        canvas,
        Offset(zPanel.left + (zPanel.width * 0.24).clamp(18.0, 56.0), zPanel.bottom - 16),
        5,
        CombineElementMeta.all[4].color,
        activeKey == 'panel',
      );
    }
    if (visibleKeys.contains('center')) {
      _drawNumberBadge(canvas, zCenter.center, 2, CombineElementMeta.all[1].color, activeKey == 'center');
    }
    if (visibleKeys.contains('border')) {
      _drawNumberBadge(
        canvas,
        Offset(zBorder.center.dx, zBorder.bottom - 18),
        3,
        CombineElementMeta.all[2].color,
        activeKey == 'border',
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PictorialOverlayPainter oldDelegate) {
    return oldDelegate.activeKey != activeKey ||
        oldDelegate.doorContainerRect != doorContainerRect ||
        oldDelegate.drawLeaderLines != drawLeaderLines ||
        oldDelegate.doorAspect != doorAspect ||
        oldDelegate.regions != regions ||
        oldDelegate.visibleKeys.length != visibleKeys.length ||
        !oldDelegate.visibleKeys.containsAll(visibleKeys);
  }
}
