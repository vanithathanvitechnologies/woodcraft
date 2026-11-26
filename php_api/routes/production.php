<?php
require_once __DIR__ . '/../helpers/notifications.php';

// STRICT PRIVACY-PROTECTED COLUMNS ONLY — ZERO Customer Name, Mobile, Address, or Pricing!
const RESTRICTED_JOB_COLS = '
  o.id, o.job_id, o.woodwork_category, o.width_inches, o.height_inches,
  o.frame_section, o.door_thickness, o.leaf_type, o.wood_species,
  o.carving_pattern, o.polish_shade, o.hardware, o.quantity,
  o.workshop_notes, o.reference_design_ids, o.reference_elements,
  o.ai_output_image_url, o.expected_delivery_date, o.priority,
  o.current_stage, o.current_stage_name, o.has_blocker, o.blocker_note,
  o.production_place, o.assigned_production_user_id,
  pu.name AS assigned_production_user_name,
  o.created_at, o.updated_at
';

function enrichRestrictedJobPhp(PDO $pdo, array $job): array {
    $refIds = parseJsonField($job['reference_design_ids'] ?? null, []);
    $refDesigns = [];
    if (count($refIds) > 0) {
        $placeholders = implode(',', array_fill(0, count($refIds), '?'));
        // base_price intentionally excluded for workshop privacy
        $stmt = $pdo->prepare("SELECT id, title, category, carving_style, wood_species, image_url FROM design_catalog WHERE id IN ($placeholders)");
        $stmt->execute($refIds);
        $refDesigns = $stmt->fetchAll();
    }

    $hStmt = $pdo->prepare(
        'SELECT h.id, h.stage_number, h.stage_name, h.notes, h.is_blocker, h.created_at, u.name AS updated_by_name
         FROM order_stage_history h
         LEFT JOIN users u ON u.id = h.updated_by
         WHERE h.order_id = ?
         ORDER BY h.created_at ASC'
    );
    $hStmt->execute([$job['id']]);

    $pStmt = $pdo->prepare(
        'SELECT p.id, p.stage_number, p.stage_name, p.photo_url, p.caption, p.created_at, u.name AS uploaded_by_name
         FROM order_progress_photos p
         LEFT JOIN users u ON u.id = p.uploaded_by
         WHERE p.order_id = ?
         ORDER BY p.created_at DESC'
    );
    $pStmt->execute([$job['id']]);

    $job['reference_design_ids'] = $refIds;
    $job['reference_elements'] = parseJsonField($job['reference_elements'] ?? null, []);
    $job['reference_designs'] = $refDesigns;
    $job['stage_history'] = $hStmt->fetchAll();
    $job['progress_photos'] = $pStmt->fetchAll();
    return attachAiStyleGuideMetaPhp($job);
}

function handleProductionRoutes(string $method, array $segments): void {
    $pdo = getDb();

    // GET /api/production/team — Active production members list for order assignment
    if ($method === 'GET' && ($segments[0] ?? '') === 'team') {
        requireRoles(['admin', 'owner', 'sales', 'production']);
        $stmt = $pdo->query("SELECT id, name, phone FROM users WHERE role = 'production' AND is_active = 1 ORDER BY name ASC");
        jsonResponse(['success' => true, 'members' => $stmt->fetchAll()]);
    }

    if (($segments[0] ?? '') !== 'jobs') {
        jsonResponse(['success' => false, 'message' => 'Production endpoint not found'], 404);
    }

    // GET /api/production/jobs
    if ($method === 'GET' && !isset($segments[1])) {
        $authUser = requireRoles(['production', 'owner', 'sales', 'admin']);
        $filter = $_GET['filter'] ?? 'all';
        $search = trim((string)($_GET['search'] ?? ''));

        $sql = 'SELECT ' . RESTRICTED_JOB_COLS . ',
                       DATEDIFF(o.expected_delivery_date, CURDATE()) AS days_left,
                       COALESCE((SELECT MAX(h.created_at) FROM order_stage_history h WHERE h.order_id = o.id), o.updated_at) AS last_progress_at,
                       CASE
                         WHEN o.current_stage = 8 THEN COALESCE(
                           (SELECT MAX(h.created_at) FROM order_stage_history h WHERE h.order_id = o.id AND h.stage_number = 8),
                           o.updated_at
                         )
                         ELSE NULL
                       END AS completed_at
                FROM orders o
                LEFT JOIN users pu ON pu.id = o.assigned_production_user_id
                WHERE o.is_dispatched = 1';
        $params = [];
        if (($authUser['role'] ?? '') === 'production') {
            $sql .= ' AND (o.assigned_production_user_id = ? OR o.assigned_production_user_id IS NULL)';
            $params[] = (int)$authUser['id'];
        }
        if ($filter === 'new') $sql .= ' AND o.current_stage = 1';
        elseif ($filter === 'in_progress') $sql .= ' AND o.current_stage > 1 AND o.current_stage < 8';
        elseif ($filter === 'completed') $sql .= ' AND o.current_stage = 8';

        if ($search !== '') {
            $sql .= ' AND (o.job_id LIKE ? OR o.woodwork_category LIKE ? OR o.wood_species LIKE ? OR o.carving_pattern LIKE ? OR o.production_place LIKE ?)';
            $like = "%$search%";
            array_push($params, $like, $like, $like, $like, $like);
        }

        $sql .= ' ORDER BY FIELD(o.priority, "Urgent", "High", "Normal"), o.expected_delivery_date ASC';
        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);
        $rows = $stmt->fetchAll();
        $today = date('Y-m-d');
        foreach ($rows as &$r) {
            $r['reference_design_ids'] = parseJsonField($r['reference_design_ids'] ?? null, []);
            $r['reference_elements'] = parseJsonField($r['reference_elements'] ?? null, []);
            $stageNum = (int)$r['current_stage'];
            $daysLeft = (int)($r['days_left'] ?? 0);
            $r['is_delivery_reached'] = ($stageNum < 8 && $r['expected_delivery_date'] <= $today);
            $r['is_due_soon'] = ($stageNum < 8 && $r['expected_delivery_date'] > $today && $daysLeft <= 2);
        }
        jsonResponse(['success' => true, 'stages' => PRODUCTION_STAGES, 'jobs' => $rows]);
    }

    // GET /api/production/jobs/by-job-id/:jobId
    if ($method === 'GET' && ($segments[1] ?? '') === 'by-job-id' && !empty($segments[2])) {
        requireRoles(['production', 'owner', 'sales', 'admin']);
        $stmt = $pdo->prepare('SELECT ' . RESTRICTED_JOB_COLS . ' FROM orders o LEFT JOIN users pu ON pu.id = o.assigned_production_user_id WHERE o.job_id = ? LIMIT 1');
        $stmt->execute([trim($segments[2])]);
        $job = $stmt->fetch();
        if (!$job) jsonResponse(['success' => false, 'message' => 'Job ID not found'], 404);
        jsonResponse(['success' => true, 'job' => enrichRestrictedJobPhp($pdo, $job)]);
    }

    $id = isset($segments[1]) && is_numeric($segments[1]) ? (int)$segments[1] : null;

    // GET /api/production/jobs/:id
    if ($method === 'GET' && $id !== null && !isset($segments[2])) {
        requireRoles(['production', 'owner', 'sales', 'admin']);
        $stmt = $pdo->prepare('SELECT ' . RESTRICTED_JOB_COLS . ' FROM orders o LEFT JOIN users pu ON pu.id = o.assigned_production_user_id WHERE o.id = ? LIMIT 1');
        $stmt->execute([$id]);
        $job = $stmt->fetch();
        if (!$job) jsonResponse(['success' => false, 'message' => 'Job not found'], 404);
        jsonResponse(['success' => true, 'job' => enrichRestrictedJobPhp($pdo, $job), 'stages' => PRODUCTION_STAGES]);
    }

    // PATCH /api/production/jobs/:id/assign
    if (($method === 'PATCH' || $method === 'POST') && $id !== null && ($segments[2] ?? '') === 'assign') {
        requireRoles(['owner', 'admin', 'sales']);
        $body = getJsonBody();
        $fields = [];
        $params = [];
        $assignedUpdated = false;
        if (array_key_exists('assigned_production_user_id', $body)) {
            $fields[] = 'assigned_production_user_id = ?';
            $params[] = !empty($body['assigned_production_user_id']) ? (int)$body['assigned_production_user_id'] : null;
            $assignedUpdated = true;
        }
        if (array_key_exists('production_place', $body)) {
            $place = trim((string)($body['production_place'] ?? ''));
            $fields[] = 'production_place = ?';
            $params[] = $place !== '' ? $place : null;
        }
        if (!$fields) jsonResponse(['success' => false, 'message' => 'Nothing to update'], 400);

        $params[] = $id;
        $pdo->prepare('UPDATE orders SET ' . implode(', ', $fields) . ' WHERE id = ?')->execute($params);

        $stmt = $pdo->prepare('SELECT ' . RESTRICTED_JOB_COLS . ' FROM orders o LEFT JOIN users pu ON pu.id = o.assigned_production_user_id WHERE o.id = ?');
        $stmt->execute([$id]);
        $job = $stmt->fetch();
        if (!$job) jsonResponse(['success' => false, 'message' => 'Job not found'], 404);

        if ($assignedUpdated) {
            notifyOrderAssignedPhp($pdo, $job);
        }
        syncDeliveryNotificationsPhp($pdo);
        jsonResponse(['success' => true, 'message' => 'Production assignment saved', 'job' => enrichRestrictedJobPhp($pdo, $job)]);
    }

    // PATCH /api/production/jobs/:id/stage
    if (($method === 'PATCH' || $method === 'POST') && $id !== null && ($segments[2] ?? '') === 'stage') {
        $authUser = requireRoles(['production', 'admin']);
        $body = getJsonBody();
        $stageNum = (int)($body['stage_number'] ?? 0);
        $notes = (string)($body['notes'] ?? '');
        $clearBlocker = !array_key_exists('clear_blocker', $body) || $body['clear_blocker'] !== false;

        if ($stageNum < 1 || $stageNum > 8) {
            jsonResponse(['success' => false, 'message' => 'Valid stage_number (1 to 8) is required'], 400);
        }

        $stageName = getStageName($stageNum);
        $pdo->prepare(
            'UPDATE orders
             SET current_stage = ?,
                 current_stage_name = ?,
                 assigned_production_user_id = COALESCE(assigned_production_user_id, ?),
                 has_blocker = CASE WHEN ? THEN 0 ELSE has_blocker END,
                 blocker_note = CASE WHEN ? THEN NULL ELSE blocker_note END
             WHERE id = ?'
        )->execute([$stageNum, $stageName, $authUser['id'], $clearBlocker ? 1 : 0, $clearBlocker ? 1 : 0, $id]);

        $pdo->prepare(
            'INSERT INTO order_stage_history (order_id, stage_number, stage_name, updated_by, notes, is_blocker) VALUES (?, ?, ?, ?, ?, 0)'
        )->execute([$id, $stageNum, $stageName, $authUser['id'], $notes ?: "Moved to $stageName"]);

        syncDeliveryNotificationsPhp($pdo);

        $stmt = $pdo->prepare('SELECT ' . RESTRICTED_JOB_COLS . ' FROM orders o LEFT JOIN users pu ON pu.id = o.assigned_production_user_id WHERE o.id = ?');
        $stmt->execute([$id]);
        jsonResponse(['success' => true, 'job' => enrichRestrictedJobPhp($pdo, $stmt->fetch())]);
    }

    // POST /api/production/jobs/:id/blocker
    if ($method === 'POST' && $id !== null && ($segments[2] ?? '') === 'blocker') {
        $authUser = requireRoles(['production', 'admin']);
        $body = getJsonBody();
        $resolved = !empty($body['resolved']);
        $note = trim((string)($body['blocker_note'] ?? ''));

        $ex = $pdo->prepare('SELECT current_stage, current_stage_name FROM orders WHERE id = ?');
        $ex->execute([$id]);
        $row = $ex->fetch();
        if (!$row) jsonResponse(['success' => false, 'message' => 'Job not found'], 404);

        if ($resolved) {
            $pdo->prepare('UPDATE orders SET has_blocker = 0, blocker_note = NULL WHERE id = ?')->execute([$id]);
            $pdo->prepare('INSERT INTO order_stage_history (order_id, stage_number, stage_name, updated_by, notes, is_blocker) VALUES (?, ?, ?, ?, ?, 0)')
                ->execute([$id, $row['current_stage'], $row['current_stage_name'], $authUser['id'], 'Blocker resolved by workshop']);
        } else {
            if (!$note) jsonResponse(['success' => false, 'message' => 'Please describe the workshop issue/blocker'], 400);
            $pdo->prepare('UPDATE orders SET has_blocker = 1, blocker_note = ? WHERE id = ?')->execute([$note, $id]);
            $pdo->prepare('INSERT INTO order_stage_history (order_id, stage_number, stage_name, updated_by, notes, is_blocker) VALUES (?, ?, ?, ?, ?, 1)')
                ->execute([$id, $row['current_stage'], $row['current_stage_name'], $authUser['id'], "HOLD / BLOCKER: $note"]);
        }

        $stmt = $pdo->prepare('SELECT ' . RESTRICTED_JOB_COLS . ' FROM orders o WHERE o.id = ?');
        $stmt->execute([$id]);
        jsonResponse(['success' => true, 'job' => enrichRestrictedJobPhp($pdo, $stmt->fetch())]);
    }

    // POST /api/production/jobs/:id/photos
    if ($method === 'POST' && $id !== null && ($segments[2] ?? '') === 'photos') {
        $authUser = requireRoles(['production', 'admin']);
        if (empty($_FILES['photo']) || $_FILES['photo']['error'] !== UPLOAD_ERR_OK) {
            jsonResponse(['success' => false, 'message' => 'Photo file is required'], 400);
        }

        $ex = $pdo->prepare('SELECT current_stage, current_stage_name FROM orders WHERE id = ?');
        $ex->execute([$id]);
        $row = $ex->fetch();
        if (!$row) jsonResponse(['success' => false, 'message' => 'Job not found'], 404);

        $targetDir = __DIR__ . '/../uploads/progress';
        if (!is_dir($targetDir)) mkdir($targetDir, 0755, true);

        $ext = pathinfo($_FILES['photo']['name'], PATHINFO_EXTENSION) ?: 'jpg';
        $fname = 'progress-' . time() . '-' . random_int(1000, 9999) . '.' . $ext;
        move_uploaded_file($_FILES['photo']['tmp_name'], "$targetDir/$fname");
        $photoUrl = "/uploads/progress/$fname";

        $stageNum = !empty($_POST['stage_number']) ? (int)$_POST['stage_number'] : (int)$row['current_stage'];
        $stageName = getStageName($stageNum);
        $caption = $_POST['caption'] ?? "Progress photo at $stageName";

        $ins = $pdo->prepare('INSERT INTO order_progress_photos (order_id, stage_number, stage_name, photo_url, caption, uploaded_by) VALUES (?, ?, ?, ?, ?, ?)');
        $ins->execute([$id, $stageNum, $stageName, $photoUrl, $caption, $authUser['id']]);

        $get = $pdo->prepare('SELECT * FROM order_progress_photos WHERE id = ?');
        $get->execute([(int)$pdo->lastInsertId()]);
        jsonResponse(['success' => true, 'photo' => $get->fetch()], 201);
    }

    jsonResponse(['success' => false, 'message' => 'Production endpoint not found'], 404);
}
