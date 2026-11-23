const express = require('express');
const pool = require('../config/db');
const { authenticateToken, requireRoles } = require('../middleware/auth');

const router = express.Router();

// Owner & Admin Reports Summary
router.get('/summary', authenticateToken, requireRoles('admin', 'owner'), async (req, res) => {
  try {
    const [[kpis]] = await pool.query(`
      SELECT
        COUNT(*) AS total_orders,
        COALESCE(SUM(total_cost), 0) AS total_revenue,
        COALESCE(SUM(advance_amount), 0) AS total_advance,
        COALESCE(SUM(balance_amount), 0) AS total_balance,
        SUM(CASE WHEN current_stage = 8 THEN 1 ELSE 0 END) AS completed_orders,
        SUM(CASE WHEN current_stage < 8 THEN 1 ELSE 0 END) AS active_orders,
        SUM(CASE WHEN current_stage < 8 AND expected_delivery_date < CURDATE() THEN 1 ELSE 0 END) AS delayed_orders,
        SUM(CASE WHEN has_blocker = 1 THEN 1 ELSE 0 END) AS blocked_orders
      FROM orders
    `);

    const [[counts]] = await pool.query(`
      SELECT
        (SELECT COUNT(*) FROM customers) AS total_customers,
        (SELECT COUNT(*) FROM users WHERE is_active = 1) AS active_staff,
        (SELECT COUNT(*) FROM design_catalog WHERE is_archived = 0) AS active_designs
    `);

    const [byStage] = await pool.query(`
      SELECT current_stage AS stage_number, current_stage_name AS stage_name, COUNT(*) AS count
      FROM orders
      GROUP BY current_stage, current_stage_name
      ORDER BY current_stage ASC
    `);

    const [byWood] = await pool.query(`
      SELECT wood_species, COUNT(*) AS order_count, COALESCE(SUM(total_cost), 0) AS revenue
      FROM orders
      GROUP BY wood_species
      ORDER BY revenue DESC
    `);

    const [byCategory] = await pool.query(`
      SELECT woodwork_category, COUNT(*) AS order_count, COALESCE(SUM(total_cost), 0) AS revenue
      FROM orders
      GROUP BY woodwork_category
      ORDER BY order_count DESC
    `);

    const [bySalesperson] = await pool.query(`
      SELECT COALESCE(u.name, 'Unassigned') AS sales_name,
             COUNT(o.id) AS order_count,
             COALESCE(SUM(o.total_cost), 0) AS revenue
      FROM orders o
      LEFT JOIN users u ON u.id = o.sales_user_id
      GROUP BY o.sales_user_id, u.name
      ORDER BY revenue DESC
    `);

    res.json({
      success: true,
      kpis: { ...kpis, ...counts },
      by_stage: byStage,
      by_wood: byWood,
      by_category: byCategory,
      by_salesperson: bySalesperson,
    });
  } catch (err) {
    console.error('Reports summary error:', err);
    res.status(500).json({ success: false, message: 'Failed to generate reports' });
  }
});

// CSV Export of Orders for Admin Panel / Owner
router.get('/export/csv', authenticateToken, requireRoles('admin', 'owner'), async (req, res) => {
  try {
    const [rows] = await pool.query(`
      SELECT o.job_id, o.created_at, c.name AS customer_name, c.mobile AS customer_mobile,
             o.woodwork_category, o.wood_species, o.leaf_type,
             CONCAT(o.width_inches, 'x', o.height_inches) AS dimensions_in,
             o.quantity, o.total_cost, o.advance_amount, o.balance_amount,
             o.expected_delivery_date, o.current_stage_name, o.priority
      FROM orders o
      JOIN customers c ON c.id = o.customer_id
      ORDER BY o.created_at DESC
    `);

    const headers = [
      'Job ID',
      'Order Date',
      'Customer Name',
      'Mobile',
      'Category',
      'Wood Species',
      'Leaf Type',
      'Dimensions (in)',
      'Qty',
      'Total Cost',
      'Advance',
      'Balance',
      'Delivery Date',
      'Production Stage',
      'Priority',
    ];

    const escapeCsv = (val) => `"${String(val ?? '').replace(/"/g, '""')}"`;
    const csvLines = [
      headers.join(','),
      ...rows.map((r) =>
        [
          r.job_id,
          r.created_at,
          r.customer_name,
          r.customer_mobile,
          r.woodwork_category,
          r.wood_species,
          r.leaf_type,
          r.dimensions_in,
          r.quantity,
          r.total_cost,
          r.advance_amount,
          r.balance_amount,
          r.expected_delivery_date,
          r.current_stage_name,
          r.priority,
        ]
          .map(escapeCsv)
          .join(',')
      ),
    ];

    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', 'attachment; filename="wooden-door-orders-report.csv"');
    res.send(csvLines.join('\n'));
  } catch (err) {
    res.status(500).json({ success: false, message: 'Failed to export CSV' });
  }
});

module.exports = router;
