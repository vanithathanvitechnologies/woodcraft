const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('../config/db');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();
const JWT_SECRET = process.env.JWT_SECRET || 'wooden_door_super_secret_jwt_key_2026';
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '7d';

// Single Login Screen for Owner, Sales Team, Production Team, and Admin
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ success: false, message: 'Email and password are required' });
    }

    const [rows] = await pool.query(
      'SELECT id, name, email, phone, password_hash, role, is_active FROM users WHERE email = ? LIMIT 1',
      [email.trim().toLowerCase()]
    );

    if (rows.length === 0) {
      return res.status(401).json({ success: false, message: 'Invalid email or password' });
    }

    const user = rows[0];
    if (!user.is_active) {
      return res.status(403).json({ success: false, message: 'Account is deactivated. Contact Admin.' });
    }

    const valid = await bcrypt.compare(password, user.password_hash);
    if (!valid) {
      return res.status(401).json({ success: false, message: 'Invalid email or password' });
    }

    const token = jwt.sign(
      { id: user.id, name: user.name, email: user.email, role: user.role, type: 'staff' },
      JWT_SECRET,
      { expiresIn: JWT_EXPIRES_IN }
    );

    res.json({
      success: true,
      token,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        phone: user.phone,
        role: user.role,
      },
    });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ success: false, message: 'Server error during login' });
  }
});

// Get current authenticated user
router.get('/me', authenticateToken, async (req, res) => {
  try {
    if (req.user.type === 'customer') {
      const [rows] = await pool.query(
        'SELECT id, name, mobile, delivery_address, created_at FROM customers WHERE id = ?',
        [req.user.id]
      );
      if (!rows.length) return res.status(404).json({ success: false, message: 'Customer not found' });
      return res.json({ success: true, type: 'customer', customer: rows[0] });
    }

    const [rows] = await pool.query(
      'SELECT id, name, email, phone, role, is_active, created_at FROM users WHERE id = ?',
      [req.user.id]
    );
    if (!rows.length) return res.status(404).json({ success: false, message: 'User not found' });
    res.json({ success: true, type: 'staff', user: rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Failed to load profile' });
  }
});

// Customer App: Request OTP with Mobile Number (added by Sales Team)
router.post('/customer/request-otp', async (req, res) => {
  try {
    const rawMobile = String(req.body.mobile || '').replace(/\D/g, '');
    if (rawMobile.length < 10) {
      return res.status(400).json({ success: false, message: 'Please enter a valid 10-digit mobile number' });
    }

    const [customers] = await pool.query(
      'SELECT id, name, mobile, delivery_address FROM customers WHERE REPLACE(mobile, " ", "") LIKE ? LIMIT 1',
      [`%${rawMobile.slice(-10)}`]
    );

    if (customers.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Mobile number not found. Please use the mobile number registered with our Sales Team.',
      });
    }

    const customer = customers[0];
    const otpCode = String(Math.floor(100000 + Math.random() * 900000));
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000); // 5 minutes

    await pool.query(
      'INSERT INTO customer_otps (mobile, otp_code, expires_at) VALUES (?, ?, ?)',
      [customer.mobile, otpCode, expiresAt]
    );

    const autoVerify = (process.env.AUTO_VERIFY_OTP || 'true') === 'true';

    res.json({
      success: true,
      message: 'OTP sent successfully',
      mobile: customer.mobile,
      customer_name: customer.name,
      auto_verify: autoVerify,
      // Returned in auto-verify mode so Customer App auto-fills & verifies seamlessly
      otp_code: autoVerify ? otpCode : undefined,
    });
  } catch (err) {
    console.error('OTP request error:', err);
    res.status(500).json({ success: false, message: 'Failed to generate OTP' });
  }
});

// Customer App: Verify OTP -> returns Customer JWT & profile
router.post('/customer/verify-otp', async (req, res) => {
  try {
    const rawMobile = String(req.body.mobile || '').replace(/\D/g, '');
    const otp = String(req.body.otp || '').trim();

    if (rawMobile.length < 10 || !otp) {
      return res.status(400).json({ success: false, message: 'Mobile number and OTP are required' });
    }

    const [customers] = await pool.query(
      'SELECT id, name, mobile, delivery_address FROM customers WHERE REPLACE(mobile, " ", "") LIKE ? LIMIT 1',
      [`%${rawMobile.slice(-10)}`]
    );
    if (!customers.length) {
      return res.status(404).json({ success: false, message: 'Customer not found' });
    }

    const customer = customers[0];
    const [otpRows] = await pool.query(
      'SELECT id, otp_code, expires_at, verified FROM customer_otps WHERE mobile = ? ORDER BY id DESC LIMIT 1',
      [customer.mobile]
    );

    if (!otpRows.length || otpRows[0].otp_code !== otp) {
      return res.status(401).json({ success: false, message: 'Invalid OTP code' });
    }

    if (new Date(otpRows[0].expires_at) < new Date()) {
      return res.status(401).json({ success: false, message: 'OTP has expired. Please request a new one.' });
    }

    await pool.query('UPDATE customer_otps SET verified = 1 WHERE id = ?', [otpRows[0].id]);

    const token = jwt.sign(
      { id: customer.id, name: customer.name, mobile: customer.mobile, type: 'customer' },
      JWT_SECRET,
      { expiresIn: '30d' }
    );

    res.json({
      success: true,
      token,
      customer,
    });
  } catch (err) {
    console.error('OTP verify error:', err);
    res.status(500).json({ success: false, message: 'Failed to verify OTP' });
  }
});

module.exports = router;
