import 'package:flutter/material.dart';

/// Signature Royal Creations & Certifications Showcase for Suresh Timbers
/// displayed on the Customer App Home Screen.
class SureshTimbersColors {
  static const woodDark = Color(0xFF2D180A);
  static const woodPrimary = Color(0xFF6B3E1D);
  static const brass = Color(0xFFD4A037);
  static const cream = Color(0xFFFAF5EE);
  static const border = Color(0xFFEBE4DA);
  static const emerald = Color(0xFF1B8A5A);
}

class SureshTimbersShowcaseSection extends StatelessWidget {
  const SureshTimbersShowcaseSection({super.key});

  static const _featuredDoors = [
    (
      'assets/images/showcase/royal_heritage_door.jpg',
      'Royal Heritage Main Entrance',
      '25-Yr Written Warranty',
      'Deep handcrafted traditional carvings with Raja Nilai pillars in seasoned mature Burma Teak.',
    ),
    (
      'assets/images/showcase/south_indian_main_door.jpg',
      'South Indian Heritage Door',
      'Traditional Pillars',
      'Classic South Indian architectural main entrance featuring solid teak double shutters & heritage crown.',
    ),
    (
      'assets/images/showcase/grand_royal_door.jpg',
      'Grand Royal Carved Entrance',
      'Brass & Teak Craft',
      'Heavy-duty premium teak entrance door with intricate hand-carved relief and royal brass border work.',
    ),
    (
      'assets/images/showcase/chettinad_brass_door.jpg',
      'Chettinad Brass Double Door',
      'Double Leaf Teak',
      'Signature Chettinad studded brass medallion double shutter built for timeless family entrances.',
    ),
    (
      'assets/images/showcase/temple_pooja_door.jpg',
      'Temple Arch Pooja Door',
      'Sacred Craftsmanship',
      'Master-carved temple mantapa arch and traditional Nilai frame crafted for serene pooja rooms.',
    ),
    (
      'assets/images/showcase/peacock_classic_door.jpg',
      'Classic Peacock Single Door',
      'Minimalist Luxury',
      'Clean contemporary teak frame accented with an ornate brass peacock motif and smooth natural polish.',
    ),
  ];

  static const _certifications = [
    (Icons.verified_rounded, 'ISO 9001', 'Quality Management'),
    (Icons.forest_rounded, 'FSC Certified', 'Sustainable Forestry'),
    (Icons.eco_rounded, 'PEFC Certified', 'Chain of Custody'),
    (Icons.public_rounded, 'Import & Export', 'Global Trade License'),
    (Icons.description_rounded, '100% Traceable', 'Permit & Origin Cert'),
  ];

  void _openDoorPreview(
    BuildContext context,
    String assetPath,
    String title,
    String badge,
    String description,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  children: [
                    Container(
                      height: 360,
                      width: double.infinity,
                      color: const Color(0xFFFDFBF8),
                      padding: const EdgeInsets.all(10),
                      child: InteractiveViewer(
                        child: Image.asset(assetPath, fit: BoxFit.contain),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: SureshTimbersColors.woodDark,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            color: SureshTimbersColors.brass,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.6),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: SureshTimbersColors.woodDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: SureshTimbersColors.cream,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: SureshTimbersColors.border),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.verified_user_rounded, size: 16, color: SureshTimbersColors.emerald),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Suresh Timbers Genuine Teak • 25-Year Written Warranty Available',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: SureshTimbersColors.woodDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Signature Royal Doors Showcase Carousel
        _sectionHeader(
          Icons.door_front_door_rounded,
          'Signature Royal Creations',
          'Tap any Suresh Timbers masterpiece to inspect details',
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 248,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _featuredDoors.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (ctx, i) {
              final (asset, title, badge, desc) = _featuredDoors[i];
              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _openDoorPreview(ctx, asset, title, badge, desc),
                child: Container(
                  width: 168,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: SureshTimbersColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: SureshTimbersColors.woodDark.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(
                              color: const Color(0xFFFDFBF8),
                              padding: const EdgeInsets.all(6),
                              child: Image.asset(asset, fit: BoxFit.contain),
                            ),
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: SureshTimbersColors.woodDark.withValues(alpha: 0.88),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  badge,
                                  style: const TextStyle(
                                    color: SureshTimbersColors.brass,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(top: BorderSide(color: SureshTimbersColors.border)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: SureshTimbersColors.woodDark,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            const Row(
                              children: [
                                Icon(Icons.zoom_in_rounded, size: 12, color: SureshTimbersColors.woodPrimary),
                                SizedBox(width: 4),
                                Text(
                                  'Tap to view',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: SureshTimbersColors.woodPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 22),

        // 2. Global Certifications & Traceability
        _sectionHeader(
          Icons.verified_rounded,
          'Certifications & Standards',
          '100% legal, certified, and traceable timber',
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _certifications.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final (icon, title, sub) = _certifications[i];
              return Container(
                width: 148,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFFFFF), Color(0xFFFAF3E8)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: SureshTimbersColors.brass.withValues(alpha: 0.45),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 18, color: SureshTimbersColors.emerald),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: SureshTimbersColors.woodDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7A5A43),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _sectionHeader(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: SureshTimbersColors.woodPrimary.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 19, color: SureshTimbersColors.woodPrimary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w900,
                  color: SureshTimbersColors.woodDark,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF7A5A43),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
