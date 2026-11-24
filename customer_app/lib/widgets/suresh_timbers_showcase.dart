import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Promotional Hero Banner & Complete Achievements Showcase for Suresh Timbers
/// displayed on the Customer App Home Screen.
class SureshTimbersColors {
  static const woodDark = Color(0xFF2D180A);
  static const woodMid = Color(0xFF4A240E);
  static const woodPrimary = Color(0xFF6B3E1D);
  static const brass = Color(0xFFD4A037);
  static const brassSoft = Color(0xFFF3DEC0);
  static const cream = Color(0xFFFAF5EE);
  static const border = Color(0xFFEBE4DA);
  static const emerald = Color(0xFF1B8A5A);
}

class SureshTimbersPromoHero extends StatelessWidget {
  const SureshTimbersPromoHero({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF221107),
            Color(0xFF4A240E),
            Color(0xFF6B3E1D),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: SureshTimbersColors.brass.withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: SureshTimbersColors.woodDark.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Brand Logo + Heritage Pill
          Row(
            children: [
              Container(
                width: 108,
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/app_logo.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: SureshTimbersColors.brass.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: SureshTimbersColors.brass.withValues(alpha: 0.55),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.workspace_premium_rounded, size: 14, color: SureshTimbersColors.brass),
                        SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            'SINCE 1983 • NO. 1 IN TN',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: SureshTimbersColors.brassSoft,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Royal Headline
          const Text(
            'Royal Main Entrance for Your Family',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1.2,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Designed like fine jewellery. Crafted by masters. Tamil Nadu\'s Only Royal Door Brand.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.84),
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),

          // 25-Year Written Warranty Golden Seal Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  SureshTimbersColors.brass.withValues(alpha: 0.22),
                  SureshTimbersColors.brass.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: SureshTimbersColors.brass.withValues(alpha: 0.50),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: SureshTimbersColors.brass,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.verified_user_rounded, size: 22, color: SureshTimbersColors.woodDark),
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '25 Years Written Warranty with Certificate',
                        style: TextStyle(
                          color: SureshTimbersColors.brassSoft,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Laser-branded authenticity seal on every door • 14%–16% moisture-meter verified seasoned teak',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Quick Legacy Highlights Strip
          Row(
            children: [
              _miniHighlight(Icons.history_edu_rounded, '45+ Years', 'Legacy'),
              const SizedBox(width: 8),
              _miniHighlight(Icons.storefront_rounded, '40+ Branches', 'Tamil Nadu'),
              const SizedBox(width: 8),
              _miniHighlight(Icons.trending_up_rounded, '₹100 Cr', 'Group Scale'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniHighlight(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: SureshTimbersColors.brass),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class SureshTimbersShowcaseSection extends StatelessWidget {
  const SureshTimbersShowcaseSection({super.key});

  static const _achievements = [
    (Icons.emoji_events_rounded, '45+ Years', 'Timber Excellence Since 1983', Color(0xFF6B3E1D)),
    (Icons.store_mall_directory_rounded, '40+ Branches', 'Wide Network Across Tamil Nadu', Color(0xFF8C5327)),
    (Icons.account_balance_rounded, '₹100 Crores', 'Suresh Timbers Group Turnover', Color(0xFF5C2E14)),
    (Icons.pie_chart_rounded, '10% Share', 'Teakwood Market Leadership', Color(0xFF7A4924)),
    (Icons.verified_rounded, '25 Years', 'Written Warranty Certificate', Color(0xFF1B8A5A)),
    (Icons.star_rounded, '4.9★ • 98%', 'Rating & Client Retention', Color(0xFFB57F1C)),
  ];

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

  static const _milestones = [
    (
      Icons.gavel_rounded,
      'India\'s First Forest Dept Tie-Up',
      'Official tie-up with the Forest Department for 100% legal hardwood harvesting — every tree comes with a Forest Permit, Transit Pass & Origin Certificate.',
    ),
    (
      Icons.park_rounded,
      'Isha Foundation Sustainable Forestry',
      'Proud partner of Isha Foundation for sustainable forestry and eco-conscious replanting initiatives across Tamil Nadu.',
    ),
    (
      Icons.precision_manufacturing_rounded,
      'India\'s First End-to-End Timber Brand',
      'First company in India to source raw timber directly and transform it in-house into finished royal doors, frames, and millwork.',
    ),
    (
      Icons.qr_code_2_rounded,
      'One-of-a-Kind & Laser-Branded Authenticity',
      'Every royal door is architect-designed once and never repeated — sealed with our laser-branded Suresh Timbers logo against imitations.',
    ),
    (
      Icons.water_drop_rounded,
      '14%–16% Moisture Meter Discipline',
      'Hand-selected mature teak is seasoned to 14%–16% moisture and verified with a digital moisture meter before carpentry begins.',
    ),
    (
      Icons.groups_rounded,
      'Strong Legacy & Leadership Since 1983',
      'Founded by Late Mr. K. Ganesan in 1983 and led by MD Suresh Kannan & Director Geetha, delivering legality, longevity, and legacy.',
    ),
  ];

  static const _workforce = [
    ('15+', 'Senior Architects'),
    ('100+', 'Master Carpenters'),
    ('150+', 'Production Staff'),
    ('250+', 'Sales Team'),
  ];

  static const _clientScale = [
    ('200+', 'Architects & Builders'),
    ('150+', 'Interior Designers'),
    ('600+', 'Retail Homes'),
    ('50+', 'Export Partners'),
  ];

  static const _prestigiousClients = [
    'Madurai Meenakshi Temple',
    'Zoho Corporation',
    'Isha Foundation',
    'State Bank of India',
    'Sri Ramakrishna Tapovanam',
    'KG Constructions',
    'Deejos',
    'Max Properties',
    'Suninfra',
    'Seven Circle Developers',
    'Police Department',
    'Forest College',
    'Vivekananda College',
    'Tamil Nadu Warehouse',
  ];

  static const _craftSteps = [
    ('01', 'Free Consultation', 'Architect guidance & wood selection'),
    ('02', 'Custom Planning', 'Exact dimensions, style & timeline'),
    ('03', 'Master Crafting', 'Moisture-tested carving & finishing'),
    ('04', 'Certified Delivery', 'On-time install + 25-Yr certificate'),
  ];

  void _copyWithNotice(BuildContext context, String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied: $value'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

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
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: SureshTimbersColors.woodDark),
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
        // 1. Key Achievements & Impact Numbers
        _sectionHeader(
          Icons.military_tech_rounded,
          'Our Achievements & Legacy',
          '45+ years of trust, scale, and royal craftsmanship',
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossCount = constraints.maxWidth > 620 ? 3 : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _achievements.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossCount,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                mainAxisExtent: 98,
              ),
              itemBuilder: (_, i) {
                final (icon, metric, subtitle, tint) = _achievements[i];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: SureshTimbersColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: SureshTimbersColors.woodDark.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: tint.withValues(alpha: 0.11),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(icon, size: 17, color: tint),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              metric,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: tint,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF5A4638),
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 22),

        // 2. Signature Royal Doors Showcase Carousel
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

        // 3. Global Certifications & Traceability
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
        const SizedBox(height: 22),

        // 4. Proud Milestones & Why Suresh Timbers
        _sectionHeader(
          Icons.auto_awesome_rounded,
          'Proud Milestones & Guarantees',
          'What sets Suresh Timbers apart across India',
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: SureshTimbersColors.border),
          ),
          child: Column(
            children: List.generate(_milestones.length, (i) {
              final (icon, title, desc) = _milestones[i];
              final isLast = i == _milestones.length - 1;
              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: SureshTimbersColors.cream,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: SureshTimbersColors.brass.withValues(alpha: 0.45),
                            ),
                          ),
                          child: Icon(icon, size: 19, color: SureshTimbersColors.woodPrimary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: SureshTimbersColors.woodDark,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                desc,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF5A4638),
                                  height: 1.38,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (!isLast) ...[
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: SureshTimbersColors.border),
                    ],
                  ],
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 22),

        // 5. Master Workforce & 4-Step Royal Process
        _sectionHeader(
          Icons.engineering_rounded,
          'Strength Behind Every Door',
          '515+ dedicated specialists from forest to finish',
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [SureshTimbersColors.woodDark, SureshTimbersColors.woodMid],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: _workforce.map((item) {
                  final (count, role) = item;
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            count,
                            style: const TextStyle(
                              color: SureshTimbersColors.brass,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            role,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.8,
                              fontWeight: FontWeight.w600,
                              height: 1.15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              const Text(
                '4-STEP ROYAL CRAFTSMANSHIP JOURNEY',
                style: TextStyle(
                  color: SureshTimbersColors.brassSoft,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              ..._craftSteps.map((s) {
                final (num, heading, detail) = s;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: SureshTimbersColors.brass,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          num,
                          style: const TextStyle(
                            color: SureshTimbersColors.woodDark,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 12, color: Colors.white),
                            children: [
                              TextSpan(
                                text: '$heading: ',
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              TextSpan(
                                text: detail,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.78)),
                              ),
                            ],
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
        const SizedBox(height: 22),

        // 6. Prestigious Clients & Client Network Scale
        _sectionHeader(
          Icons.handshake_rounded,
          'Trusted by Iconic Institutions',
          '100% on-time delivery • 24/7 customer support',
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: SureshTimbersColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: _clientScale.map((c) {
                  final (val, label) = c;
                  return Expanded(
                    child: Column(
                      children: [
                        Text(
                          val,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: SureshTimbersColors.woodPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B5748),
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: SureshTimbersColors.border),
              const SizedBox(height: 12),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: _prestigiousClients.map((client) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: SureshTimbersColors.cream,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: SureshTimbersColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_rounded, size: 13, color: SureshTimbersColors.brass),
                        const SizedBox(width: 5),
                        Text(
                          client,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: SureshTimbersColors.woodDark,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // 7. Group Companies & Royal Design Consultation CTA Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFFCF7), Color(0xFFF5E9D6)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: SureshTimbersColors.brass.withValues(alpha: 0.55),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: SureshTimbersColors.woodDark,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(Icons.support_agent_rounded, color: SureshTimbersColors.brass, size: 22),
                  ),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Book a Free Royal Design Consultation',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            color: SureshTimbersColors.woodDark,
                          ),
                        ),
                        Text(
                          'Suresh Mass Marketing Pvt. Ltd. • Group Units: Teak Park & Interio Square',
                          style: TextStyle(fontSize: 11, color: Color(0xFF6B5342)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on_rounded, size: 16, color: SureshTimbersColors.woodPrimary),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'No. 1-5-9/1C, Near Govt Hospital, Kallupatti Main Road, Elumalai – 625535, Madurai, Tamil Nadu',
                      style: TextStyle(fontSize: 11.8, color: SureshTimbersColors.woodDark, height: 1.35),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 15, color: SureshTimbersColors.woodPrimary),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Mon–Fri: 9:00 AM – 6:00 PM • Sat: 9:00 AM – 2:00 PM',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF5A4638)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SureshTimbersColors.woodDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _copyWithNotice(context, 'Phone / WhatsApp', '+91 97876 52526'),
                      icon: const Icon(Icons.call_rounded, size: 16, color: SureshTimbersColors.brass),
                      label: const Text('+91 97876 52526', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: SureshTimbersColors.woodDark,
                        side: const BorderSide(color: SureshTimbersColors.woodPrimary),
                        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _copyWithNotice(context, 'Website', 'https://sureshtimbers.com'),
                      icon: const Icon(Icons.language_rounded, size: 16),
                      label: const Text('sureshtimbers.com', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  '"We don\'t just sell wood — We deliver legality, longevity, and legacy."',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w700,
                    color: SureshTimbersColors.woodPrimary,
                  ),
                ),
              ),
            ],
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
