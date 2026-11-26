<?php
require_once __DIR__ . '/../helpers/process_steps.php';

function handleCustomerPortalRoutes(string $method, array $segments): void {
    $customerAuth = requireCustomer();
    $pdo = getDb();

    // GET /api/customer/dashboard
    if ($method === 'GET' && ($segments[0] ?? '') === 'dashboard') {
        $cStmt = $pdo->prepare('SELECT id, name, mobile, delivery_address, created_at FROM customers WHERE id = ? LIMIT 1');
        $cStmt->execute([$customerAuth['id']]);
        $customer = $cStmt->fetch();
        if (!$customer) jsonResponse(['success' => false, 'message' => 'Customer not found'], 404);

        $oStmt = $pdo->prepare(
            'SELECT o.id, o.job_id, o.woodwork_category, o.width_inches, o.height_inches, o.frame_section, o.door_thickness,
                    o.leaf_type, o.wood_species, o.carving_pattern, o.polish_shade, o.hardware, o.quantity, o.custom_notes,
                    o.ai_output_image_url, o.production_place,
                    o.expected_delivery_date, o.priority, o.current_stage, o.current_stage_name, o.created_at, o.updated_at,
                    c.name AS customer_name,
                    pu.name AS assigned_production_user_name,
                    (SELECT COUNT(*) FROM order_process_steps s WHERE s.order_id = o.id AND s.s_no >= 6 AND s.actual_date IS NOT NULL AND TRIM(s.actual_date) != "" AND TRIM(s.actual_date) != "-") AS process_done_count
             FROM orders o
             JOIN customers c ON c.id = o.customer_id
             LEFT JOIN users pu ON pu.id = o.assigned_production_user_id
             WHERE o.customer_id = ?
             ORDER BY o.created_at DESC'
        );
        $oStmt->execute([$customerAuth['id']]);
        $orders = $oStmt->fetchAll();

        $inProgress = 0;
        $completed = 0;

        foreach ($orders as &$o) {
            $hStmt = $pdo->prepare('SELECT stage_number, stage_name, notes, created_at FROM order_stage_history WHERE order_id = ? AND is_blocker = 0 ORDER BY created_at ASC');
            $hStmt->execute([$o['id']]);
            $o['stage_history'] = $hStmt->fetchAll();

            $pStmt = $pdo->prepare('SELECT id, stage_number, stage_name, photo_url, caption, created_at FROM order_progress_photos WHERE order_id = ? ORDER BY created_at DESC');
            $pStmt->execute([$o['id']]);
            $o['progress_photos'] = $pStmt->fetchAll();

            if ((int)$o['current_stage'] === 8) $completed++; else $inProgress++;
        }

        jsonResponse([
            'success' => true,
            'customer' => $customer,
            'summary' => [
                'total_orders' => count($orders),
                'in_progress' => $inProgress,
                'completed' => $completed,
            ],
            'stages' => PRODUCTION_STAGES,
            'orders' => $orders,
        ]);
    }

    // GET /api/customer/orders/:id
    if ($method === 'GET' && ($segments[0] ?? '') === 'orders' && isset($segments[1]) && is_numeric($segments[1])) {
        $orderId = (int)$segments[1];
        $oStmt = $pdo->prepare(
            'SELECT o.id, o.job_id, o.woodwork_category, o.width_inches, o.height_inches, o.frame_section, o.door_thickness,
                    o.leaf_type, o.wood_species, o.carving_pattern, o.polish_shade, o.hardware, o.quantity, o.custom_notes,
                    o.ai_output_image_url, o.production_place,
                    o.expected_delivery_date, o.priority, o.current_stage, o.current_stage_name, o.created_at, o.updated_at,
                    c.name AS customer_name,
                    pu.name AS assigned_production_user_name
             FROM orders o
             JOIN customers c ON c.id = o.customer_id
             LEFT JOIN users pu ON pu.id = o.assigned_production_user_id
             WHERE o.id = ? AND o.customer_id = ? LIMIT 1'
        );
        $oStmt->execute([$orderId, $customerAuth['id']]);
        $order = $oStmt->fetch();
        if (!$order) jsonResponse(['success' => false, 'message' => 'Order not found'], 404);

        $hStmt = $pdo->prepare('SELECT stage_number, stage_name, notes, created_at FROM order_stage_history WHERE order_id = ? AND is_blocker = 0 ORDER BY created_at ASC');
        $hStmt->execute([$orderId]);
        $order['stage_history'] = $hStmt->fetchAll();

        $pStmt = $pdo->prepare('SELECT id, stage_number, stage_name, photo_url, caption, created_at FROM order_progress_photos WHERE order_id = ? ORDER BY created_at DESC');
        $pStmt->execute([$orderId]);
        $order['progress_photos'] = $pStmt->fetchAll();

        $order['process_steps'] = getOrderProcessStepsPhp($pdo, $orderId, false, $order);
        $order['process_summary'] = summarizeProcessProgressPhp($order['process_steps']);

        jsonResponse([
            'success' => true,
            'stages' => PRODUCTION_STAGES,
            'order' => $order,
        ]);
    }

    jsonResponse(['success' => false, 'message' => 'Customer portal endpoint not found'], 404);
}
