<?php

const TRACKABLE_PROCESS_STEPS = [
    6 => 'Design Confirmation Date',
    7 => 'Raw Material Collection Date',
    8 => 'Raw Material Received Date',
    9 => 'Seasoning 1st Stage',
    10 => 'Seasoning 2nd Stage',
    11 => 'Seasoning 3rd Stage',
    12 => 'Natural Seasoning 1st Stage',
    13 => 'Natural Seasoning 2nd Stage',
    14 => 'Plaining Process 1st Stage',
    15 => 'Plaining Process 2nd Stage',
    16 => 'Wood on Wheels Loading Date',
    17 => 'Wood on Wheels 1st Stage',
    18 => 'Wood on Wheels 2nd Stage',
    19 => 'Carpenter Process 1st Stage',
    20 => 'Carpenter Process 2nd Stage',
    21 => 'CNC Process 1st Stage',
    22 => 'CNC Process 2nd Stage',
    23 => 'Hand Carving Process 1st Stage',
    24 => 'Hand Carving Process 2nd Stage',
    25 => 'Grill Process 1st Stage',
    26 => 'Grill Process 2nd Stage',
    27 => 'Finishing Process (Emery)',
    28 => 'Finishing Process (Primer)',
    29 => 'Finishing Process (Sealer)',
    30 => 'Finishing Process (Matte)',
    31 => 'Finishing Process (Glossy)',
    32 => 'Finishing Dry Process',
    33 => 'Quality Checking Process',
    34 => 'Loading Date',
    35 => 'Lorry Transport',
    36 => 'Delivery Date in Showroom',
];

function formatProcessShortDatePhp(?string $raw): string {
    $s = trim((string)$raw);
    if ($s === '' || $s === 'null') {
        return '-';
    }
    $ts = strtotime($s);
    if ($ts === false) {
        return $s;
    }
    return date('d.m.y', $ts);
}

function initOrSyncOrderProcessStepsPhp(PDO $pdo, int $orderId, array $orderRow = []): void {
    ensureAppSchemaPhp($pdo);

    if (empty($orderRow['job_id']) || !array_key_exists('customer_name', $orderRow) || !array_key_exists('assigned_production_user_name', $orderRow)) {
        $stmt = $pdo->prepare(
            'SELECT o.id, o.job_id, o.production_place, o.created_at, o.expected_delivery_date,
                    c.name AS customer_name,
                    pu.name AS assigned_production_user_name
             FROM orders o
             JOIN customers c ON c.id = o.customer_id
             LEFT JOIN users pu ON pu.id = o.assigned_production_user_id
             WHERE o.id = ? LIMIT 1'
        );
        $stmt->execute([$orderId]);
        $fetched = $stmt->fetch();
        if (!$fetched) {
            return;
        }
        $orderRow = array_merge($fetched, $orderRow);
    }

    $jobId = trim((string)($orderRow['job_id'] ?? ('Order #' . $orderId)));
    $place = trim((string)($orderRow['production_place'] ?? ''));
    $branchLabel = $place !== '' ? "$jobId ($place)" : $jobId;
    $orderDate = formatProcessShortDatePhp((string)($orderRow['created_at'] ?? date('Y-m-d')));
    $custName = trim((string)($orderRow['customer_name'] ?? 'Customer'));
    $mgrName = trim((string)($orderRow['assigned_production_user_name'] ?? ''));
    if ($mgrName === '') {
        $mgrName = 'Unassigned';
    }
    $deliveryDate = formatProcessShortDatePhp((string)($orderRow['expected_delivery_date'] ?? ''));

    $headerRows = [
        1 => $branchLabel,
        2 => "Order Date - $orderDate",
        3 => "Customer Name - $custName",
        4 => "Production Manager Name - $mgrName",
        5 => "Delivery Date - $deliveryDate",
    ];

    $upsertHeader = $pdo->prepare(
        'INSERT INTO order_process_steps (order_id, s_no, process_name, planning_date, actual_date, is_readonly)
         VALUES (?, ?, ?, NULL, NULL, 1)
         ON DUPLICATE KEY UPDATE process_name = VALUES(process_name), is_readonly = 1'
    );
    foreach ($headerRows as $sNo => $label) {
        $upsertHeader->execute([$orderId, $sNo, $label]);
    }

    $insertStep = $pdo->prepare(
        'INSERT IGNORE INTO order_process_steps (order_id, s_no, process_name, planning_date, actual_date, is_readonly)
         VALUES (?, ?, ?, NULL, NULL, 0)'
    );
    foreach (TRACKABLE_PROCESS_STEPS as $sNo => $label) {
        $insertStep->execute([$orderId, $sNo, $label]);
    }
}

function getOrderProcessStepsPhp(PDO $pdo, int $orderId, bool $maskCustomerForWorkshop = false, array $orderRow = []): array {
    initOrSyncOrderProcessStepsPhp($pdo, $orderId, $orderRow);

    $stmt = $pdo->prepare(
        'SELECT s.id, s.order_id, s.s_no, s.process_name, s.planning_date, s.actual_date,
                s.is_readonly, s.updated_by, s.notes, s.updated_at,
                u.name AS updated_by_name
         FROM order_process_steps s
         LEFT JOIN users u ON u.id = s.updated_by
         WHERE s.order_id = ?
         ORDER BY s.s_no ASC'
    );
    $stmt->execute([$orderId]);
    $rows = $stmt->fetchAll();

    if ($maskCustomerForWorkshop) {
        $jobRef = trim((string)($orderRow['job_id'] ?? ('#' . $orderId)));
        foreach ($rows as &$r) {
            if ((int)$r['s_no'] === 3) {
                $r['process_name'] = "Customer Name - Protected ($jobRef)";
            }
        }
    }

    return $rows;
}

function summarizeProcessProgressPhp(array $steps): array {
    $doneCount = 0;
    $plannedCount = 0;
    $lastDoneName = '';
    $lastDoneSno = 0;
    $isRow36Done = false;

    foreach ($steps as $r) {
        $sNo = (int)($r['s_no'] ?? 0);
        if ($sNo < 6) {
            continue;
        }
        $plan = trim((string)($r['planning_date'] ?? ''));
        $act = trim((string)($r['actual_date'] ?? ''));
        if ($plan !== '' && $plan !== '-') {
            $plannedCount++;
        }
        if ($act !== '' && $act !== '-') {
            $doneCount++;
            if ($sNo >= $lastDoneSno) {
                $lastDoneSno = $sNo;
                $lastDoneName = (string)($r['process_name'] ?? '');
            }
            if ($sNo === 36) {
                $isRow36Done = true;
            }
        }
    }

    $totalTrackable = count(TRACKABLE_PROCESS_STEPS); // 31 steps (6..36)
    if ($isRow36Done) {
        $stageNum = 8;
        $stageName = 'Delivery Date in Showroom';
    } elseif ($doneCount > 0) {
        $stageNum = min(7, max(2, 2 + (int)floor(($doneCount / (float)$totalTrackable) * 5)));
        $stageName = $lastDoneName !== '' ? $lastDoneName : 'In Progress';
    } elseif ($plannedCount > 0) {
        $stageNum = 2;
        $stageName = 'Planning Scheduled';
    } else {
        $stageNum = 1;
        $stageName = 'Pending / New Job';
    }

    return [
        'done_count' => $doneCount,
        'planned_count' => $plannedCount,
        'total_steps' => $totalTrackable,
        'stage_number' => $stageNum,
        'stage_name' => $stageName,
    ];
}

function updateOrderProcessStepPhp(
    PDO $pdo,
    int $orderId,
    int $sNo,
    ?string $planningDate,
    ?string $actualDate,
    int $userId,
    ?string $notes = null,
    bool $updatePlanning = true,
    bool $updateActual = true
): array {
    initOrSyncOrderProcessStepsPhp($pdo, $orderId);

    $ex = $pdo->prepare('SELECT * FROM order_process_steps WHERE order_id = ? AND s_no = ? LIMIT 1');
    $ex->execute([$orderId, $sNo]);
    $row = $ex->fetch();
    if (!$row) {
        throw new InvalidArgumentException("Process row #$sNo not found");
    }

    $newPlan = $updatePlanning ? trim((string)$planningDate) : (string)($row['planning_date'] ?? '');
    $newActual = $updateActual ? trim((string)$actualDate) : (string)($row['actual_date'] ?? '');
    $newNotes = $notes !== null ? trim($notes) : ($row['notes'] ?? null);

    $pdo->prepare(
        'UPDATE order_process_steps
         SET planning_date = ?,
             actual_date = ?,
             updated_by = ?,
             notes = ?
         WHERE order_id = ? AND s_no = ?'
    )->execute([
        $newPlan !== '' ? $newPlan : null,
        $newActual !== '' ? $newActual : null,
        $userId,
        $newNotes !== '' ? $newNotes : null,
        $orderId,
        $sNo,
    ]);

    $allSteps = getOrderProcessStepsPhp($pdo, $orderId, false);
    $summary = summarizeProcessProgressPhp($allSteps);

    $pdo->prepare(
        'UPDATE orders
         SET current_stage = ?,
             current_stage_name = ?,
             assigned_production_user_id = COALESCE(assigned_production_user_id, ?)
         WHERE id = ?'
    )->execute([
        $summary['stage_number'],
        $summary['stage_name'],
        $userId,
        $orderId,
    ]);

    $stepLabel = (string)$row['process_name'];
    $parts = [];
    if ($updatePlanning && $newPlan !== '') {
        $parts[] = "Plan: $newPlan";
    }
    if ($updateActual && $newActual !== '') {
        $parts[] = "Actual: $newActual";
    }
    if ($newNotes) {
        $parts[] = $newNotes;
    }
    $histNote = "Row $sNo ($stepLabel)" . (!empty($parts) ? ' — ' . implode(' • ', $parts) : ' updated');

    $pdo->prepare(
        'INSERT INTO order_stage_history (order_id, stage_number, stage_name, updated_by, notes, is_blocker)
         VALUES (?, ?, ?, ?, ?, 0)'
    )->execute([
        $orderId,
        $summary['stage_number'],
        "$sNo. $stepLabel",
        $userId,
        $histNote,
    ]);

    return $summary;
}
