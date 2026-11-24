<?php

function attachOrderRelationsPhp(PDO $pdo, array $order): array {
    $refIds = parseJsonField($order['reference_design_ids'] ?? null, []);
    $refDesigns = [];
    if (count($refIds) > 0) {
        $placeholders = implode(',', array_fill(0, count($refIds), '?'));
        $stmt = $pdo->prepare("SELECT id, title, category, wood_species, image_url FROM design_catalog WHERE id IN ($placeholders)");
        $stmt->execute($refIds);
        $refDesigns = $stmt->fetchAll();
    }

    $hStmt = $pdo->prepare(
        'SELECT h.*, u.name AS updated_by_name, u.role AS updated_by_role
         FROM order_stage_history h
         LEFT JOIN users u ON u.id = h.updated_by
         WHERE h.order_id = ?
         ORDER BY h.created_at ASC'
    );
    $hStmt->execute([$order['id']]);

    $pStmt = $pdo->prepare(
        'SELECT p.*, u.name AS uploaded_by_name
         FROM order_progress_photos p
         LEFT JOIN users u ON u.id = p.uploaded_by
         WHERE p.order_id = ?
         ORDER BY p.created_at DESC'
    );
    $pStmt->execute([$order['id']]);

    $order['reference_design_ids'] = $refIds;
    $order['reference_elements'] = parseJsonField($order['reference_elements'] ?? null, []);
    $order['reference_designs'] = $refDesigns;
    $order['stage_history'] = $hStmt->fetchAll();
    $order['progress_photos'] = $pStmt->fetchAll();
    return $order;
}

function handleOrdersRoutes(string $method, array $segments): void {
    $authUser = requireRoles(['admin', 'owner', 'sales']);
    $pdo = getDb();

    // POST /api/orders/estimate
    if ($method === 'POST' && ($segments[0] ?? '') === 'estimate') {
        $body = getJsonBody();
        $base = (float)($body['base_price'] ?? 28000);
        $w = (float)($body['width_inches'] ?? 36);
        $h = (float)($body['height_inches'] ?? 84);
        $wood = (string)($body['wood_species'] ?? 'Burma Teak');
        $leaf = (string)($body['leaf_type'] ?? 'Single Leaf');
        $hardware = (float)($body['hardware_cost'] ?? 4500);
        $polish = (float)($body['polish_cost'] ?? 3500);
        $carving = (float)($body['carving_cost'] ?? 4000);
        $qty = max(1, (int)($body['quantity'] ?? 1));
        $discount = (float)($body['discount'] ?? 0);
        $advance = (float)($body['advance_amount'] ?? 0);

        $areaSqFt = ($w * $h) / 144.0;
        $areaFactor = max(0.8, $areaSqFt / 21.0);
        $woodMult = getWoodMultiplier($wood);
        $leafMult = ($leaf === 'Double Leaf') ? 1.45 : 1.0;

        $woodworkUnit = (int)round($base * $areaFactor * $woodMult * $leafMult);
        $unitTotal = $woodworkUnit + $hardware + $polish + $carving;
        $subtotal = $unitTotal * $qty;
        $totalCost = max(0, $subtotal - $discount);
        $balance = max(0, $totalCost - $advance);

        jsonResponse([
            'success' => true,
            'estimate' => [
                'area_sqft' => round($areaSqFt, 2),
                'wood_multiplier' => $woodMult,
                'woodwork_unit_cost' => $woodworkUnit,
                'unit_total' => $unitTotal,
                'subtotal' => $subtotal,
                'discount' => $discount,
                'total_cost' => $totalCost,
                'advance_amount' => $advance,
                'balance_amount' => $balance,
            ],
        ]);
    }

    $id = isset($segments[0]) && is_numeric($segments[0]) ? (int)$segments[0] : null;

    // POST /api/orders/:id/dispatch
    if ($method === 'POST' && $id !== null && ($segments[1] ?? '') === 'dispatch') {
        $pdo->prepare('UPDATE orders SET is_dispatched = 1 WHERE id = ?')->execute([$id]);
        $pdo->prepare('INSERT INTO order_stage_history (order_id, stage_number, stage_name, updated_by, notes) VALUES (?, 1, ?, ?, ?)')
            ->execute([$id, getStageName(1), $authUser['id'], 'Dispatched to Production Team Workshop']);
        jsonResponse(['success' => true, 'message' => 'Job dispatched to Production Team']);
    }

    // GET /api/orders
    if ($method === 'GET' && $id === null) {
        $sql = 'SELECT o.*,
                       c.name AS customer_name,
                       c.mobile AS customer_mobile,
                       c.delivery_address AS customer_address,
                       u.name AS sales_user_name
                FROM orders o
                JOIN customers c ON c.id = o.customer_id
                LEFT JOIN users u ON u.id = o.sales_user_id
                WHERE 1=1';
        $params = [];

        if (!empty($_GET['search'])) {
            $sql .= ' AND (o.job_id LIKE ? OR c.name LIKE ? OR c.mobile LIKE ? OR o.woodwork_category LIKE ? OR o.wood_species LIKE ?)';
            $like = '%' . trim($_GET['search']) . '%';
            array_push($params, $like, $like, $like, $like, $like);
        }
        if (!empty($_GET['stage']) && $_GET['stage'] !== 'all') {
            $sql .= ' AND o.current_stage = ?';
            $params[] = (int)$_GET['stage'];
        }
        if (!empty($_GET['date_from'])) {
            $sql .= ' AND DATE(o.created_at) >= ?';
            $params[] = $_GET['date_from'];
        }
        if (!empty($_GET['date_to'])) {
            $sql .= ' AND DATE(o.created_at) <= ?';
            $params[] = $_GET['date_to'];
        }
        if (!empty($_GET['delivery_date'])) {
            $sql .= ' AND o.expected_delivery_date = ?';
            $params[] = $_GET['delivery_date'];
        }
        if (($_GET['delayed_only'] ?? '') === 'true') {
            $sql .= ' AND o.expected_delivery_date < CURDATE() AND o.current_stage < 8';
        }
        if (($_GET['blocker_only'] ?? '') === 'true') {
            $sql .= ' AND o.has_blocker = 1';
        }

        $sql .= ' ORDER BY o.created_at DESC';
        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);
        $rows = $stmt->fetchAll();

        $today = date('Y-m-d');
        foreach ($rows as &$r) {
            $r['reference_design_ids'] = parseJsonField($r['reference_design_ids'] ?? null, []);
            $r['reference_elements'] = parseJsonField($r['reference_elements'] ?? null, []);
            $r['is_delayed'] = ((int)$r['current_stage'] < 8 && $r['expected_delivery_date'] < $today);
        }
        jsonResponse(['success' => true, 'orders' => $rows]);
    }

    // GET /api/orders/:id
    if ($method === 'GET' && $id !== null) {
        $stmt = $pdo->prepare(
            'SELECT o.*,
                    c.name AS customer_name,
                    c.mobile AS customer_mobile,
                    c.delivery_address AS customer_address,
                    u.name AS sales_user_name
             FROM orders o
             JOIN customers c ON c.id = o.customer_id
             LEFT JOIN users u ON u.id = o.sales_user_id
             WHERE o.id = ? LIMIT 1'
        );
        $stmt->execute([$id]);
        $order = $stmt->fetch();
        if (!$order) jsonResponse(['success' => false, 'message' => 'Order not found'], 404);
        jsonResponse(['success' => true, 'order' => attachOrderRelationsPhp($pdo, $order)]);
    }

    // POST /api/orders
    if ($method === 'POST' && $id === null) {
        $body = getJsonBody();
        $pdo->beginTransaction();
        try {
            $customerId = $body['customer_id'] ?? null;
            if (!$customerId) {
                $custName = trim((string)($body['customer_name'] ?? ''));
                $cleanMobile = preg_replace('/\D/', '', (string)($body['customer_mobile'] ?? ''));
                $address = (string)($body['delivery_address'] ?? '');

                if (!$custName || strlen($cleanMobile) < 10) {
                    $pdo->rollBack();
                    jsonResponse(['success' => false, 'message' => 'Customer name and valid 10-digit mobile number are required'], 400);
                }

                $chk = $pdo->prepare('SELECT id FROM customers WHERE mobile = ? LIMIT 1');
                $chk->execute([$cleanMobile]);
                $ex = $chk->fetch();
                if ($ex) {
                    $customerId = (int)$ex['id'];
                    $pdo->prepare('UPDATE customers SET name = ?, delivery_address = ? WHERE id = ?')
                        ->execute([$custName, $address, $customerId]);
                } else {
                    $cIns = $pdo->prepare('INSERT INTO customers (name, mobile, delivery_address, created_by) VALUES (?, ?, ?, ?)');
                    $cIns->execute([$custName, $cleanMobile, $address, $authUser['id']]);
                    $customerId = (int)$pdo->lastInsertId();
                }
            }

            $year = date('Y');
            $cntStmt = $pdo->prepare("SELECT COALESCE(MAX(CAST(SUBSTRING_INDEX(job_id, '-', -1) AS UNSIGNED)), 0) AS max_num FROM orders WHERE job_id LIKE ?");
            $cntStmt->execute(["SUW-$year-%"]);
            $nextNum = ((int)($cntStmt->fetch()['max_num'] ?? 0)) + 1;
            $jobId = sprintf('SUW-%s-%04d', $year, $nextNum);

            $total = (float)($body['total_cost'] ?? 0);
            $advance = (float)($body['advance_amount'] ?? 0);
            $balance = max(0, $total - $advance);
            $delivery = $body['expected_delivery_date'] ?? date('Y-m-d', strtotime('+14 days'));
            $isDispatched = array_key_exists('is_dispatched', $body) ? ($body['is_dispatched'] ? 1 : 0) : 1;

            $ins = $pdo->prepare(
                'INSERT INTO orders (
                  job_id, customer_id, sales_user_id,
                  woodwork_category, width_inches, height_inches, frame_section, door_thickness,
                  leaf_type, wood_species, carving_pattern, polish_shade, hardware, quantity,
                  custom_notes, workshop_notes, reference_design_ids, reference_elements, ai_output_image_url,
                  total_cost, advance_amount, balance_amount,
                  expected_delivery_date, priority, current_stage, current_stage_name, is_dispatched
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?)'
            );
            $ins->execute([
                $jobId,
                $customerId,
                $authUser['id'],
                $body['woodwork_category'] ?? 'Door',
                (float)($body['width_inches'] ?? 36),
                (float)($body['height_inches'] ?? 84),
                $body['frame_section'] ?? '5 x 3 inch',
                $body['door_thickness'] ?? '1.75 inch (45mm)',
                $body['leaf_type'] ?? 'Single Leaf',
                $body['wood_species'] ?? 'Burma Teak',
                $body['carving_pattern'] ?? 'Royal Lotus & Pillar',
                $body['polish_shade'] ?? 'Natural Teak Matte',
                $body['hardware'] ?? 'Antique Brass Handle & Mortise Lock',
                max(1, (int)($body['quantity'] ?? 1)),
                $body['custom_notes'] ?? '',
                $body['workshop_notes'] ?? ($body['custom_notes'] ?? ''),
                json_encode($body['reference_design_ids'] ?? []),
                json_encode($body['reference_elements'] ?? []),
                $body['ai_output_image_url'] ?? '',
                $total,
                $advance,
                $balance,
                $delivery,
                $body['priority'] ?? 'Normal',
                getStageName(1),
                $isDispatched,
            ]);
            $orderId = (int)$pdo->lastInsertId();

            $pdo->prepare('INSERT INTO order_stage_history (order_id, stage_number, stage_name, updated_by, notes) VALUES (?, 1, ?, ?, ?)')
                ->execute([
                    $orderId,
                    getStageName(1),
                    $authUser['id'],
                    $isDispatched ? 'Order confirmed and dispatched to Production Workshop' : 'Order confirmed and saved',
                ]);

            $pdo->commit();

            $get = $pdo->prepare(
                'SELECT o.*, c.name AS customer_name, c.mobile AS customer_mobile, c.delivery_address AS customer_address
                 FROM orders o JOIN customers c ON c.id = o.customer_id WHERE o.id = ?'
            );
            $get->execute([$orderId]);
            jsonResponse(['success' => true, 'order' => attachOrderRelationsPhp($pdo, $get->fetch())], 201);
        } catch (Throwable $e) {
            if ($pdo->inTransaction()) $pdo->rollBack();
            jsonResponse(['success' => false, 'message' => 'Failed to create order: ' . $e->getMessage()], 500);
        }
    }

    // PUT /api/orders/:id
    if ($method === 'PUT' && $id !== null) {
        $body = getJsonBody();
        $fields = [];
        $params = [];

        if (isset($body['total_cost']) || isset($body['advance_amount'])) {
            $ex = $pdo->prepare('SELECT total_cost, advance_amount FROM orders WHERE id = ?');
            $ex->execute([$id]);
            $row = $ex->fetch();
            if (!$row) jsonResponse(['success' => false, 'message' => 'Order not found'], 404);
            $newTotal = isset($body['total_cost']) ? (float)$body['total_cost'] : (float)$row['total_cost'];
            $newAdv = isset($body['advance_amount']) ? (float)$body['advance_amount'] : (float)$row['advance_amount'];
            $fields[] = 'total_cost = ?, advance_amount = ?, balance_amount = ?';
            array_push($params, $newTotal, $newAdv, max(0, $newTotal - $newAdv));
        }
        foreach (['expected_delivery_date', 'priority', 'workshop_notes', 'custom_notes'] as $k) {
            if (array_key_exists($k, $body)) {
                $fields[] = "$k = ?";
                $params[] = $body[$k];
            }
        }
        if (!$fields) jsonResponse(['success' => false, 'message' => 'No fields to update'], 400);
        $params[] = $id;
        $pdo->prepare('UPDATE orders SET ' . implode(', ', $fields) . ' WHERE id = ?')->execute($params);

        $get = $pdo->prepare('SELECT * FROM orders WHERE id = ?');
        $get->execute([$id]);
        jsonResponse(['success' => true, 'order' => $get->fetch()]);
    }

    jsonResponse(['success' => false, 'message' => 'Orders endpoint not found'], 404);
}
