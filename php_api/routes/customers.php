<?php

function handleCustomersRoutes(string $method, array $segments): void {
    $authUser = requireRoles(['admin', 'owner', 'sales']);
    $pdo = getDb();
    $id = isset($segments[0]) && is_numeric($segments[0]) ? (int)$segments[0] : null;

    if ($method === 'GET' && $id === null) {
        $search = trim((string)($_GET['search'] ?? ''));
        $sql = 'SELECT c.*,
                       COUNT(o.id) AS order_count,
                       COALESCE(SUM(o.total_cost), 0) AS total_spent,
                       COALESCE(SUM(o.balance_amount), 0) AS total_balance
                FROM customers c
                LEFT JOIN orders o ON o.customer_id = c.id
                WHERE 1=1';
        $params = [];
        if ($search !== '') {
            $sql .= ' AND (c.name LIKE ? OR c.mobile LIKE ? OR c.delivery_address LIKE ?)';
            $like = "%$search%";
            array_push($params, $like, $like, $like);
        }
        $sql .= ' GROUP BY c.id ORDER BY c.created_at DESC';
        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);
        jsonResponse(['success' => true, 'customers' => $stmt->fetchAll()]);
    }

    if ($method === 'POST' && $id === null) {
        $body = getJsonBody();
        $name = trim((string)($body['name'] ?? ''));
        $cleanMobile = preg_replace('/\D/', '', (string)($body['mobile'] ?? ''));
        $address = (string)($body['delivery_address'] ?? '');

        if (!$name || strlen($cleanMobile) < 10) {
            jsonResponse(['success' => false, 'message' => 'Customer name and valid 10-digit mobile number are required'], 400);
        }

        $chk = $pdo->prepare('SELECT * FROM customers WHERE mobile = ? LIMIT 1');
        $chk->execute([$cleanMobile]);
        $existing = $chk->fetch();
        if ($existing) {
            $pdo->prepare('UPDATE customers SET name = ?, delivery_address = ? WHERE id = ?')
                ->execute([$name, $address, $existing['id']]);
            $get = $pdo->prepare('SELECT * FROM customers WHERE id = ?');
            $get->execute([$existing['id']]);
            jsonResponse(['success' => true, 'customer' => $get->fetch(), 'existed' => true]);
        }

        $ins = $pdo->prepare('INSERT INTO customers (name, mobile, delivery_address, created_by) VALUES (?, ?, ?, ?)');
        $ins->execute([$name, $cleanMobile, $address, $authUser['id']]);
        $get = $pdo->prepare('SELECT * FROM customers WHERE id = ?');
        $get->execute([(int)$pdo->lastInsertId()]);
        jsonResponse(['success' => true, 'customer' => $get->fetch(), 'existed' => false], 201);
    }

    if ($method === 'PUT' && $id !== null) {
        $body = getJsonBody();
        $fields = [];
        $params = [];
        if (isset($body['name'])) {
            $fields[] = 'name = ?';
            $params[] = trim((string)$body['name']);
        }
        if (!empty($body['mobile'])) {
            $fields[] = 'mobile = ?';
            $params[] = preg_replace('/\D/', '', (string)$body['mobile']);
        }
        if (array_key_exists('delivery_address', $body)) {
            $fields[] = 'delivery_address = ?';
            $params[] = $body['delivery_address'];
        }
        if (!$fields) jsonResponse(['success' => false, 'message' => 'Nothing to update'], 400);
        $params[] = $id;
        $pdo->prepare('UPDATE customers SET ' . implode(', ', $fields) . ' WHERE id = ?')->execute($params);
        $get = $pdo->prepare('SELECT * FROM customers WHERE id = ?');
        $get->execute([$id]);
        jsonResponse(['success' => true, 'customer' => $get->fetch()]);
    }

    jsonResponse(['success' => false, 'message' => 'Customers endpoint not found'], 404);
}
