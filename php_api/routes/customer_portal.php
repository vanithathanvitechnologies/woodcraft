<?php

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
            'SELECT id, job_id, woodwork_category, width_inches, height_inches, frame_section, door_thickness,
                    leaf_type, wood_species, carving_pattern, polish_shade, hardware, quantity, custom_notes,
                    ai_output_image_url, production_place,
                    expected_delivery_date, priority, current_stage, current_stage_name, created_at, updated_at
             FROM orders
             WHERE customer_id = ?
             ORDER BY created_at DESC'
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
            'SELECT id, job_id, woodwork_category, width_inches, height_inches, frame_section, door_thickness,
                    leaf_type, wood_species, carving_pattern, polish_shade, hardware, quantity, custom_notes,
                    ai_output_image_url, production_place,
                    expected_delivery_date, priority, current_stage, current_stage_name, created_at, updated_at
             FROM orders
             WHERE id = ? AND customer_id = ? LIMIT 1'
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

        jsonResponse([
            'success' => true,
            'stages' => PRODUCTION_STAGES,
            'order' => $order,
        ]);
    }

    jsonResponse(['success' => false, 'message' => 'Customer portal endpoint not found'], 404);
}
