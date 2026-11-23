<?php

function handleAuthRoutes(string $method, array $segments): void {
    $pdo = getDb();

    // POST /api/auth/login
    if ($method === 'POST' && ($segments[0] ?? '') === 'login') {
        $body = getJsonBody();
        $email = strtolower(trim((string)($body['email'] ?? '')));
        $password = (string)($body['password'] ?? '');

        if (!$email || !$password) {
            jsonResponse(['success' => false, 'message' => 'Email and password are required'], 400);
        }

        $stmt = $pdo->prepare('SELECT id, name, email, phone, password_hash, role, is_active FROM users WHERE email = ? LIMIT 1');
        $stmt->execute([$email]);
        $user = $stmt->fetch();

        if (!$user || !password_verify($password, $user['password_hash'])) {
            jsonResponse(['success' => false, 'message' => 'Invalid email or password'], 401);
        }
        if ((int)$user['is_active'] !== 1) {
            jsonResponse(['success' => false, 'message' => 'Account is deactivated. Contact Admin.'], 403);
        }

        $token = jwtEncode([
            'id' => (int)$user['id'],
            'name' => $user['name'],
            'email' => $user['email'],
            'role' => $user['role'],
            'type' => 'staff',
        ]);

        jsonResponse([
            'success' => true,
            'token' => $token,
            'user' => [
                'id' => (int)$user['id'],
                'name' => $user['name'],
                'email' => $user['email'],
                'phone' => $user['phone'],
                'role' => $user['role'],
            ],
        ]);
    }

    // GET /api/auth/me
    if ($method === 'GET' && ($segments[0] ?? '') === 'me') {
        $authUser = authenticateToken();
        if (($authUser['type'] ?? '') === 'customer') {
            $stmt = $pdo->prepare('SELECT id, name, mobile, delivery_address, created_at FROM customers WHERE id = ?');
            $stmt->execute([$authUser['id']]);
            $customer = $stmt->fetch();
            if (!$customer) jsonResponse(['success' => false, 'message' => 'Customer not found'], 404);
            jsonResponse(['success' => true, 'type' => 'customer', 'customer' => $customer]);
        }

        $stmt = $pdo->prepare('SELECT id, name, email, phone, role, is_active, created_at FROM users WHERE id = ?');
        $stmt->execute([$authUser['id']]);
        $user = $stmt->fetch();
        if (!$user) jsonResponse(['success' => false, 'message' => 'User not found'], 404);
        jsonResponse(['success' => true, 'type' => 'staff', 'user' => $user]);
    }

    // POST /api/auth/customer/request-otp
    if ($method === 'POST' && ($segments[0] ?? '') === 'customer' && ($segments[1] ?? '') === 'request-otp') {
        $body = getJsonBody();
        $rawMobile = preg_replace('/\D/', '', (string)($body['mobile'] ?? ''));
        if (strlen($rawMobile) < 10) {
            jsonResponse(['success' => false, 'message' => 'Please enter a valid 10-digit mobile number'], 400);
        }

        $last10 = substr($rawMobile, -10);
        $stmt = $pdo->prepare('SELECT id, name, mobile, delivery_address FROM customers WHERE REPLACE(mobile, " ", "") LIKE ? LIMIT 1');
        $stmt->execute(["%$last10"]);
        $customer = $stmt->fetch();

        if (!$customer) {
            jsonResponse([
                'success' => false,
                'message' => 'Mobile number not found. Please use the mobile number registered with our Sales Team.',
            ], 404);
        }

        $otpCode = (string)random_int(100000, 999999);
        $expiresAt = date('Y-m-d H:i:s', time() + 300);

        $ins = $pdo->prepare('INSERT INTO customer_otps (mobile, otp_code, expires_at) VALUES (?, ?, ?)');
        $ins->execute([$customer['mobile'], $otpCode, $expiresAt]);

        $resp = [
            'success' => true,
            'message' => 'OTP sent successfully',
            'mobile' => $customer['mobile'],
            'customer_name' => $customer['name'],
            'auto_verify' => AUTO_VERIFY_OTP,
        ];
        if (AUTO_VERIFY_OTP) {
            $resp['otp_code'] = $otpCode;
        }
        jsonResponse($resp);
    }

    // POST /api/auth/customer/verify-otp
    if ($method === 'POST' && ($segments[0] ?? '') === 'customer' && ($segments[1] ?? '') === 'verify-otp') {
        $body = getJsonBody();
        $rawMobile = preg_replace('/\D/', '', (string)($body['mobile'] ?? ''));
        $otp = trim((string)($body['otp'] ?? ''));

        if (strlen($rawMobile) < 10 || !$otp) {
            jsonResponse(['success' => false, 'message' => 'Mobile number and OTP are required'], 400);
        }

        $last10 = substr($rawMobile, -10);
        $stmt = $pdo->prepare('SELECT id, name, mobile, delivery_address FROM customers WHERE REPLACE(mobile, " ", "") LIKE ? LIMIT 1');
        $stmt->execute(["%$last10"]);
        $customer = $stmt->fetch();
        if (!$customer) jsonResponse(['success' => false, 'message' => 'Customer not found'], 404);

        $otpStmt = $pdo->prepare('SELECT id, otp_code, expires_at FROM customer_otps WHERE mobile = ? ORDER BY id DESC LIMIT 1');
        $otpStmt->execute([$customer['mobile']]);
        $otpRow = $otpStmt->fetch();

        if (!$otpRow || $otpRow['otp_code'] !== $otp) {
            jsonResponse(['success' => false, 'message' => 'Invalid OTP code'], 401);
        }
        if (strtotime($otpRow['expires_at']) < time()) {
            jsonResponse(['success' => false, 'message' => 'OTP has expired. Please request a new one.'], 401);
        }

        $pdo->prepare('UPDATE customer_otps SET verified = 1 WHERE id = ?')->execute([$otpRow['id']]);

        $token = jwtEncode([
            'id' => (int)$customer['id'],
            'name' => $customer['name'],
            'mobile' => $customer['mobile'],
            'type' => 'customer',
        ], 30 * 24 * 60 * 60);

        jsonResponse([
            'success' => true,
            'token' => $token,
            'customer' => $customer,
        ]);
    }

    jsonResponse(['success' => false, 'message' => 'Auth endpoint not found'], 404);
}
