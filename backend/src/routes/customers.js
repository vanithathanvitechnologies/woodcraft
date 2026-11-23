const express = require('express');
const pool = require('../config/db');
const { authenticateToken, requireRoles } = require('../middleware/auth');

const router = express.Router();

// List customers with order totals (Owner, Sales, Admin — NEVER Production)
router.get('/', authenticateToken, requireRoles('admin', 'owner', 'sales'), async (req, res) => {
  try {
    const { search } = req.query;
    let sql = `
      SELECT c.*,
             COUNT(o.id) AS order_count,
             COALESCE(SUM(o.total_cost), 0) AS total_spent,
             COALESCE(SUM(o.balance_amount), 0) AS total_balance
      FROM customers c
      LEFT JOIN orders o ON o.customer_id = c.id
      WHERE 1=1
    `;
    const params = [];
    if (search) {
      sql += ' AND (c.name LIKE ? OR c.mobile LIKE ? OR c.delivery_address LIKE ?)';
      const like = `%${search}%`;
      params.push(like, like, like);
    }
    sql += ' GROUP BY c.id ORDER BY c.created_at DESC';

    const [rows] = await pool.query(sql, params);
    res.json({ success: true, customers: rows });
  } catch (err) {
    console.error('List customers error:', err);
    res.status(500).json({ success: false, message: 'Failed to fetch customers' });
  }
});

// Add or update customer by mobile number (used by Sales Team)
router.post('/', authenticateToken, requireRoles('admin', 'owner', 'sales'), async (req, res) => {
  try {
    const { name, mobile, delivery_address = '' } = req.body;
    const cleanMobile = String(mobile || '').replace(/\D/g, '');
    if (!name || cleanMobile.length < 10) {
      return res.status(400).json({ success: false, message: 'Customer name and valid 10-digit mobile number are required' });
    }

    const [existing] = await pool.query('SELECT * FROM customers WHERE mobile = ? LIMIT 1', [cleanMobile]);
    if (existing.length > 0) {
      await pool.query('UPDATE customers SET name = ?, delivery_address = ? WHERE id = ?', [
        name.trim(),
        delivery_address,
        existing[0].id,
      ]);
      const [updated] = await pool.query('SELECT * FROM customers WHERE id = ?', [existing[0].id]);
      return res.json({ success: true, customer: updated[0], existed: true });
    }

    const [result] = await pool.query(
      'INSERT INTO customers (name, mobile, delivery_address, created_by) VALUES (?, ?, ?, ?)',
      [name.trim(), cleanMobile, delivery_address, req.user.id]
    );
    const [created] = await pool.query('SELECT * FROM customers WHERE id = ?', [result.insertId]);
    res.status(201).json({ success: true, customer: created[0], existed: false });
  } catch (err) {
    console.error('Create customer error:', err);
    res.status(500).json({ success: false, message: 'Failed to save customer' });
  }
});

// Update customer
router.put('/:id', authenticateToken, requireRoles('admin', 'owner', 'sales'), async (req, res) => {
  try {
    const { name, mobile, delivery_address } = req.body;
    const cleanMobile = mobile ? String(mobile).replace(/\D/g, '') : undefined;
    const fields = [];
    const params = [];

    if (name !== undefined) {
      fields.push('name = ?');
      params.push(name.trim());
    }
    if (cleanMobile) {
      fields.push('mobile = ?');
      params.push(cleanMobile);
    }
    if (delivery_address !== undefined) {
      fields.push('delivery_address = ?');
      params.push(delivery_address);
    }

    if (!fields.length) return res.status(400).json({ success: false, message: 'Nothing to update' });
    params.push(req.params.id);
    await pool.query(`UPDATE customers SET ${fields.join(', ')} WHERE id = ?`, params);
    const [rows] = await pool.query('SELECT * FROM customers WHERE id = ?', [req.params.id]);
    res.json({ success: true, customer: rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Failed to update customer' });
  }
});

module.exports = router;
