<?php
require_once __DIR__ . '/../config.php';

function getDb(): PDO {
    static $pdo = null;
    if ($pdo === null) {
        $dsn = 'mysql:host=' . DB_HOST . ';port=' . DB_PORT . ';dbname=' . DB_NAME . ';charset=utf8mb4';
        $pdo = new PDO($dsn, DB_USER, DB_PASS, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
        ]);
    }
    return $pdo;
}

function jsonResponse($data, int $status = 200): void {
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($data, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    exit;
}

function getJsonBody(): array {
    $raw = file_get_contents('php://input');
    if (!$raw) return [];
    $decoded = json_decode($raw, true);
    return is_array($decoded) ? $decoded : [];
}

function parseJsonField($val, $fallback = []) {
    if (is_array($val)) return $val;
    if (!$val) return $fallback;
    $decoded = json_decode((string)$val, true);
    return is_array($decoded) ? $decoded : $fallback;
}

function attachAiStyleGuideMetaPhp(array $record): array {
    $imgUrl = trim((string)($record['ai_output_image_url'] ?? ''));
    if ($imgUrl === '') return $record;

    $base = basename(parse_url($imgUrl, PHP_URL_PATH) ?: '');
    if ($base === '' || !preg_match('/^[a-zA-Z0-9._-]+\.png$/i', $base)) {
        return $record;
    }

    $aiDir = dirname(__DIR__) . DIRECTORY_SEPARATOR . 'uploads' . DIRECTORY_SEPARATOR . 'ai-outputs';
    $metaFile = preg_replace('/\.png$/i', '-meta.json', $base);
    $metaPath = $aiDir . DIRECTORY_SEPARATOR . $metaFile;
    if (is_file($metaPath)) {
        $raw = @file_get_contents($metaPath);
        $meta = $raw ? json_decode($raw, true) : null;
        if (is_array($meta)) {
            if (!empty($meta['element_regions']) && is_array($meta['element_regions'])) {
                $record['element_regions'] = $meta['element_regions'];
            }
            if (!empty($meta['element_breakdown']) && is_array($meta['element_breakdown'])) {
                $record['element_breakdown'] = $meta['element_breakdown'];
            }
            if (isset($meta['output_aspect']) && is_numeric($meta['output_aspect'])) {
                $record['output_aspect'] = (float)$meta['output_aspect'];
            }
            if (!empty($meta['ai_guide_image_url'])) {
                $record['ai_guide_image_url'] = (string)$meta['ai_guide_image_url'];
            }
        }
    }

    if (empty($record['ai_guide_image_url'])) {
        $guideFile = preg_replace('/\.png$/i', '-guide.png', $base);
        if (is_file($aiDir . DIRECTORY_SEPARATOR . $guideFile)) {
            $record['ai_guide_image_url'] = '/uploads/ai-outputs/' . $guideFile;
        }
    }

    return $record;
}
