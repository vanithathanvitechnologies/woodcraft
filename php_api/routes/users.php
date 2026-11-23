<?php

function handleUsersRoutes(string $method, array $segments): void {
    $authUser = requireRoles(['admin', 'owner']);
    $pdo = getDb();
    $id = isset($segments[0]) && is_numeric($segments[0]) ? (int)$segments[0] : null;

    if ($method === 'GET' && $id === null) {
        $role = $_GET['role'] ?? '';
        $search = trim((string)($_GET['search'] ?? ''));

        $sql = 'SELECT id, name, email, phone, role, is_active, created_at FROM users WHERE 1=1';
        $params = [];
        if ($role && $role !== 'all') {
            $sql .= ' AND role = ?';
            $params[] = $role;
        }
        if ($search !== '') {
            $sql .= ' AND (name LIKE ? OR email LIKE ? OR phone LIKE ?)';
            $like = "%$search%";
            array_push($params, $like, $like, $like);
        }
        $sql .= ' ORDER BY created_at DESC';
        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);
        jsonResponse(['success' => true, 'users' => $stmt->fetchAll()]);
    }

    if ($method === 'POST' && $id === null) {
        $body = getJsonBody();
        $name = trim((string)($body['name'] ?? ''));
        $email = strtolower(trim((string)($body['email'] ?? '')));
        $phone = $body['phone'] ?? null;
        $password = (string)($body['password'] ?? '');
        $role = (string)($body['role'] ?? '');

        if (!$name || !$email || !$password || !in_array($role, ['admin', 'owner', 'sales', 'production'], true)) {
            jsonResponse(['success' => false, 'message' => 'Name, email, password, and valid role are required'], 400);
        }

        $chk = $pdo->prepare('SELECT id FROM users WHERE email = ?');
        $chk->execute([$email]);
        if ($chk->fetch()) {
            jsonResponse(['success' => false, 'message' => 'A user with this email already exists'], 409);
        }

        $hash = password_hash($password, PASSWORD_BCRYPT);
        $ins = $pdo->prepare('INSERT INTO users (name, email, phone, password_hash, role, is_active) VALUES (?, ?, ?, ?, ?, 1)');
        $ins->execute([$name, $email, $phone, $hash, $role]);
        $newId = (int)$pdo->lastInsertId();

        $get = $pdo->prepare('SELECT id, name, email, phone, role, is_active, created_at FROM users WHERE id = ?');
        $get->execute([$newId]);
        jsonResponse(['success' => true, 'user' => $get->fetch()], 201);
    }

    if ($method === 'PUT' && $id !== null) {
        $body = getJsonBody();
        $fields = [];
        $params = [];

        if (isset($body['name'])) {
            $fields[] = 'name = ?';
            $params[] = trim((string)$body['name']);
        }
        if (array_key_exists('phone', $body)) {
            $fields[] = 'phone = ?';
            $params[] = $body['phone'];
        }
        if (isset($body['role']) && in_array($body['role'], ['admin', 'owner', 'sales', 'production'], true)) {
            $fields[] = 'role = ?';
            $params[] = $body['role'];
        }
        if (array_key_exists('is_active', $body)) {
            $fields[] = 'is_active = ?';
            $params[] = $body['is_active'] ? 1 : 0;
        }
        if (!empty($body['password']) && strlen(trim((string)$body['password'])) >= 4) {
            $fields[] = 'password_hash = ?';
            $params[] = password_hash(trim((string)$body['password']), PASSWORD_BCRYPT);
        }

        if (!$fields) jsonResponse(['success' => false, 'message' => 'No fields to update'], 400);
        $params[] = $id;
        $pdo->prepare('UPDATE users SET ' . implode(', ', $fields) . ' WHERE id = ?')->execute($params);

        $get = $pdo->prepare('SELECT id, name, email, phone, role, is_active, created_at FROM users WHERE id = ?');
        $get->execute([$id]);
        jsonResponse(['success' => true, 'user' => $get->fetch()]);
    }

    if ($method === 'DELETE' && $id !== null) {
        if ($id === (int)$authUser['id']) {
            jsonResponse(['success' => false, 'message' => 'Cannot delete your own account'], 400);
        }
        $pdo->prepare('DELETE FROM users WHERE id = ?')->execute([$id]);
        jsonResponse(['success' => true, 'message' => 'User deleted']);
    }

    jsonResponse(['success' => false, 'message' => 'Users endpoint not found'], 404);
}
