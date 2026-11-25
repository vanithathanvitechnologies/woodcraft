<?php

function ensureWoodenCategoriesTable(PDO $pdo): void {
    static $initialized = false;
    if ($initialized) {
        return;
    }

    $pdo->exec("
        CREATE TABLE IF NOT EXISTS wooden_categories (
            id INT AUTO_INCREMENT PRIMARY KEY,
            name VARCHAR(100) NOT NULL UNIQUE,
            description VARCHAR(255) NOT NULL DEFAULT '',
            is_active TINYINT(1) NOT NULL DEFAULT 1,
            sort_order INT NOT NULL DEFAULT 0,
            created_by INT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX idx_wooden_categories_active (is_active),
            INDEX idx_wooden_categories_sort (sort_order)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ");

    $count = (int)$pdo->query('SELECT COUNT(*) FROM wooden_categories')->fetchColumn();
    if ($count === 0) {
        $defaults = [
            ['Door', 'Main entrance doors, pooja doors, carved teak & single/double leaf doors', 1],
            ['Wood Frames', 'Carved teak nilai frames, chowkhats, pillars & window frames', 2],
            ['Hard Wood', 'Seasoned A-grade Burma teak, sal wood & timber sections', 3],
        ];
        $ins = $pdo->prepare(
            'INSERT IGNORE INTO wooden_categories (name, description, is_active, sort_order) VALUES (?, ?, 1, ?)'
        );
        foreach ($defaults as [$name, $desc, $order]) {
            $ins->execute([$name, $desc, $order]);
        }

        // Preserve any custom category already present in design_catalog
        try {
            $existing = $pdo->query("SELECT DISTINCT TRIM(category) AS cat FROM design_catalog WHERE category IS NOT NULL AND TRIM(category) <> ''")->fetchAll();
            $nextOrder = count($defaults) + 1;
            foreach ($existing as $row) {
                $cat = trim((string)($row['cat'] ?? ''));
                if ($cat !== '') {
                    $ins->execute([$cat, '', $nextOrder++]);
                }
            }
        } catch (Throwable $e) {
            // design_catalog may not exist yet on fresh install
        }
    }

    $initialized = true;
}

function getActiveWoodenCategoryNames(PDO $pdo): array {
    try {
        ensureWoodenCategoriesTable($pdo);
        $stmt = $pdo->query('SELECT name FROM wooden_categories WHERE is_active = 1 ORDER BY sort_order ASC, id ASC');
        $names = array_values(array_filter(array_map(
            fn($r) => trim((string)($r['name'] ?? '')),
            $stmt->fetchAll()
        )));
        return !empty($names) ? $names : WOODWORK_CATEGORIES;
    } catch (Throwable $e) {
        return WOODWORK_CATEGORIES;
    }
}

function handleCategoriesRoutes(string $method, array $segments): void {
    $pdo = getDb();
    ensureWoodenCategoriesTable($pdo);

    $id = isset($segments[0]) && is_numeric($segments[0]) ? (int)$segments[0] : null;

    // GET /api/categories (accessible to all authenticated staff so Staff App & Admin stay in sync)
    if ($method === 'GET' && $id === null) {
        requireRoles(['admin', 'owner', 'sales', 'production']);
        $includeInactive = ($_GET['include_inactive'] ?? '') === 'true';

        $sql = '
            SELECT
                wc.*,
                (SELECT COUNT(*) FROM design_catalog dc WHERE LOWER(TRIM(dc.category)) = LOWER(TRIM(wc.name)) AND dc.is_archived = 0) AS design_count,
                (SELECT COUNT(*) FROM design_catalog dc WHERE LOWER(TRIM(dc.category)) = LOWER(TRIM(wc.name))) AS total_design_count
            FROM wooden_categories wc
            WHERE 1=1
        ';
        if (!$includeInactive) {
            $sql .= ' AND wc.is_active = 1';
        }
        $sql .= ' ORDER BY wc.sort_order ASC, wc.id ASC';

        $rows = $pdo->query($sql)->fetchAll();
        foreach ($rows as &$row) {
            $row['id'] = (int)$row['id'];
            $row['is_active'] = (int)$row['is_active'];
            $row['sort_order'] = (int)$row['sort_order'];
            $row['design_count'] = (int)$row['design_count'];
            $row['total_design_count'] = (int)$row['total_design_count'];
        }
        unset($row);

        jsonResponse(['success' => true, 'categories' => $rows]);
    }

    // POST /api/categories (Admin / Owner only)
    if ($method === 'POST' && $id === null) {
        $authUser = requireRoles(['admin', 'owner']);
        $body = getJsonBody();

        $name = trim((string)($body['name'] ?? ''));
        $description = trim((string)($body['description'] ?? ''));
        $isActive = array_key_exists('is_active', $body) ? ($body['is_active'] ? 1 : 0) : 1;

        if ($name === '') {
            jsonResponse(['success' => false, 'message' => 'Category name is required'], 400);
        }
        if (mb_strlen($name) > 100) {
            jsonResponse(['success' => false, 'message' => 'Category name must be 100 characters or fewer'], 400);
        }

        $dup = $pdo->prepare('SELECT id FROM wooden_categories WHERE LOWER(TRIM(name)) = LOWER(?) LIMIT 1');
        $dup->execute([$name]);
        if ($dup->fetch()) {
            jsonResponse(['success' => false, 'message' => 'A wooden category with this name already exists'], 409);
        }

        if (isset($body['sort_order']) && $body['sort_order'] !== '') {
            $sortOrder = (int)$body['sort_order'];
        } else {
            $maxOrder = (int)$pdo->query('SELECT COALESCE(MAX(sort_order), 0) FROM wooden_categories')->fetchColumn();
            $sortOrder = $maxOrder + 1;
        }

        $ins = $pdo->prepare(
            'INSERT INTO wooden_categories (name, description, is_active, sort_order, created_by) VALUES (?, ?, ?, ?, ?)'
        );
        $ins->execute([$name, $description, $isActive, $sortOrder, $authUser['id'] ?? null]);

        $newId = (int)$pdo->lastInsertId();
        $get = $pdo->prepare('
            SELECT wc.*,
                (SELECT COUNT(*) FROM design_catalog dc WHERE LOWER(TRIM(dc.category)) = LOWER(TRIM(wc.name)) AND dc.is_archived = 0) AS design_count,
                (SELECT COUNT(*) FROM design_catalog dc WHERE LOWER(TRIM(dc.category)) = LOWER(TRIM(wc.name))) AS total_design_count
            FROM wooden_categories wc WHERE wc.id = ?
        ');
        $get->execute([$newId]);
        $cat = $get->fetch();
        jsonResponse(['success' => true, 'category' => $cat], 201);
    }

    // PUT /api/categories/:id (Admin / Owner only)
    if ($method === 'PUT' && $id !== null) {
        requireRoles(['admin', 'owner']);
        $body = getJsonBody();

        $curStmt = $pdo->prepare('SELECT * FROM wooden_categories WHERE id = ?');
        $curStmt->execute([$id]);
        $current = $curStmt->fetch();
        if (!$current) {
            jsonResponse(['success' => false, 'message' => 'Wooden category not found'], 404);
        }

        $fields = [];
        $params = [];
        $newName = null;

        if (array_key_exists('name', $body)) {
            $trimmed = trim((string)$body['name']);
            if ($trimmed === '') {
                jsonResponse(['success' => false, 'message' => 'Category name cannot be empty'], 400);
            }
            if (mb_strlen($trimmed) > 100) {
                jsonResponse(['success' => false, 'message' => 'Category name must be 100 characters or fewer'], 400);
            }
            $dup = $pdo->prepare('SELECT id FROM wooden_categories WHERE LOWER(TRIM(name)) = LOWER(?) AND id <> ? LIMIT 1');
            $dup->execute([$trimmed, $id]);
            if ($dup->fetch()) {
                jsonResponse(['success' => false, 'message' => 'Another wooden category already uses this name'], 409);
            }
            $fields[] = 'name = ?';
            $params[] = $trimmed;
            $newName = $trimmed;
        }
        if (array_key_exists('description', $body)) {
            $fields[] = 'description = ?';
            $params[] = trim((string)$body['description']);
        }
        if (array_key_exists('sort_order', $body)) {
            $fields[] = 'sort_order = ?';
            $params[] = (int)$body['sort_order'];
        }
        if (array_key_exists('is_active', $body)) {
            $fields[] = 'is_active = ?';
            $params[] = $body['is_active'] ? 1 : 0;
        }

        if (!$fields) {
            jsonResponse(['success' => false, 'message' => 'No fields to update'], 400);
        }

        $params[] = $id;
        $pdo->prepare('UPDATE wooden_categories SET ' . implode(', ', $fields) . ' WHERE id = ?')->execute($params);

        // Keep existing catalog designs and orders linked if renamed
        if ($newName !== null && strcasecmp((string)$current['name'], $newName) !== 0) {
            $pdo->prepare('UPDATE design_catalog SET category = ? WHERE LOWER(TRIM(category)) = LOWER(TRIM(?))')
                ->execute([$newName, $current['name']]);
            $pdo->prepare('UPDATE orders SET woodwork_category = ? WHERE LOWER(TRIM(woodwork_category)) = LOWER(TRIM(?))')
                ->execute([$newName, $current['name']]);
        }

        $get = $pdo->prepare('
            SELECT wc.*,
                (SELECT COUNT(*) FROM design_catalog dc WHERE LOWER(TRIM(dc.category)) = LOWER(TRIM(wc.name)) AND dc.is_archived = 0) AS design_count,
                (SELECT COUNT(*) FROM design_catalog dc WHERE LOWER(TRIM(dc.category)) = LOWER(TRIM(wc.name))) AS total_design_count
            FROM wooden_categories wc WHERE wc.id = ?
        ');
        $get->execute([$id]);
        jsonResponse(['success' => true, 'category' => $get->fetch()]);
    }

    // DELETE /api/categories/:id (Admin / Owner only)
    if ($method === 'DELETE' && $id !== null) {
        requireRoles(['admin', 'owner']);

        $curStmt = $pdo->prepare('SELECT * FROM wooden_categories WHERE id = ?');
        $curStmt->execute([$id]);
        $current = $curStmt->fetch();
        if (!$current) {
            jsonResponse(['success' => false, 'message' => 'Wooden category not found'], 404);
        }

        $cntStmt = $pdo->prepare('SELECT COUNT(*) FROM design_catalog WHERE LOWER(TRIM(category)) = LOWER(TRIM(?)) AND is_archived = 0');
        $cntStmt->execute([$current['name']]);
        $activeDesigns = (int)$cntStmt->fetchColumn();
        if ($activeDesigns > 0) {
            jsonResponse([
                'success' => false,
                'message' => "Cannot delete \"{$current['name']}\" because {$activeDesigns} active catalog design(s) use it. Move or archive those designs first, or disable this category.",
            ], 400);
        }

        $pdo->prepare('DELETE FROM wooden_categories WHERE id = ?')->execute([$id]);
        jsonResponse(['success' => true, 'message' => 'Wooden category deleted']);
    }

    jsonResponse(['success' => false, 'message' => 'Categories endpoint not found'], 404);
}
