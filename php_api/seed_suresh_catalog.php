<?php
/**
 * One-Click Suresh Timbers Design Catalog Importer for cPanel / MySQL
 *
 * Usage:
 *   - Append missing Suresh Timbers designs (idempotent):
 *       https://yourdomain.com/woodcraft/api/seed_suresh_catalog.php
 *   - Archive old non-Suresh Timbers designs & keep only Suresh Timbers catalog:
 *       https://yourdomain.com/woodcraft/api/seed_suresh_catalog.php?replace=1
 */
ini_set('display_errors', '1');
ini_set('display_startup_errors', '1');
error_reporting(E_ALL);
header('Content-Type: text/plain; charset=utf-8');

require_once __DIR__ . '/config.php';
require_once __DIR__ . '/helpers/db.php';

try {
    $pdo = getDb();
    $manifestPath = __DIR__ . '/uploads/catalog/suresh_timbers_catalog.json';
    if (!is_file($manifestPath)) {
        http_response_code(404);
        echo "ERROR: Missing manifest at $manifestPath\n";
        exit;
    }

    $manifest = json_decode(file_get_contents($manifestPath), true);
    $items = $manifest['items'] ?? [];
    if (!is_array($items) || count($items) === 0) {
        http_response_code(500);
        echo "ERROR: Manifest contains no catalog items.\n";
        exit;
    }

    $salesId = $pdo->query("SELECT id FROM users WHERE role IN ('sales', 'owner', 'admin') ORDER BY FIELD(role, 'sales', 'owner', 'admin') LIMIT 1")->fetchColumn() ?: null;

    if (($_GET['replace'] ?? '') === '1') {
        $archived = $pdo->exec("UPDATE design_catalog SET is_archived = 1 WHERE image_url NOT LIKE '/uploads/catalog/st-%'");
        echo "Archived $archived previous non-Suresh Timbers catalog entries.\n";
    }

    $checkStmt = $pdo->prepare('SELECT id FROM design_catalog WHERE image_url = ? LIMIT 1');
    $insertStmt = $pdo->prepare(
        'INSERT INTO design_catalog
            (title, category, carving_style, wood_species, base_price, image_url, additional_images, tags, description, is_trending, is_archived, created_by)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?)'
    );
    $updateStmt = $pdo->prepare(
        'UPDATE design_catalog
         SET title = ?, category = ?, carving_style = ?, wood_species = ?, base_price = ?, tags = ?, description = ?, is_trending = ?, is_archived = 0
         WHERE id = ?'
    );

    // Archive any legacy designs belonging to removed categories
    $archivedLegacy = $pdo->exec("UPDATE design_catalog SET is_archived = 1 WHERE category NOT IN ('Door', 'Wood Frames', 'Hard Wood') AND image_url NOT LIKE '/uploads/catalog/st-%'");
    if ($archivedLegacy > 0) {
        echo "Archived $archivedLegacy legacy items from removed categories.\n";
    }

    $inserted = 0;
    $updated = 0;
    $missingFiles = 0;

    foreach ($items as $item) {
        $imgUrl = (string)($item['image_url'] ?? '');
        if ($imgUrl === '') continue;

        $diskFile = __DIR__ . '/' . ltrim($imgUrl, '/');
        if (!is_file($diskFile)) {
            $missingFiles++;
        }

        $title = (string)$item['title'];
        $category = (string)($item['category'] ?? 'Door');
        $carving = (string)($item['carving_style'] ?? '');
        $wood = (string)($item['wood_species'] ?? 'Burma Teak');
        $price = (float)($item['base_price'] ?? 35000);
        $tags = (string)($item['tags'] ?? 'suresh timbers');
        $desc = (string)($item['description'] ?? '');
        $trending = !empty($item['is_trending']) ? 1 : 0;

        $checkStmt->execute([$imgUrl]);
        $foundId = $checkStmt->fetchColumn();
        if ($foundId) {
            $updateStmt->execute([$title, $category, $carving, $wood, $price, $tags, $desc, $trending, (int)$foundId]);
            $updated++;
            continue;
        }

        $insertStmt->execute([
            $title,
            $category,
            $carving,
            $wood,
            $price,
            $imgUrl,
            '[]',
            $tags,
            $desc,
            $trending,
            $salesId,
        ]);
        $inserted++;
    }

    echo "Suresh Timbers Catalog Import Complete!\n";
    echo "  Manifest items : " . count($items) . "\n";
    echo "  Newly inserted : $inserted\n";
    echo "  Updated existing: $updated\n";
    if ($missingFiles > 0) {
        echo "  WARNING: $missingFiles image files were not found on disk under uploads/catalog/.\n";
        echo "  Make sure you uploaded php_api/uploads/catalog/ (or extracted uploads_live_photos.zip).\n";
    }
} catch (Throwable $e) {
    http_response_code(500);
    echo "ERROR: " . $e->getMessage() . "\n";
}
