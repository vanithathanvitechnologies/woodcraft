<?php
require_once __DIR__ . '/../config.php';

function base64UrlEncode(string $data): string {
    return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
}

function base64UrlDecode(string $data): string {
    $pad = strlen($data) % 4;
    if ($pad) {
        $data .= str_repeat('=', 4 - $pad);
    }
    return base64_decode(strtr($data, '-_', '+/'));
}

function jwtEncode(array $payload, int $ttlSeconds = JWT_EXPIRES_SECONDS): string {
    $header = ['alg' => 'HS256', 'typ' => 'JWT'];
    $payload['iat'] = time();
    $payload['exp'] = time() + $ttlSeconds;

    $h = base64UrlEncode(json_encode($header));
    $p = base64UrlEncode(json_encode($payload));
    $sig = hash_hmac('sha256', "$h.$p", JWT_SECRET, true);
    return "$h.$p." . base64UrlEncode($sig);
}

function jwtDecode(string $token): ?array {
    $parts = explode('.', $token);
    if (count($parts) !== 3) return null;
    [$h, $p, $s] = $parts;
    $expected = base64UrlEncode(hash_hmac('sha256', "$h.$p", JWT_SECRET, true));
    if (!hash_equals($expected, $s)) return null;

    $payload = json_decode(base64UrlDecode($p), true);
    if (!is_array($payload)) return null;
    if (isset($payload['exp']) && $payload['exp'] < time()) return null;
    return $payload;
}
