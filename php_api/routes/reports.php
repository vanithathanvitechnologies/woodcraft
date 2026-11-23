<?php

function handleReportsRoutes(string $method, array $segments): void {
    requireRoles(['admin', 'owner']);
    $pdo = getDb();

    // GET /api/reports/summary
    if ($method === 'GET' && ($segments[0] ?? '') === 'summary') {
        $kpis = $pdo->query('
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
        ')->fetch();

        $counts = $pdo->query('
            SELECT
              (SELECT COUNT(*) FROM customers) AS total_customers,
              (SELECT COUNT(*) FROM users WHERE is_active = 1) AS active_staff,
              (SELECT COUNT(*) FROM design_catalog WHERE is_archived = 0) AS active_designs
        ')->fetch();

        $byStage = $pdo->query('
            SELECT current_stage AS stage_number, current_stage_name AS stage_name, COUNT(*) AS count
            FROM orders
            GROUP BY current_stage, current_stage_name
            ORDER BY current_stage ASC
        ')->fetchAll();

        $byWood = $pdo->query('
            SELECT wood_species, COUNT(*) AS order_count, COALESCE(SUM(total_cost), 0) AS revenue
            FROM orders
            GROUP BY wood_species
            ORDER BY revenue DESC
        ')->fetchAll();

        $byCategory = $pdo->query('
            SELECT woodwork_category, COUNT(*) AS order_count, COALESCE(SUM(total_cost), 0) AS revenue
            FROM orders
            GROUP BY woodwork_category
            ORDER BY order_count DESC
        ')->fetchAll();

        $bySales = $pdo->query('
            SELECT COALESCE(u.name, "Unassigned") AS sales_name,
                   COUNT(o.id) AS order_count,
                   COALESCE(SUM(o.total_cost), 0) AS revenue
            FROM orders o
            LEFT JOIN users u ON u.id = o.sales_user_id
            GROUP BY o.sales_user_id, u.name
            ORDER BY revenue DESC
        ')->fetchAll();

        jsonResponse([
            'success' => true,
            'kpis' => array_merge($kpis ?: [], $counts ?: []),
            'by_stage' => $byStage,
            'by_wood' => $byWood,
            'by_category' => $byCategory,
            'by_salesperson' => $bySales,
        ]);
    }

    // GET /api/reports/export/csv
    if ($method === 'GET' && ($segments[0] ?? '') === 'export' && ($segments[1] ?? '') === 'csv') {
        $rows = $pdo->query('
            SELECT o.job_id, o.created_at, c.name AS customer_name, c.mobile AS customer_mobile,
                   o.woodwork_category, o.wood_species, o.leaf_type,
                   CONCAT(o.width_inches, "x", o.height_inches) AS dimensions_in,
                   o.quantity, o.total_cost, o.advance_amount, o.balance_amount,
                   o.expected_delivery_date, o.current_stage_name, o.priority
            FROM orders o
            JOIN customers c ON c.id = o.customer_id
            ORDER BY o.created_at DESC
        ')->fetchAll();

        header('Content-Type: text/csv; charset=utf-8');
        header('Content-Disposition: attachment; filename="wooden-door-orders-report.csv"');
        $out = fopen('php://output', 'w');
        fputcsv($out, [
            'Job ID', 'Order Date', 'Customer Name', 'Mobile', 'Category', 'Wood Species',
            'Leaf Type', 'Dimensions (in)', 'Qty', 'Total Cost', 'Advance', 'Balance',
            'Delivery Date', 'Production Stage', 'Priority',
        ]);
        foreach ($rows as $r) {
            fputcsv($out, array_values($r));
        }
        fclose($out);
        exit;
    }

    jsonResponse(['success' => false, 'message' => 'Reports endpoint not found'], 404);
}
