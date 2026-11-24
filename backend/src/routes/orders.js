const express = require('express');
const pool = require('../config/db');
const { authenticateToken, requireRoles } = require('../middleware/auth');
const { getStageName, WOOD_SPECIES } = require('../config/constants');

const router = express.Router();

function parseJsonSafe(val, fallback = []) {
  if (!val) return fallback;
  if (typeof val === 'object') return val;
  try {
    return JSON.parse(val);
  } catch {
    return fallback;
  }
}

async function generateJobId() {
  const year = new Date().getFullYear();
  const [rows] = await pool.query(
    "SELECT COALESCE(MAX(CAST(SUBSTRING_INDEX(job_id, '-', -1) AS UNSIGNED)), 0) AS max_num FROM orders WHERE job_id LIKE ?",
    [`SUW-${year}-%`]
  );
  const nextNum = (rows[0].max_num || 0) + 1;
  return `SUW-${year}-${String(nextNum).padStart(4, '0')}`;
}

async function attachOrderRelations(order) {
  const refIds = parseJsonSafe(order.reference_design_ids, []);
  let reference_designs = [];
  if (refIds.length > 0) {
    const placeholders = refIds.map(() => '?').join(',');
    const [refs] = await pool.query(
      `SELECT id, title, category, wood_species, image_url FROM design_catalog WHERE id IN (${placeholders})`,
      refIds
    );
    reference_designs = refs;
  }

  const [history] = await pool.query(
    `SELECT h.*, u.name AS updated_by_name, u.role AS updated_by_role
     FROM order_stage_history h
     LEFT JOIN users u ON u.id = h.updated_by
     WHERE h.order_id = ?
     ORDER BY h.created_at ASC`,
    [order.id]
  );

  const [photos] = await pool.query(
    `SELECT p.*, u.name AS uploaded_by_name
     FROM order_progress_photos p
     LEFT JOIN users u ON u.id = p.uploaded_by
     WHERE p.order_id = ?
     ORDER BY p.created_at DESC`,
    [order.id]
  );

  return {
    ...order,
    reference_design_ids: refIds,
    reference_elements: parseJsonSafe(order.reference_elements, []),
    reference_designs,
    stage_history: history,
    progress_photos: photos,
  };
}

// Billing & Cost Estimation helper
router.post('/estimate', authenticateToken, requireRoles('admin', 'owner', 'sales'), (req, res) => {
  const {
    base_price = 28000,
    width_inches = 36,
    height_inches = 84,
    wood_species = 'Burma Teak',
    leaf_type = 'Single Leaf',
    hardware_cost = 4500,
    polish_cost = 3500,
    carving_cost = 4000,
    quantity = 1,
    discount = 0,
    advance_amount = 0,
  } = req.body;

  const areaSqFt = (Number(width_inches) * Number(height_inches)) / 144;
  const areaFactor = Math.max(0.8, areaSqFt / 21);
  const speciesObj = WOOD_SPECIES.find((w) => w.name === wood_species);
  const woodMultiplier = speciesObj ? speciesObj.multiplier : 1.2;
  const leafMultiplier = leaf_type === 'Double Leaf' ? 1.45 : 1.0;

  const woodworkUnit = Math.round(Number(base_price) * areaFactor * woodMultiplier * leafMultiplier);
  const unitTotal = woodworkUnit + Number(hardware_cost) + Number(polish_cost) + Number(carving_cost);
  const subtotal = unitTotal * Math.max(1, Number(quantity) || 1);
  const totalCost = Math.max(0, subtotal - Number(discount || 0));
  const balanceAmount = Math.max(0, totalCost - Number(advance_amount || 0));

  res.json({
    success: true,
    estimate: {
      area_sqft: Number(areaSqFt.toFixed(2)),
      wood_multiplier: woodMultiplier,
      woodwork_unit_cost: woodworkUnit,
      unit_total: unitTotal,
      subtotal,
      discount: Number(discount || 0),
      total_cost: totalCost,
      advance_amount: Number(advance_amount || 0),
      balance_amount: balanceAmount,
    },
  });
});

// List all orders with customer & billing info (Owner, Sales, Admin ONLY — Production forbidden)
router.get('/', authenticateToken, requireRoles('admin', 'owner', 'sales'), async (req, res) => {
  try {
    const { search, stage, date_from, date_to, delivery_date, delayed_only, blocker_only } = req.query;
    let sql = `
      SELECT o.*,
             c.name AS customer_name,
             c.mobile AS customer_mobile,
             c.delivery_address AS customer_address,
             u.name AS sales_user_name
      FROM orders o
      JOIN customers c ON c.id = o.customer_id
      LEFT JOIN users u ON u.id = o.sales_user_id
      WHERE 1=1
    `;
    const params = [];

    if (search) {
      sql += ' AND (o.job_id LIKE ? OR c.name LIKE ? OR c.mobile LIKE ? OR o.woodwork_category LIKE ? OR o.wood_species LIKE ?)';
      const like = `%${search}%`;
      params.push(like, like, like, like, like);
    }
    if (stage && stage !== 'all') {
      sql += ' AND o.current_stage = ?';
      params.push(Number(stage));
    }
    if (date_from) {
      sql += ' AND DATE(o.created_at) >= ?';
      params.push(date_from);
    }
    if (date_to) {
      sql += ' AND DATE(o.created_at) <= ?';
      params.push(date_to);
    }
    if (delivery_date) {
      sql += ' AND o.expected_delivery_date = ?';
      params.push(delivery_date);
    }
    if (delayed_only === 'true') {
      sql += ' AND o.expected_delivery_date < CURDATE() AND o.current_stage < 8';
    }
    if (blocker_only === 'true') {
      sql += ' AND o.has_blocker = 1';
    }

    sql += ' ORDER BY o.created_at DESC';
    const [rows] = await pool.query(sql, params);

    const formatted = rows.map((r) => ({
      ...r,
      reference_design_ids: parseJsonSafe(r.reference_design_ids, []),
      reference_elements: parseJsonSafe(r.reference_elements, []),
      is_delayed: r.current_stage < 8 && new Date(r.expected_delivery_date) < new Date(new Date().toDateString()),
    }));

    res.json({ success: true, orders: formatted });
  } catch (err) {
    console.error('List orders error:', err);
    res.status(500).json({ success: false, message: 'Failed to fetch orders' });
  }
});

// Get single order with full history, reference designs, and progress photos
router.get('/:id', authenticateToken, requireRoles('admin', 'owner', 'sales'), async (req, res) => {
  try {
    const [rows] = await pool.query(
      `SELECT o.*,
              c.name AS customer_name,
              c.mobile AS customer_mobile,
              c.delivery_address AS customer_address,
              u.name AS sales_user_name
       FROM orders o
       JOIN customers c ON c.id = o.customer_id
       LEFT JOIN users u ON u.id = o.sales_user_id
       WHERE o.id = ? LIMIT 1`,
      [req.params.id]
    );

    if (!rows.length) {
      return res.status(404).json({ success: false, message: 'Order not found' });
    }

    const detailed = await attachOrderRelations(rows[0]);
    res.json({ success: true, order: detailed });
  } catch (err) {
    console.error('Get order error:', err);
    res.status(500).json({ success: false, message: 'Failed to fetch order details' });
  }
});

// Create confirmed order (Auto-creates/updates customer by mobile number for Customer App login)
router.post('/', authenticateToken, requireRoles('admin', 'owner', 'sales'), async (req, res) => {
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();

    const {
      customer_id,
      customer_name,
      customer_mobile,
      delivery_address = '',
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
      workshop_notes = '',
      reference_design_ids = [],
      reference_elements = [],
      ai_output_image_url = '',
      total_cost = 0,
      advance_amount = 0,
      expected_delivery_date,
      priority = 'Normal',
      is_dispatched = true,
    } = req.body;

    let finalCustomerId = customer_id;

    if (!finalCustomerId) {
      const cleanMobile = String(customer_mobile || '').replace(/\D/g, '');
      if (!customer_name || cleanMobile.length < 10) {
        await conn.rollback();
        return res.status(400).json({
          success: false,
          message: 'Customer name and valid 10-digit mobile number are required',
        });
      }

      const [existingCust] = await conn.query('SELECT id FROM customers WHERE mobile = ? LIMIT 1', [cleanMobile]);
      if (existingCust.length > 0) {
        finalCustomerId = existingCust[0].id;
        await conn.query('UPDATE customers SET name = ?, delivery_address = ? WHERE id = ?', [
          customer_name.trim(),
          delivery_address,
          finalCustomerId,
        ]);
      } else {
        const [custRes] = await conn.query(
          'INSERT INTO customers (name, mobile, delivery_address, created_by) VALUES (?, ?, ?, ?)',
          [customer_name.trim(), cleanMobile, delivery_address, req.user.id]
        );
        finalCustomerId = custRes.insertId;
      }
    }

    const jobId = await generateJobId();
    const numTotal = Number(total_cost) || 0;
    const numAdvance = Number(advance_amount) || 0;
    const balance = Math.max(0, numTotal - numAdvance);
    const defaultDelivery = new Date(Date.now() + 14 * 86400000).toISOString().slice(0, 10);

    const [orderRes] = await conn.query(
      `INSERT INTO orders (
        job_id, customer_id, sales_user_id,
        woodwork_category, width_inches, height_inches, frame_section, door_thickness,
        leaf_type, wood_species, carving_pattern, polish_shade, hardware, quantity,
        custom_notes, workshop_notes, reference_design_ids, reference_elements, ai_output_image_url,
        total_cost, advance_amount, balance_amount,
        expected_delivery_date, priority, current_stage, current_stage_name, is_dispatched
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?)`,
      [
        jobId,
        finalCustomerId,
        req.user.id,
        woodwork_category,
        Number(width_inches) || 36,
        Number(height_inches) || 84,
        frame_section,
        door_thickness,
        leaf_type,
        wood_species,
        carving_pattern,
        polish_shade,
        hardware,
        Math.max(1, Number(quantity) || 1),
        custom_notes,
        workshop_notes || custom_notes,
        JSON.stringify(reference_design_ids),
        JSON.stringify(reference_elements),
        ai_output_image_url,
        numTotal,
        numAdvance,
        balance,
        expected_delivery_date || defaultDelivery,
        priority,
        getStageName(1),
        is_dispatched ? 1 : 0,
      ]
    );

    await conn.query(
      'INSERT INTO order_stage_history (order_id, stage_number, stage_name, updated_by, notes) VALUES (?, 1, ?, ?, ?)',
      [
        orderRes.insertId,
        getStageName(1),
        req.user.id,
        is_dispatched ? 'Order confirmed and dispatched to Production Workshop' : 'Order confirmed and saved',
      ]
    );

    await conn.commit();

    const [createdRows] = await pool.query(
      `SELECT o.*, c.name AS customer_name, c.mobile AS customer_mobile, c.delivery_address AS customer_address
       FROM orders o JOIN customers c ON c.id = o.customer_id WHERE o.id = ?`,
      [orderRes.insertId]
    );
    const detailed = await attachOrderRelations(createdRows[0]);
    res.status(201).json({ success: true, order: detailed });
  } catch (err) {
    await conn.rollback();
    console.error('Create order error:', err);
    res.status(500).json({ success: false, message: 'Failed to create order' });
  } finally {
    conn.release();
  }
});

// One-Tap Send to Production
router.post('/:id/dispatch', authenticateToken, requireRoles('admin', 'owner', 'sales'), async (req, res) => {
  try {
    await pool.query('UPDATE orders SET is_dispatched = 1 WHERE id = ?', [req.params.id]);
    await pool.query(
      'INSERT INTO order_stage_history (order_id, stage_number, stage_name, updated_by, notes) VALUES (?, 1, ?, ?, ?)',
      [req.params.id, getStageName(1), req.user.id, 'Dispatched to Production Team Workshop']
    );
    res.json({ success: true, message: 'Job dispatched to Production Team' });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Failed to dispatch job' });
  }
});

// Update order billing / delivery / notes
router.put('/:id', authenticateToken, requireRoles('admin', 'owner', 'sales'), async (req, res) => {
  try {
    const { total_cost, advance_amount, expected_delivery_date, priority, workshop_notes, custom_notes } = req.body;
    const fields = [];
    const params = [];

    if (total_cost !== undefined || advance_amount !== undefined) {
      const [existing] = await pool.query('SELECT total_cost, advance_amount FROM orders WHERE id = ?', [req.params.id]);
      if (!existing.length) return res.status(404).json({ success: false, message: 'Order not found' });
      const newTotal = total_cost !== undefined ? Number(total_cost) : Number(existing[0].total_cost);
      const newAdv = advance_amount !== undefined ? Number(advance_amount) : Number(existing[0].advance_amount);
      fields.push('total_cost = ?, advance_amount = ?, balance_amount = ?');
      params.push(newTotal, newAdv, Math.max(0, newTotal - newAdv));
    }
    if (expected_delivery_date !== undefined) {
      fields.push('expected_delivery_date = ?');
      params.push(expected_delivery_date);
    }
    if (priority !== undefined) {
      fields.push('priority = ?');
      params.push(priority);
    }
    if (workshop_notes !== undefined) {
      fields.push('workshop_notes = ?');
      params.push(workshop_notes);
    }
    if (custom_notes !== undefined) {
      fields.push('custom_notes = ?');
      params.push(custom_notes);
    }

    if (!fields.length) return res.status(400).json({ success: false, message: 'No fields to update' });
    params.push(req.params.id);
    await pool.query(`UPDATE orders SET ${fields.join(', ')} WHERE id = ?`, params);
    const [rows] = await pool.query('SELECT * FROM orders WHERE id = ?', [req.params.id]);
    res.json({ success: true, order: rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Failed to update order' });
  }
});

module.exports = router;
