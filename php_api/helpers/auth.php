<?php
require_once __DIR__ . '/jwt.php';
require_once __DIR__ . '/db.php';

function getBearerToken(): ?string {
    $auth = $_SERVER['HTTP_AUTHORIZATION']
        ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION']
        ?? '';
    if (!$auth && !empty($_SERVER['HTTP_X_AUTH_TOKEN'])) {
        return trim((string)$_SERVER['HTTP_X_AUTH_TOKEN']);
    }
    if (!$auth && function_exists('apache_request_headers')) {
        $headers = apache_request_headers();
        foreach ($headers as $k => $v) {
            $lk = strtolower($k);
            if ($lk === 'authorization') {
                $auth = $v;
                break;
            }
            if ($lk === 'x-auth-token') {
                return trim((string)$v);
            }
        }
    }
    if (preg_match('/Bearer\s+(.+)/i', $auth, $m)) {
        return trim($m[1]);
    }
    return null;
}

function authenticateToken(): array {
    $token = getBearerToken();
    if (!$token) {
        jsonResponse(['success' => false, 'message' => 'Authentication token required'], 401);
    }
    $user = jwtDecode($token);
    if (!$user) {
        jsonResponse(['success' => false, 'message' => 'Invalid or expired token'], 401);
    }
    return $user;
}

function requireRoles(array $allowedRoles): array {
    $user = authenticateToken();
    if (($user['type'] ?? '') !== 'staff') {
        jsonResponse(['success' => false, 'message' => 'Staff access required'], 403);
    }
    if (!in_array($user['role'] ?? '', $allowedRoles, true)) {
        jsonResponse([
            'success' => false,
            'message' => 'Access denied. Required role: ' . implode(', ', $allowedRoles),
        ], 403);
    }
    return $user;
}

function requireCustomer(): array {
    $user = authenticateToken();
    if (($user['type'] ?? '') !== 'customer') {
        jsonResponse(['success' => false, 'message' => 'Customer access required'], 403);
    }
    return $user;
}
