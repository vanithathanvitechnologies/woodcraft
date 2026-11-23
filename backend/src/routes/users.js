const express = require('express');
const bcrypt = require('bcryptjs');
const pool = require('../config/db');
const { authenticateToken, requireRoles } = require('../middleware/auth');

const router = express.Router();

// List all staff/admin users (Admin & Owner)
router.get('/', authenticateToken, requireRoles('admin', 'owner'), async (req, res) => {
  try {
    const { role, search } = req.query;
    let sql = 'SELECT id, name, email, phone, role, is_active, created_at FROM users WHERE 1=1';
    const params = [];

    if (role && role !== 'all') {
      sql += ' AND role = ?';
      params.push(role);
    }
    if (search) {
      sql += ' AND (name LIKE ? OR email LIKE ? OR phone LIKE ?)';
      const like = `%${search}%`;
      params.push(like, like, like);
    }
    sql += ' ORDER BY created_at DESC';

    const [rows] = await pool.query(sql, params);
    res.json({ success: true, users: rows });
  } catch (err) {
    console.error('List users error:', err);
    res.status(500).json({ success: false, message: 'Failed to fetch users' });
  }
});

// Create staff/admin user (Admin & Owner)
router.post('/', authenticateToken, requireRoles('admin', 'owner'), async (req, res) => {
  try {
    const { name, email, phone, password, role } = req.body;
    const allowedRoles = ['admin', 'owner', 'sales', 'production'];

    if (!name || !email || !password || !allowedRoles.includes(role)) {
      return res.status(400).json({
        success: false,
        message: 'Name, email, password, and valid role (admin, owner, sales, production) are required',
      });
    }

    const normalizedEmail = email.trim().toLowerCase();
    const [existing] = await pool.query('SELECT id FROM users WHERE email = ?', [normalizedEmail]);
    if (existing.length > 0) {
      return res.status(409).json({ success: false, message: 'A user with this email already exists' });
    }

    const passwordHash = await bcrypt.hash(password, 10);
    const [result] = await pool.query(
      'INSERT INTO users (name, email, phone, password_hash, role, is_active) VALUES (?, ?, ?, ?, ?, 1)',
      [name.trim(), normalizedEmail, phone || null, passwordHash, role]
    );

    const [created] = await pool.query(
      'SELECT id, name, email, phone, role, is_active, created_at FROM users WHERE id = ?',
      [result.insertId]
    );

    res.status(201).json({ success: true, user: created[0] });
  } catch (err) {
    console.error('Create user error:', err);
    res.status(500).json({ success: false, message: 'Failed to create user' });
  }
});

// Update staff user
router.put('/:id', authenticateToken, requireRoles('admin', 'owner'), async (req, res) => {
  try {
    const { id } = req.params;
    const { name, phone, role, is_active, password } = req.body;

    const fields = [];
    const params = [];

    if (name !== undefined) {
      fields.push('name = ?');
      params.push(name.trim());
    }
    if (phone !== undefined) {
      fields.push('phone = ?');
      params.push(phone);
    }
    if (role !== undefined && ['admin', 'owner', 'sales', 'production'].includes(role)) {
      fields.push('role = ?');
      params.push(role);
    }
    if (is_active !== undefined) {
      fields.push('is_active = ?');
      params.push(is_active ? 1 : 0);
    }
    if (password && password.trim().length >= 4) {
      const hash = await bcrypt.hash(password.trim(), 10);
      fields.push('password_hash = ?');
      params.push(hash);
    }

    if (!fields.length) {
      return res.status(400).json({ success: false, message: 'No fields to update' });
    }

    params.push(id);
    await pool.query(`UPDATE users SET ${fields.join(', ')} WHERE id = ?`, params);

    const [updated] = await pool.query(
      'SELECT id, name, email, phone, role, is_active, created_at FROM users WHERE id = ?',
      [id]
    );
    res.json({ success: true, user: updated[0] });
  } catch (err) {
    console.error('Update user error:', err);
    res.status(500).json({ success: false, message: 'Failed to update user' });
  }
});

// Delete user
router.delete('/:id', authenticateToken, requireRoles('admin', 'owner'), async (req, res) => {
  try {
    const { id } = req.params;
    if (Number(id) === Number(req.user.id)) {
      return res.status(400).json({ success: false, message: 'Cannot delete your own account' });
    }
    await pool.query('DELETE FROM users WHERE id = ?', [id]);
    res.json({ success: true, message: 'User deleted' });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Failed to delete user' });
  }
});

module.exports = router;
