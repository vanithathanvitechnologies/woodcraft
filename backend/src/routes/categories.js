const express = require('express');
const pool = require('../config/db');
const { authenticateToken, requireRoles } = require('../middleware/auth');
const { WOODWORK_CATEGORIES } = require('../config/constants');

const router = express.Router();

let tableReady = false;

async function ensureWoodenCategoriesTable() {
  if (tableReady) return;
  await pool.query(`
    CREATE TABLE IF NOT EXISTS wooden_categories (
      id INT AUTO_INCREMENT PRIMARY KEY,
      name VARCHAR(100) NOT NULL UNIQUE,
      description VARCHAR(255) NOT NULL DEFAULT '',
      is_active TINYINT(1) NOT NULL DEFAULT 1,
      sort_order INT NOT NULL DEFAULT 0,
      created_by INT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      INDEX idx_wooden_categories_active (is_active),
      INDEX idx_wooden_categories_sort (sort_order)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  `);

  const [[cnt]] = await pool.query('SELECT COUNT(*) AS cnt FROM wooden_categories');
  if (Number(cnt.cnt) === 0) {
    const defaults = [
      ['Door', 'Main entrance doors, pooja doors, carved teak & single/double leaf doors', 1],
      ['Wood Frames', 'Carved teak nilai frames, chowkhats, pillars & window frames', 2],
      ['Hard Wood', 'Seasoned A-grade Burma teak, sal wood & timber sections', 3],
    ];
    for (const [name, desc, order] of defaults) {
      await pool.query(
        'INSERT IGNORE INTO wooden_categories (name, description, is_active, sort_order) VALUES (?, ?, 1, ?)',
        [name, desc, order]
      );
    }

    try {
      const [existing] = await pool.query(
        "SELECT DISTINCT TRIM(category) AS cat FROM design_catalog WHERE category IS NOT NULL AND TRIM(category) <> ''"
      );
      let nextOrder = defaults.length + 1;
      for (const row of existing) {
        const cat = String(row.cat || '').trim();
        if (cat) {
          await pool.query(
            'INSERT IGNORE INTO wooden_categories (name, description, is_active, sort_order) VALUES (?, ?, 1, ?)',
            [cat, '', nextOrder++]
          );
        }
      }
    } catch (_) {
      // ignore if design_catalog not initialized
    }
  }

  tableReady = true;
}

async function getActiveWoodenCategoryNames() {
  try {
    await ensureWoodenCategoriesTable();
    const [rows] = await pool.query(
      'SELECT name FROM wooden_categories WHERE is_active = 1 ORDER BY sort_order ASC, id ASC'
    );
    const names = rows.map((r) => String(r.name || '').trim()).filter(Boolean);
    return names.length ? names : WOODWORK_CATEGORIES;
  } catch (_) {
    return WOODWORK_CATEGORIES;
  }
}

// GET /api/categories
router.get('/', authenticateToken, requireRoles('admin', 'owner', 'sales', 'production'), async (req, res) => {
  try {
    await ensureWoodenCategoriesTable();
    const includeInactive = req.query.include_inactive === 'true';
    let sql = `
      SELECT
        wc.*,
        (SELECT COUNT(*) FROM design_catalog dc WHERE LOWER(TRIM(dc.category)) = LOWER(TRIM(wc.name)) AND dc.is_archived = 0) AS design_count,
        (SELECT COUNT(*) FROM design_catalog dc WHERE LOWER(TRIM(dc.category)) = LOWER(TRIM(wc.name))) AS total_design_count
      FROM wooden_categories wc
      WHERE 1=1
    `;
    if (!includeInactive) {
      sql += ' AND wc.is_active = 1';
    }
    sql += ' ORDER BY wc.sort_order ASC, wc.id ASC';

    const [rows] = await pool.query(sql);
    res.json({ success: true, categories: rows });
  } catch (err) {
    console.error('Categories list error:', err);
    res.status(500).json({ success: false, message: 'Failed to fetch wooden categories' });
  }
});

// POST /api/categories (Admin / Owner only)
router.post('/', authenticateToken, requireRoles('admin', 'owner'), async (req, res) => {
  try {
    await ensureWoodenCategoriesTable();
    const name = String(req.body.name || '').trim();
    const description = String(req.body.description || '').trim();
    const isActive = req.body.is_active === undefined ? 1 : (req.body.is_active ? 1 : 0);

    if (!name) {
      return res.status(400).json({ success: false, message: 'Category name is required' });
    }
    if (name.length > 100) {
      return res.status(400).json({ success: false, message: 'Category name must be 100 characters or fewer' });
    }

    const [dup] = await pool.query(
      'SELECT id FROM wooden_categories WHERE LOWER(TRIM(name)) = LOWER(?) LIMIT 1',
      [name]
    );
    if (dup.length) {
      return res.status(409).json({ success: false, message: 'A wooden category with this name already exists' });
    }

    let sortOrder;
    if (req.body.sort_order !== undefined && req.body.sort_order !== '') {
      sortOrder = Number(req.body.sort_order) || 0;
    } else {
      const [[maxRow]] = await pool.query('SELECT COALESCE(MAX(sort_order), 0) AS m FROM wooden_categories');
      sortOrder = Number(maxRow.m) + 1;
    }

    const [result] = await pool.query(
      'INSERT INTO wooden_categories (name, description, is_active, sort_order, created_by) VALUES (?, ?, ?, ?, ?)',
      [name, description, isActive, sortOrder, req.user.id || null]
    );

    const [rows] = await pool.query(
      `SELECT wc.*,
        (SELECT COUNT(*) FROM design_catalog dc WHERE LOWER(TRIM(dc.category)) = LOWER(TRIM(wc.name)) AND dc.is_archived = 0) AS design_count,
        (SELECT COUNT(*) FROM design_catalog dc WHERE LOWER(TRIM(dc.category)) = LOWER(TRIM(wc.name))) AS total_design_count
       FROM wooden_categories wc WHERE wc.id = ?`,
      [result.insertId]
    );
    res.status(201).json({ success: true, category: rows[0] });
  } catch (err) {
    console.error('Create category error:', err);
    res.status(500).json({ success: false, message: 'Failed to create wooden category' });
  }
});

// PUT /api/categories/:id (Admin / Owner only)
router.put('/:id', authenticateToken, requireRoles('admin', 'owner'), async (req, res) => {
  try {
    await ensureWoodenCategoriesTable();
    const id = Number(req.params.id);
    const [curRows] = await pool.query('SELECT * FROM wooden_categories WHERE id = ?', [id]);
    if (!curRows.length) {
      return res.status(404).json({ success: false, message: 'Wooden category not found' });
    }
    const current = curRows[0];

    const fields = [];
    const params = [];
    let newName = null;

    if (req.body.name !== undefined) {
      const trimmed = String(req.body.name || '').trim();
      if (!trimmed) {
        return res.status(400).json({ success: false, message: 'Category name cannot be empty' });
      }
      if (trimmed.length > 100) {
        return res.status(400).json({ success: false, message: 'Category name must be 100 characters or fewer' });
      }
      const [dup] = await pool.query(
        'SELECT id FROM wooden_categories WHERE LOWER(TRIM(name)) = LOWER(?) AND id <> ? LIMIT 1',
        [trimmed, id]
      );
      if (dup.length) {
        return res.status(409).json({ success: false, message: 'Another wooden category already uses this name' });
      }
      fields.push('name = ?');
      params.push(trimmed);
      newName = trimmed;
    }
    if (req.body.description !== undefined) {
      fields.push('description = ?');
      params.push(String(req.body.description || '').trim());
    }
    if (req.body.sort_order !== undefined) {
      fields.push('sort_order = ?');
      params.push(Number(req.body.sort_order) || 0);
    }
    if (req.body.is_active !== undefined) {
      fields.push('is_active = ?');
      params.push(req.body.is_active ? 1 : 0);
    }

    if (!fields.length) {
      return res.status(400).json({ success: false, message: 'No fields to update' });
    }

    params.push(id);
    await pool.query(`UPDATE wooden_categories SET ${fields.join(', ')} WHERE id = ?`, params);

    if (newName && current.name.toLowerCase() !== newName.toLowerCase()) {
      await pool.query(
        'UPDATE design_catalog SET category = ? WHERE LOWER(TRIM(category)) = LOWER(TRIM(?))',
        [newName, current.name]
      );
      await pool.query(
        'UPDATE orders SET woodwork_category = ? WHERE LOWER(TRIM(woodwork_category)) = LOWER(TRIM(?))',
        [newName, current.name]
      );
    }

    const [rows] = await pool.query(
      `SELECT wc.*,
        (SELECT COUNT(*) FROM design_catalog dc WHERE LOWER(TRIM(dc.category)) = LOWER(TRIM(wc.name)) AND dc.is_archived = 0) AS design_count,
        (SELECT COUNT(*) FROM design_catalog dc WHERE LOWER(TRIM(dc.category)) = LOWER(TRIM(wc.name))) AS total_design_count
       FROM wooden_categories wc WHERE wc.id = ?`,
      [id]
    );
    res.json({ success: true, category: rows[0] });
  } catch (err) {
    console.error('Update category error:', err);
    res.status(500).json({ success: false, message: 'Failed to update wooden category' });
  }
});

// DELETE /api/categories/:id (Admin / Owner only)
router.delete('/:id', authenticateToken, requireRoles('admin', 'owner'), async (req, res) => {
  try {
    await ensureWoodenCategoriesTable();
    const id = Number(req.params.id);
    const [curRows] = await pool.query('SELECT * FROM wooden_categories WHERE id = ?', [id]);
    if (!curRows.length) {
      return res.status(404).json({ success: false, message: 'Wooden category not found' });
    }
    const current = curRows[0];

    const [[cnt]] = await pool.query(
      'SELECT COUNT(*) AS cnt FROM design_catalog WHERE LOWER(TRIM(category)) = LOWER(TRIM(?)) AND is_archived = 0',
      [current.name]
    );
    if (Number(cnt.cnt) > 0) {
      return res.status(400).json({
        success: false,
        message: `Cannot delete "${current.name}" because ${cnt.cnt} active catalog design(s) use it. Move or archive those designs first, or disable this category.`,
      });
    }

    await pool.query('DELETE FROM wooden_categories WHERE id = ?', [id]);
    res.json({ success: true, message: 'Wooden category deleted' });
  } catch (err) {
    console.error('Delete category error:', err);
    res.status(500).json({ success: false, message: 'Failed to delete wooden category' });
  }
});

router.ensureWoodenCategoriesTable = ensureWoodenCategoriesTable;
router.getActiveWoodenCategoryNames = getActiveWoodenCategoryNames;
module.exports = router;
