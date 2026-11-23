const express = require('express');
const pool = require('../config/db');
const { authenticateToken, requireCustomer } = require('../middleware/auth');
const { PRODUCTION_STAGES } = require('../config/constants');

const router = express.Router();

// Customer Dashboard: Customer Profile + All Their Orders + Live Stage Tracking
router.get('/dashboard', authenticateToken, requireCustomer, async (req, res) => {
  try {
    const [customers] = await pool.query(
      'SELECT id, name, mobile, delivery_address, created_at FROM customers WHERE id = ? LIMIT 1',
      [req.user.id]
    );
    if (!customers.length) {
      return res.status(404).json({ success: false, message: 'Customer not found' });
    }

    const [orders] = await pool.query(
      `SELECT id, job_id, woodwork_category, width_inches, height_inches, frame_section, door_thickness,
              leaf_type, wood_species, carving_pattern, polish_shade, hardware, quantity, custom_notes,
              ai_output_image_url, total_cost, advance_amount, balance_amount,
              expected_delivery_date, priority, current_stage, current_stage_name, created_at, updated_at
       FROM orders
       WHERE customer_id = ?
       ORDER BY created_at DESC`,
      [req.user.id]
    );

    const enriched = await Promise.all(
      orders.map(async (order) => {
        const [history] = await pool.query(
          `SELECT stage_number, stage_name, notes, created_at
           FROM order_stage_history
           WHERE order_id = ? AND is_blocker = 0
           ORDER BY created_at ASC`,
          [order.id]
        );
        const [photos] = await pool.query(
          `SELECT id, stage_number, stage_name, photo_url, caption, created_at
           FROM order_progress_photos
           WHERE order_id = ?
           ORDER BY created_at DESC`,
          [order.id]
        );
        return {
          ...order,
          stage_history: history,
          progress_photos: photos,
        };
      })
    );

    const summary = {
      total_orders: enriched.length,
      in_progress: enriched.filter((o) => o.current_stage < 8).length,
      completed: enriched.filter((o) => o.current_stage === 8).length,
      total_amount: enriched.reduce((s, o) => s + Number(o.total_cost || 0), 0),
      total_balance: enriched.reduce((s, o) => s + Number(o.balance_amount || 0), 0),
    };

    res.json({
      success: true,
      customer: customers[0],
      summary,
      stages: PRODUCTION_STAGES,
      orders: enriched,
    });
  } catch (err) {
    console.error('Customer dashboard error:', err);
    res.status(500).json({ success: false, message: 'Failed to load customer dashboard' });
  }
});

// Single Order Track Detail for authenticated customer
router.get('/orders/:id', authenticateToken, requireCustomer, async (req, res) => {
  try {
    const [orders] = await pool.query(
      `SELECT id, job_id, woodwork_category, width_inches, height_inches, frame_section, door_thickness,
              leaf_type, wood_species, carving_pattern, polish_shade, hardware, quantity, custom_notes,
              ai_output_image_url, total_cost, advance_amount, balance_amount,
              expected_delivery_date, priority, current_stage, current_stage_name, created_at, updated_at
       FROM orders
       WHERE id = ? AND customer_id = ? LIMIT 1`,
      [req.params.id, req.user.id]
    );
    if (!orders.length) {
      return res.status(404).json({ success: false, message: 'Order not found' });
    }

    const [history] = await pool.query(
      'SELECT stage_number, stage_name, notes, created_at FROM order_stage_history WHERE order_id = ? AND is_blocker = 0 ORDER BY created_at ASC',
      [orders[0].id]
    );
    const [photos] = await pool.query(
      'SELECT id, stage_number, stage_name, photo_url, caption, created_at FROM order_progress_photos WHERE order_id = ? ORDER BY created_at DESC',
      [orders[0].id]
    );

    res.json({
      success: true,
      stages: PRODUCTION_STAGES,
      order: {
        ...orders[0],
        stage_history: history,
        progress_photos: photos,
      },
    });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Failed to load order tracking' });
  }
});

module.exports = router;
