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
        ensureAppSchemaPhp($pdo);
    }
    return $pdo;
}

function ensureAppSchemaPhp(PDO $pdo): void {
    static $checked = false;
    if ($checked) return;
    $checked = true;
    try {
        $col = $pdo->query("SHOW COLUMNS FROM orders LIKE 'production_place'")->fetch();
        if (!$col) {
            $pdo->exec('ALTER TABLE orders ADD COLUMN production_place VARCHAR(180) NULL AFTER assigned_production_user_id');
        }
        $pdo->exec(
            'CREATE TABLE IF NOT EXISTS notifications (
              id INT AUTO_INCREMENT PRIMARY KEY,
              user_id INT NOT NULL,
              order_id INT NOT NULL,
              type VARCHAR(50) NOT NULL,
              title VARCHAR(180) NOT NULL,
              message TEXT NOT NULL,
              notify_for_date DATE NULL,
              is_read TINYINT(1) NOT NULL DEFAULT 0,
              created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
              UNIQUE KEY uniq_user_order_type_date (user_id, order_id, type, notify_for_date),
              INDEX idx_notif_user_read (user_id, is_read),
              INDEX idx_notif_order (order_id),
              CONSTRAINT fk_notif_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
              CONSTRAINT fk_notif_order FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
        );
    } catch (Throwable $e) {
        // Ignore if schema doesn't exist yet (e.g. during initial seed)
    }
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
