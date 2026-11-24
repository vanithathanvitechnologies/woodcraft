<?php
/**
 * One-Click Database Setup & Seed Script for cPanel
 * Open once in browser: https://yourdomain.com/php_api/seed.php
 * (Delete or rename after seeding for security!)
 */
ini_set('display_errors', '1');
ini_set('display_startup_errors', '1');
error_reporting(E_ALL);
header('Content-Type: text/plain; charset=utf-8');

$required = ['config.php', 'schema.sql', 'helpers/db.php', 'helpers/constants.php', 'helpers/door_generator.php'];
$missing = [];
foreach ($required as $f) {
    if (!file_exists(__DIR__ . '/' . $f)) $missing[] = $f;
}
if ($missing) {
    echo "MISSING FILES in " . __DIR__ . ":\n - " . implode("\n - ", $missing) . "\n\n";
    echo "Files currently in this folder:\n - " . implode("\n - ", scandir(__DIR__)) . "\n";
    exit;
}

require_once __DIR__ . '/config.php';
require_once __DIR__ . '/helpers/db.php';
require_once __DIR__ . '/helpers/constants.php';
require_once __DIR__ . '/helpers/door_generator.php';

try {
    $pdo = getDb();
    echo "Connected to MySQL database: " . DB_NAME . "\n";

    // 1. Run schema.sql
    $sql = file_get_contents(__DIR__ . '/schema.sql');
    $pdo->exec($sql);
    echo "Tables verified/created.\n";

    // 2. Seed default staff accounts
    $hash = password_hash('123456', PASSWORD_BCRYPT);
    $seedUsers = [
        ['Admin', 'admin@wooden.com', '7603970435', 'admin'],
        ['Owner', 'owner@wooden.com', '7603970435', 'owner'],
        ['Sales Team', 'sales@wooden.com', '7603970435', 'sales'],
        ['Production Team', 'production@wooden.com', '7603970435', 'production'],
    ];
    $uStmt = $pdo->prepare('INSERT IGNORE INTO users (name, email, phone, password_hash, role, is_active) VALUES (?, ?, ?, ?, ?, 1)');
    foreach ($seedUsers as $u) {
        $uStmt->execute([$u[0], $u[1], $u[2], $hash, $u[3]]);
    }

    $salesId = $pdo->query("SELECT id FROM users WHERE role = 'sales' LIMIT 1")->fetchColumn() ?: null;
    $prodId = $pdo->query("SELECT id FROM users WHERE role = 'production' LIMIT 1")->fetchColumn() ?: null;

    // 3. Seed Design Catalog (uses Suresh Timbers catalog manifest if available)
    $catCount = (int)$pdo->query('SELECT COUNT(*) FROM design_catalog')->fetchColumn();
    if ($catCount === 0) {
        $stManifestPath = __DIR__ . '/uploads/catalog/suresh_timbers_catalog.json';
        if (is_file($stManifestPath)) {
            $stData = json_decode(file_get_contents($stManifestPath), true);
            $stItems = $stData['items'] ?? [];
            $cStmt = $pdo->prepare(
                'INSERT INTO design_catalog (title, category, carving_style, wood_species, base_price, image_url, additional_images, tags, description, is_trending, created_by)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
            );
            foreach ($stItems as $item) {
                $cStmt->execute([
                    (string)$item['title'],
                    (string)($item['category'] ?? 'Main Door & Frame'),
                    (string)($item['carving_style'] ?? ''),
                    (string)($item['wood_species'] ?? 'Burma Teak'),
                    (float)($item['base_price'] ?? 35000),
                    (string)$item['image_url'],
                    '[]',
                    (string)($item['tags'] ?? 'suresh timbers'),
                    (string)($item['description'] ?? ''),
                    !empty($item['is_trending']) ? 1 : 0,
                    $salesId,
                ]);
            }
            echo "Seeded " . count($stItems) . " Suresh Timbers catalog designs.\n";
        } else {
            $samples = [
                ['Royal Chettinad Lotus Main Door', 'Main Door & Frame', 'Chettinad Floral & Pillar', 'Burma Teak', 42000, 'Natural Teak Matte', 'Double Leaf', 'main door,chettinad,double leaf', 1],
                ['Temple Bells Pooja Door', 'Pooja Door', 'Traditional Temple Brass Bells', 'Nilambur Teak', 34000, 'Honey Gold Gloss', 'Double Leaf', 'pooja,temple,bells', 1],
                ['Modern Heritage Panel Main Door', 'Main Door & Frame', 'Minimalist Carved Medallion', 'Ghana Teak', 29500, 'Dark Walnut Satin', 'Single Leaf', 'modern,single leaf,walnut', 1],
                ['Rosewood Peacock Grand Frame', 'Main Door & Frame', 'Peacock Arch Carving', 'Indian Rosewood', 54000, 'Royal Rosewood Gloss', 'Double Leaf', 'rosewood,peacock,luxury', 0],
                ['Classic Teak Arch Window', 'Window', 'Beaded Border Frame', 'Burma Teak', 18500, 'Natural PU Clear', 'Double Leaf', 'window,teak', 0],
            ];
            $cStmt = $pdo->prepare(
                'INSERT INTO design_catalog (title, category, carving_style, wood_species, base_price, image_url, tags, description, is_trending, created_by)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
            );
            foreach ($samples as $idx => $s) {
                $img = renderDoorPngPhp([
                    'wood_species' => $s[3],
                    'polish_shade' => $s[5],
                    'leaf_type' => $s[6],
                    'woodwork_category' => $s[1],
                    'output_dir' => __DIR__ . '/uploads/catalog',
                    'prefix' => 'catalog-' . ($idx + 1),
                ]);
                $cStmt->execute([
                    $s[0], $s[1], $s[2], $s[3], $s[4],
                    '/uploads/catalog/' . $img['filename'],
                    $s[7], "Handcrafted {$s[0]} in seasoned {$s[3]}.", $s[8], $salesId,
                ]);
            }
            echo "Seeded 5 catalog designs with PNG artwork.\n";
        }
    }

    // 4. Seed Initial Customer & Orders
    $ordCount = (int)$pdo->query('SELECT COUNT(*) FROM orders')->fetchColumn();
    if ($ordCount === 0) {
        $pdo->prepare('INSERT IGNORE INTO customers (name, mobile, delivery_address, created_by) VALUES (?, ?, ?, ?)')
            ->execute(['Surexo Customer', '7603970435', '', $salesId]);

        $c1 = $pdo->query("SELECT id FROM customers WHERE mobile = '7603970435'")->fetchColumn();
        $c2 = $c1;
        $dIds = $pdo->query('SELECT id FROM design_catalog ORDER BY id ASC LIMIT 3')->fetchAll(PDO::FETCH_COLUMN);

        $ai1 = renderDoorPngPhp([
            'wood_species' => 'Burma Teak', 'polish_shade' => 'Natural Teak Matte',
            'leaf_type' => 'Double Leaf', 'woodwork_category' => 'Main Door & Frame',
            'output_dir' => __DIR__ . '/uploads/ai-outputs', 'prefix' => 'seed-order-1',
        ]);
        $ai2 = renderDoorPngPhp([
            'wood_species' => 'Nilambur Teak', 'polish_shade' => 'Honey Gold Gloss',
            'leaf_type' => 'Double Leaf', 'woodwork_category' => 'Pooja Door',
            'output_dir' => __DIR__ . '/uploads/ai-outputs', 'prefix' => 'seed-order-2',
        ]);

        $oStmt = $pdo->prepare(
            'INSERT INTO orders (
              job_id, customer_id, sales_user_id, assigned_production_user_id,
              woodwork_category, width_inches, height_inches, frame_section, door_thickness,
              leaf_type, wood_species, carving_pattern, polish_shade, hardware, quantity,
              custom_notes, workshop_notes, reference_design_ids, reference_elements, ai_output_image_url,
              total_cost, advance_amount, balance_amount, expected_delivery_date, priority,
              current_stage, current_stage_name, is_dispatched
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)'
        );

        $oStmt->execute([
            'SUW-2026-0001', $c1, $salesId, $prodId,
            'Main Door & Frame', 48, 84, '5 x 3.5 inch', '2 inch (50mm)',
            'Double Leaf', 'Burma Teak', 'Chettinad Lotus Center + Beaded Frame',
            'Natural Teak Matte', 'Antique Brass Lion Handles & Yale Mortise', 1,
            'Ensure deep 3D lotus carving in center panels',
            'Check timber moisture <10% before CNC carving.',
            json_encode(array_slice($dIds, 0, 2)),
            json_encode([['design_id' => $dIds[0] ?? 1, 'element' => 'Frame Style & Center Carving']]),
            '/uploads/ai-outputs/' . $ai1['filename'],
            78500, 35000, 43500, date('Y-m-d', strtotime('+10 days')), 'High',
            4, getStageName(4),
        ]);
        $ord1Id = (int)$pdo->lastInsertId();
        for ($st = 1; $st <= 4; $st++) {
            $pdo->prepare('INSERT INTO order_stage_history (order_id, stage_number, stage_name, updated_by, notes) VALUES (?, ?, ?, ?, ?)')
                ->execute([$ord1Id, $st, getStageName($st), $st === 1 ? $salesId : $prodId, 'Updated to ' . getStageName($st)]);
        }

        $oStmt->execute([
            'SUW-2026-0002', $c2, $salesId, $prodId,
            'Pooja Door', 36, 78, '4 x 3 inch', '1.5 inch (38mm)',
            'Double Leaf', 'Nilambur Teak', 'Traditional Temple Bells Grid',
            'Honey Gold Gloss', '24 Solid Brass Bells + Brass Aldrop', 1,
            'Include Om motif on top arch',
            'Drill brass bell slots precisely with 1.5 inch spacing.',
            json_encode(array_slice($dIds, 1, 2)),
            json_encode([['design_id' => $dIds[1] ?? 2, 'element' => 'Temple Bells Grid']]),
            '/uploads/ai-outputs/' . $ai2['filename'],
            46000, 20000, 26000, date('Y-m-d', strtotime('+4 days')), 'Urgent',
            6, getStageName(6),
        ]);
        $ord2Id = (int)$pdo->lastInsertId();
        for ($st = 1; $st <= 6; $st++) {
            $pdo->prepare('INSERT INTO order_stage_history (order_id, stage_number, stage_name, updated_by, notes) VALUES (?, ?, ?, ?, ?)')
                ->execute([$ord2Id, $st, getStageName($st), $st === 1 ? $salesId : $prodId, 'Updated to ' . getStageName($st)]);
        }
        echo "Seeded initial customer and 2 live orders.\n";
    }

    echo "\nSETUP COMPLETE!\n";
    echo "Staff Accounts:\n";
    echo "  Admin:      admin@wooden.com\n";
    echo "  Owner:      owner@wooden.com\n";
    echo "  Sales:      sales@wooden.com\n";
    echo "  Production: production@wooden.com\n";
    echo "Customer Mobile: 7603970435\n";
} catch (Throwable $e) {
    http_response_code(500);
    echo "ERROR: " . $e->getMessage() . "\n";
}
