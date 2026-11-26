<?php

function syncDeliveryNotificationsPhp(PDO $pdo): void {
    ensureAppSchemaPhp($pdo);

    // Mark pre-delivery / due-reached notifications read once order reaches Stage 8 (Completed)
    $pdo->exec(
        "UPDATE notifications n
         JOIN orders o ON o.id = n.order_id
         SET n.is_read = 1
         WHERE o.current_stage >= 8
           AND n.is_read = 0
           AND n.type IN ('pre_delivery_2d', 'delivery_reached')"
    );

    $ordersStmt = $pdo->query(
        'SELECT o.id, o.job_id, o.woodwork_category, o.wood_species, o.expected_delivery_date,
                o.current_stage, o.current_stage_name, o.assigned_production_user_id, o.production_place,
                o.is_dispatched,
                c.name AS customer_name,
                pu.name AS assigned_production_user_name,
                DATEDIFF(o.expected_delivery_date, CURDATE()) AS days_left
         FROM orders o
         JOIN customers c ON c.id = o.customer_id
         LEFT JOIN users pu ON pu.id = o.assigned_production_user_id
         WHERE o.current_stage < 8
           AND DATEDIFF(o.expected_delivery_date, CURDATE()) <= 2'
    );
    $dueOrders = $ordersStmt->fetchAll();
    if (!$dueOrders) {
        return;
    }

    $owners = $pdo->query("SELECT id FROM users WHERE role IN ('owner', 'admin') AND is_active = 1")->fetchAll(PDO::FETCH_COLUMN);
    $prodUsers = $pdo->query("SELECT id FROM users WHERE role = 'production' AND is_active = 1")->fetchAll(PDO::FETCH_COLUMN);
    $activeProdSet = array_flip(array_map('intval', $prodUsers));

    $ins = $pdo->prepare(
        'INSERT IGNORE INTO notifications (user_id, order_id, type, title, message, notify_for_date)
         VALUES (?, ?, ?, ?, ?, ?)'
    );

    foreach ($dueOrders as $o) {
        $orderId = (int)$o['id'];
        $daysLeft = (int)$o['days_left'];
        $deliveryDate = (string)$o['expected_delivery_date'];
        $place = trim((string)($o['production_place'] ?? ''));
        $assignedName = trim((string)($o['assigned_production_user_name'] ?? ''));

        $placeSuffix = $place !== '' ? " • Place: $place" : '';
        $assignedSuffix = $assignedName !== '' ? " • Assigned: $assignedName" : '';

        if ($daysLeft > 0) {
            $type = 'pre_delivery_2d';
            $dayPhrase = $daysLeft === 1 ? 'tomorrow' : "in $daysLeft days";
            $ownerTitle = "Delivery $dayPhrase: {$o['job_id']}";
            $ownerMsg = "{$o['customer_name']} • {$o['woodwork_category']} ({$o['wood_species']}) is not completed (Stage {$o['current_stage']}/8: {$o['current_stage_name']}). Delivery: $deliveryDate{$assignedSuffix}{$placeSuffix}";
            $prodTitle = "Reminder ($dayPhrase): Job {$o['job_id']}";
            $prodMsg = "{$o['woodwork_category']} ({$o['wood_species']}) is at Stage {$o['current_stage']}/8 ({$o['current_stage_name']}). Target Delivery: $deliveryDate{$placeSuffix}";
        } else {
            $type = 'delivery_reached';
            $overduePhrase = $daysLeft === 0 ? 'Delivery date reached today' : ('Overdue by ' . abs($daysLeft) . ' day(s)');
            $ownerTitle = "$overduePhrase (Incomplete): {$o['job_id']}";
            $ownerMsg = "{$o['customer_name']} • {$o['woodwork_category']} is still at Stage {$o['current_stage']}/8 ({$o['current_stage_name']}). Delivery Date: $deliveryDate{$assignedSuffix}{$placeSuffix}";
            $prodTitle = "$overduePhrase: Job {$o['job_id']}";
            $prodMsg = "{$o['woodwork_category']} ({$o['wood_species']}) is NOT completed (Stage {$o['current_stage']}/8: {$o['current_stage_name']}). Target Date: $deliveryDate{$placeSuffix}";
        }

        foreach ($owners as $ownerId) {
            $ins->execute([(int)$ownerId, $orderId, $type, $ownerTitle, $ownerMsg, $deliveryDate]);
        }

        if (!empty($o['is_dispatched'])) {
            $assignedProdId = !empty($o['assigned_production_user_id']) ? (int)$o['assigned_production_user_id'] : null;
            if ($assignedProdId !== null && isset($activeProdSet[$assignedProdId])) {
                $ins->execute([$assignedProdId, $orderId, $type, $prodTitle, $prodMsg, $deliveryDate]);
            } elseif ($assignedProdId === null) {
                foreach ($prodUsers as $pid) {
                    $ins->execute([(int)$pid, $orderId, $type, $prodTitle, $prodMsg, $deliveryDate]);
                }
            }
        }
    }
}

function notifyOrderAssignedPhp(PDO $pdo, array $order): void {
    ensureAppSchemaPhp($pdo);
    $prodId = !empty($order['assigned_production_user_id']) ? (int)$order['assigned_production_user_id'] : 0;
    if ($prodId <= 0) return;

    $place = trim((string)($order['production_place'] ?? ''));
    $placeSuffix = $place !== '' ? " • Place: $place" : '';
    $title = "New Job Assigned: {$order['job_id']}";
    $msg = "{$order['woodwork_category']} ({$order['wood_species']}) • Target Delivery: {$order['expected_delivery_date']}{$placeSuffix}";

    $ins = $pdo->prepare(
        'INSERT IGNORE INTO notifications (user_id, order_id, type, title, message, notify_for_date)
         VALUES (?, ?, ?, ?, ?, ?)'
    );
    $ins->execute([$prodId, (int)$order['id'], 'order_assigned', $title, $msg, (string)$order['expected_delivery_date']]);
}
