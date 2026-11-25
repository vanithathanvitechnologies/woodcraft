const express = require('express');
const pool = require('../config/db');
const { authenticateToken, requireRoles } = require('../middleware/auth');
const { catalogUpload } = require('../middleware/upload');
const { generateAiCombinedDoor } = require('../utils/aiDoorGenerator');
const { WOOD_SPECIES } = require('../config/constants');

const router = express.Router();

// Get design catalog (Owner, Sales, Admin — Production has NO Access per spec)
router.get('/', authenticateToken, requireRoles('admin', 'owner', 'sales'), async (req, res) => {
  try {
    const { category, wood_species, search, include_archived, trending } = req.query;
    let sql = 'SELECT * FROM design_catalog WHERE 1=1';
    const params = [];

    if (include_archived !== 'true') {
      sql += ' AND is_archived = 0';
    }
    if (category && category !== 'All') {
      sql += ' AND LOWER(TRIM(category)) = LOWER(TRIM(?))';
      params.push(category);
    }
    if (wood_species && wood_species !== 'All') {
      sql += ' AND wood_species = ?';
      params.push(wood_species);
    }
    if (trending === 'true') {
      sql += ' AND is_trending = 1';
    }
    if (search) {
      sql += ' AND (title LIKE ? OR carving_style LIKE ? OR tags LIKE ? OR wood_species LIKE ? OR category LIKE ?)';
      const like = `%${search}%`;
      params.push(like, like, like, like, like);
    }

    sql += ' ORDER BY is_trending DESC, created_at DESC';
    const [rows] = await pool.query(sql, params);
    res.json({ success: true, designs: rows });
  } catch (err) {
    console.error('Catalog list error:', err);
    res.status(500).json({ success: false, message: 'Failed to fetch design catalog' });
  }
});

// Upload new design(s) to catalog (Admin / Owner ONLY)
router.post(
  '/',
  authenticateToken,
  requireRoles('admin', 'owner'),
  catalogUpload.array('images', 5),
  async (req, res) => {
    try {
      const {
        title,
        category = 'Door',
        carving_style = '',
        wood_species = 'Burma Teak',
        base_price = 25000,
        tags = '',
        description = '',
        is_trending = 0,
        image_url,
      } = req.body;

      if (!title || !String(title).trim()) {
        return res.status(400).json({ success: false, message: 'Design title is required' });
      }

      const uploadedUrls = (req.files || []).map((f) => `/uploads/catalog/${f.filename}`);
      const primaryImage = uploadedUrls[0] || String(image_url || '').trim();
      if (!primaryImage) {
        return res.status(400).json({ success: false, message: 'Please upload a design photo' });
      }
      const extraImages = uploadedUrls.slice(1);

      const [result] = await pool.query(
        `INSERT INTO design_catalog
          (title, category, carving_style, wood_species, base_price, image_url, additional_images, tags, description, is_trending, created_by)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          String(title).trim(),
          String(category || 'Door').trim() || 'Door',
          String(carving_style || '').trim(),
          String(wood_species || 'Burma Teak').trim() || 'Burma Teak',
          Number(base_price) || 0,
          primaryImage,
          JSON.stringify(extraImages),
          String(tags || '').trim(),
          String(description || '').trim(),
          is_trending === 'true' || is_trending === true || Number(is_trending) === 1 ? 1 : 0,
          req.user.id,
        ]
      );

      const [created] = await pool.query('SELECT * FROM design_catalog WHERE id = ?', [result.insertId]);
      res.status(201).json({ success: true, design: created[0] });
    } catch (err) {
      console.error('Catalog upload error:', err);
      res.status(500).json({ success: false, message: 'Failed to upload design' });
    }
  }
);

async function handleCatalogUpdate(req, res) {
  try {
    const { id } = req.params;
    const allowed = [
      'title',
      'category',
      'carving_style',
      'wood_species',
      'base_price',
      'tags',
      'description',
      'is_trending',
      'is_archived',
    ];
    const fields = [];
    const params = [];

    for (const key of allowed) {
      if (req.body[key] !== undefined) {
        fields.push(`${key} = ?`);
        if (key === 'is_trending' || key === 'is_archived') {
          const v = req.body[key];
          params.push(v === true || v === 1 || v === '1' || v === 'true' ? 1 : 0);
        } else if (key === 'base_price') {
          params.push(Number(req.body[key]) || 0);
        } else {
          params.push(String(req.body[key]).trim());
        }
      }
    }

    const uploadedUrls = (req.files || []).map((f) => `/uploads/catalog/${f.filename}`);
    if (uploadedUrls.length) {
      fields.push('image_url = ?');
      params.push(uploadedUrls[0]);
      if (uploadedUrls.length > 1) {
        fields.push('additional_images = ?');
        params.push(JSON.stringify(uploadedUrls.slice(1)));
      }
    }

    if (!fields.length) {
      return res.status(400).json({ success: false, message: 'No fields to update' });
    }

    params.push(id);
    await pool.query(`UPDATE design_catalog SET ${fields.join(', ')} WHERE id = ?`, params);
    const [rows] = await pool.query('SELECT * FROM design_catalog WHERE id = ?', [id]);
    res.json({ success: true, design: rows[0] });
  } catch (err) {
    console.error('Catalog update error:', err);
    res.status(500).json({ success: false, message: 'Failed to update design' });
  }
}

// Update / Edit / Archive / Trending toggle (Admin / Owner ONLY)
router.put('/:id', authenticateToken, requireRoles('admin', 'owner'), catalogUpload.array('images', 5), handleCatalogUpdate);
router.post('/:id', authenticateToken, requireRoles('admin', 'owner'), catalogUpload.array('images', 5), handleCatalogUpdate);

// Delete / Archive design (Admin / Owner ONLY)
router.delete('/:id', authenticateToken, requireRoles('admin', 'owner'), async (req, res) => {
  try {
    if (req.query.permanent === 'true') {
      await pool.query('DELETE FROM design_catalog WHERE id = ?', [req.params.id]);
      return res.json({ success: true, message: 'Design permanently deleted' });
    }
    await pool.query('UPDATE design_catalog SET is_archived = 1 WHERE id = ?', [req.params.id]);
    res.json({ success: true, message: 'Design archived' });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Failed to archive design' });
  }
});

// AI Multi-Design Combiner & Customizer (Combine 2-3 catalog designs + full specs)
router.post('/ai-combine', authenticateToken, requireRoles('admin', 'owner', 'sales'), async (req, res) => {
  try {
    const {
      reference_design_ids = [],
      reference_elements = [],
      woodwork_category = 'Door',
      width_inches = 36,
      height_inches = 84,
      frame_section = '5 x 3 inch',
      door_thickness = '1.75 inch (45mm)',
      leaf_type = 'Single Leaf',
      wood_species = 'Burma Teak',
      carving_pattern = 'Royal Lotus & Pillar',
      polish_shade = 'Natural Teak Matte',
      hardware = 'Antique Brass Handle & Mortise Lock',
      quantity = 1,
      custom_notes = '',
    } = req.body;

    if (!Array.isArray(reference_design_ids) || reference_design_ids.length < 1 || reference_design_ids.length > 5) {
      return res.status(400).json({
        success: false,
        message: 'Select between 1 and 5 catalog reference designs to combine',
      });
    }

    // Fetch selected reference designs for pricing & metadata
    const placeholders = reference_design_ids.map(() => '?').join(',');
    const [refDesigns] = await pool.query(
      `SELECT id, title, base_price, image_url, carving_style, wood_species FROM design_catalog WHERE id IN (${placeholders})`,
      reference_design_ids
    );

    const aiResult = await generateAiCombinedDoor({
      reference_elements,
      woodwork_category,
      width_inches,
      height_inches,
      frame_section,
      door_thickness,
      leaf_type,
      wood_species,
      carving_pattern,
      polish_shade,
      hardware,
      custom_notes,
    });

    // Compute smart cost estimation
    const avgBase =
      refDesigns.length > 0
        ? refDesigns.reduce((sum, d) => sum + Number(d.base_price || 0), 0) / refDesigns.length
        : 28000;
    const areaSqFt = (Number(width_inches) * Number(height_inches)) / 144;
    const areaFactor = Math.max(0.8, areaSqFt / 21); // 36x84 = 21 sqft baseline
    const speciesObj = WOOD_SPECIES.find((w) => w.name === wood_species);
    const woodMultiplier = speciesObj ? speciesObj.multiplier : 1.2;
    const leafMultiplier = leaf_type === 'Double Leaf' ? 1.45 : 1.0;
    const hardwareCost = 4500;
    const polishCost = 3500;

    const unitCost = Math.round(avgBase * areaFactor * woodMultiplier * leafMultiplier + hardwareCost + polishCost);
    const totalEstimatedCost = unitCost * Math.max(1, Number(quantity) || 1);

    res.json({
      success: true,
      ai_output_image_url: aiResult.image_url,
      prompt_used: aiResult.prompt_used,
      engine: aiResult.engine,
      reference_designs: refDesigns,
      cost_estimate: {
        area_sqft: Number(areaSqFt.toFixed(2)),
        unit_cost: unitCost,
        hardware_cost: hardwareCost,
        polish_cost: polishCost,
        quantity: Math.max(1, Number(quantity) || 1),
        total_estimated_cost: totalEstimatedCost,
      },
    });
  } catch (err) {
    console.error('AI combine error:', err);
    res.status(500).json({ success: false, message: 'Failed to generate AI combined design' });
  }
});

module.exports = router;
