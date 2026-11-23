const express = require('express');
const pool = require('../config/db');
const { authenticateToken, requireRoles } = require('../middleware/auth');
const { progressUpload } = require('../middleware/upload');
const { getStageName, PRODUCTION_STAGES } = require('../config/constants');

const router = express.Router();

// STRICT PRIVACY-PROTECTED COLUMNS ONLY:
// Customer Name, Mobile Number, Delivery Address, and Cost/Pricing are NEVER selected or returned!
const RESTRICTED_JOB_COLUMNS = `
  o.id,
  o.job_id,
  o.woodwork_category,
  o.width_inches,
  o.height_inches,
  o.frame_section,
  o.door_thickness,
  o.leaf_type,
  o.wood_species,
  o.carving_pattern,
  o.polish_shade,
  o.hardware,
  o.quantity,
  o.workshop_notes,
  o.reference_design_ids,
  o.reference_elements,
  o.ai_output_image_url,
  o.expected_delivery_date,
  o.priority,
  o.current_stage,
  o.current_stage_name,
  o.has_blocker,
  o.blocker_note,
  o.created_at,
  o.updated_at
`;

function parseJsonSafe(val, fallback = []) {
  if (!val) return fallback;
  if (typeof val === 'object') return val;
  try {
    return JSON.parse(val);
  } catch {
    return fallback;
  }
}

async function enrichRestrictedJob(job) {
  const refIds = parseJsonSafe(job.reference_design_ids, []);
  let reference_designs = [];
  if (refIds.length > 0) {
    const placeholders = refIds.map(() => '?').join(',');
    // Notice: base_price is omitted here too for strict privacy!
    const [refs] = await pool.query(
      `SELECT id, title, category, carving_style, wood_species, image_url FROM design_catalog WHERE id IN (${placeholders})`,
      refIds
    );
    reference_designs = refs;
  }

  const [history] = await pool.query(
    `SELECT h.id, h.stage_number, h.stage_name, h.notes, h.is_blocker, h.created_at, u.name AS updated_by_name
     FROM order_stage_history h
     LEFT JOIN users u ON u.id = h.updated_by
     WHERE h.order_id = ?
     ORDER BY h.created_at ASC`,
    [job.id]
  );

  const [photos] = await pool.query(
    `SELECT p.id, p.stage_number, p.stage_name, p.photo_url, p.caption, p.created_at, u.name AS uploaded_by_name
     FROM order_progress_photos p
     LEFT JOIN users u ON u.id = p.uploaded_by
     WHERE p.order_id = ?
     ORDER BY p.created_at DESC`,
    [job.id]
  );

  return {
    ...job,
    reference_design_ids: refIds,
    reference_elements: parseJsonSafe(job.reference_elements, []),
    reference_designs,
    stage_history: history,
    progress_photos: photos,
  };
}

// Get Production Job Queue (New / In Progress / Completed, sorted by delivery date)
router.get('/jobs', authenticateToken, requireRoles('production', 'owner', 'sales', 'admin'), async (req, res) => {
  try {
    const { filter = 'all', search } = req.query;
    let sql = `SELECT ${RESTRICTED_JOB_COLUMNS} FROM orders o WHERE o.is_dispatched = 1`;
    const params = [];

    if (filter === 'new') {
      sql += ' AND o.current_stage = 1';
    } else if (filter === 'in_progress') {
      sql += ' AND o.current_stage > 1 AND o.current_stage < 8';
    } else if (filter === 'completed') {
      sql += ' AND o.current_stage = 8';
    }

    if (search) {
      sql += ' AND (o.job_id LIKE ? OR o.woodwork_category LIKE ? OR o.wood_species LIKE ? OR o.carving_pattern LIKE ?)';
      const like = `%${search}%`;
      params.push(like, like, like, like);
    }

    sql += ' ORDER BY FIELD(o.priority, "Urgent", "High", "Normal"), o.expected_delivery_date ASC';

    const [rows] = await pool.query(sql, params);
    const formatted = rows.map((r) => ({
      ...r,
      reference_design_ids: parseJsonSafe(r.reference_design_ids, []),
      reference_elements: parseJsonSafe(r.reference_elements, []),
    }));

    res.json({ success: true, stages: PRODUCTION_STAGES, jobs: formatted });
  } catch (err) {
    console.error('Production jobs error:', err);
    res.status(500).json({ success: false, message: 'Failed to load workshop job queue' });
  }
});

// QR Code Scan Lookup by Job ID (e.g. SUW-2026-0001)
router.get('/jobs/by-job-id/:jobId', authenticateToken, requireRoles('production', 'owner', 'sales', 'admin'), async (req, res) => {
  try {
    const [rows] = await pool.query(
      `SELECT ${RESTRICTED_JOB_COLUMNS} FROM orders o WHERE o.job_id = ? LIMIT 1`,
      [req.params.jobId.trim()]
    );
    if (!rows.length) {
      return res.status(404).json({ success: false, message: 'Job ID not found' });
    }
    const detailed = await enrichRestrictedJob(rows[0]);
    res.json({ success: true, job: detailed });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Failed to look up job' });
  }
});

// Get Single Restricted Job Detail
router.get('/jobs/:id', authenticateToken, requireRoles('production', 'owner', 'sales', 'admin'), async (req, res) => {
  try {
    const [rows] = await pool.query(
      `SELECT ${RESTRICTED_JOB_COLUMNS} FROM orders o WHERE o.id = ? LIMIT 1`,
      [req.params.id]
    );
    if (!rows.length) {
      return res.status(404).json({ success: false, message: 'Job not found' });
    }
    const detailed = await enrichRestrictedJob(rows[0]);
    res.json({ success: true, job: detailed, stages: PRODUCTION_STAGES });
  } catch (err) {
    console.error('Production job detail error:', err);
    res.status(500).json({ success: false, message: 'Failed to load job details' });
  }
});

// Update Work Status & Stage (1 to 8) — Production Team (and Admin)
router.patch('/jobs/:id/stage', authenticateToken, requireRoles('production', 'admin'), async (req, res) => {
  try {
    const stageNumber = Number(req.body.stage_number);
    const notes = req.body.notes || '';
    const clearBlocker = req.body.clear_blocker !== false;

    if (!stageNumber || stageNumber < 1 || stageNumber > 8) {
      return res.status(400).json({ success: false, message: 'Valid stage_number (1 to 8) is required' });
    }

    const stageName = getStageName(stageNumber);

    await pool.query(
      `UPDATE orders
       SET current_stage = ?,
           current_stage_name = ?,
           assigned_production_user_id = COALESCE(assigned_production_user_id, ?),
           has_blocker = CASE WHEN ? THEN 0 ELSE has_blocker END,
           blocker_note = CASE WHEN ? THEN NULL ELSE blocker_note END
       WHERE id = ?`,
      [stageNumber, stageName, req.user.id, clearBlocker ? 1 : 0, clearBlocker ? 1 : 0, req.params.id]
    );

    await pool.query(
      'INSERT INTO order_stage_history (order_id, stage_number, stage_name, updated_by, notes, is_blocker) VALUES (?, ?, ?, ?, ?, 0)',
      [req.params.id, stageNumber, stageName, req.user.id, notes || `Moved to ${stageName}`]
    );

    const [rows] = await pool.query(`SELECT ${RESTRICTED_JOB_COLUMNS} FROM orders o WHERE o.id = ?`, [req.params.id]);
    const detailed = await enrichRestrictedJob(rows[0]);
    res.json({ success: true, job: detailed });
  } catch (err) {
    console.error('Stage update error:', err);
    res.status(500).json({ success: false, message: 'Failed to update production stage' });
  }
});

// Report Issue / Hold Blocker (notifies Business Owner immediately)
router.post('/jobs/:id/blocker', authenticateToken, requireRoles('production', 'admin'), async (req, res) => {
  try {
    const { blocker_note, resolved = false } = req.body;
    const [existing] = await pool.query('SELECT current_stage, current_stage_name FROM orders WHERE id = ?', [req.params.id]);
    if (!existing.length) return res.status(404).json({ success: false, message: 'Job not found' });

    if (resolved) {
      await pool.query('UPDATE orders SET has_blocker = 0, blocker_note = NULL WHERE id = ?', [req.params.id]);
      await pool.query(
        'INSERT INTO order_stage_history (order_id, stage_number, stage_name, updated_by, notes, is_blocker) VALUES (?, ?, ?, ?, ?, 0)',
        [req.params.id, existing[0].current_stage, existing[0].current_stage_name, req.user.id, 'Blocker resolved by workshop']
      );
    } else {
      if (!blocker_note || !blocker_note.trim()) {
        return res.status(400).json({ success: false, message: 'Please describe the workshop issue/blocker' });
      }
      await pool.query('UPDATE orders SET has_blocker = 1, blocker_note = ? WHERE id = ?', [blocker_note.trim(), req.params.id]);
      await pool.query(
        'INSERT INTO order_stage_history (order_id, stage_number, stage_name, updated_by, notes, is_blocker) VALUES (?, ?, ?, ?, ?, 1)',
        [req.params.id, existing[0].current_stage, existing[0].current_stage_name, req.user.id, `HOLD / BLOCKER: ${blocker_note.trim()}`]
      );
    }

    const [rows] = await pool.query(`SELECT ${RESTRICTED_JOB_COLUMNS} FROM orders o WHERE o.id = ?`, [req.params.id]);
    const detailed = await enrichRestrictedJob(rows[0]);
    res.json({ success: true, job: detailed });
  } catch (err) {
    console.error('Blocker report error:', err);
    res.status(500).json({ success: false, message: 'Failed to report blocker' });
  }
});

// Upload Workshop Progress Photo
router.post(
  '/jobs/:id/photos',
  authenticateToken,
  requireRoles('production', 'admin'),
  progressUpload.single('photo'),
  async (req, res) => {
    try {
      if (!req.file) {
        return res.status(400).json({ success: false, message: 'Photo file is required' });
      }

      const [existing] = await pool.query('SELECT current_stage, current_stage_name FROM orders WHERE id = ?', [req.params.id]);
      if (!existing.length) return res.status(404).json({ success: false, message: 'Job not found' });

      const photoUrl = `/uploads/progress/${req.file.filename}`;
      const stageNumber = Number(req.body.stage_number) || existing[0].current_stage;
      const stageName = getStageName(stageNumber);
      const caption = req.body.caption || `Progress photo at ${stageName}`;

      const [result] = await pool.query(
        'INSERT INTO order_progress_photos (order_id, stage_number, stage_name, photo_url, caption, uploaded_by) VALUES (?, ?, ?, ?, ?, ?)',
        [req.params.id, stageNumber, stageName, photoUrl, caption, req.user.id]
      );

      const [photoRows] = await pool.query('SELECT * FROM order_progress_photos WHERE id = ?', [result.insertId]);
      res.status(201).json({ success: true, photo: photoRows[0] });
    } catch (err) {
      console.error('Progress photo upload error:', err);
      res.status(500).json({ success: false, message: 'Failed to upload progress photo' });
    }
  }
);

module.exports = router;
