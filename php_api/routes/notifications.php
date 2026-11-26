<?php
require_once __DIR__ . '/../helpers/notifications.php';

function handleNotificationsRoutes(string $method, array $segments): void {
    $authUser = requireRoles(['admin', 'owner', 'sales', 'production']);
    $pdo = getDb();
    $userId = (int)$authUser['id'];
    $role = (string)($authUser['role'] ?? '');

    // GET /api/notifications
    if ($method === 'GET' && !isset($segments[0])) {
        syncDeliveryNotificationsPhp($pdo);

        $isProduction = ($role === 'production');
        $custCol = $isProduction ? '' : ', c.name AS customer_name';
        $custJoin = $isProduction ? '' : 'LEFT JOIN customers c ON c.id = o.customer_id';

        $stmt = $pdo->prepare(
            "SELECT n.id, n.order_id, n.type, n.title, n.message, n.notify_for_date, n.is_read, n.created_at,
                    o.job_id, o.woodwork_category, o.wood_species, o.current_stage, o.current_stage_name,
                    o.expected_delivery_date, o.production_place, o.assigned_production_user_id
                    $custCol
             FROM notifications n
             JOIN orders o ON o.id = n.order_id
             $custJoin
             WHERE n.user_id = ?
             ORDER BY n.is_read ASC, n.created_at DESC
             LIMIT 60"
        );
        $stmt->execute([$userId]);
        $rows = $stmt->fetchAll();

        $unreadStmt = $pdo->prepare('SELECT COUNT(*) FROM notifications WHERE user_id = ? AND is_read = 0');
        $unreadStmt->execute([$userId]);
        $unreadCount = (int)$unreadStmt->fetchColumn();

        // Incomplete orders to watch for local 2-day-prior device alarm scheduling
        $watchOrders = [];
        if (in_array($role, ['owner', 'admin', 'production'], true)) {
            $wSql = 'SELECT o.id, o.job_id, o.woodwork_category, o.wood_species, o.expected_delivery_date,
                            o.current_stage, o.current_stage_name, o.production_place, o.assigned_production_user_id,
                            DATEDIFF(o.expected_delivery_date, CURDATE()) AS days_left'
                . ($isProduction ? '' : ', c.name AS customer_name')
                . ' FROM orders o '
                . ($isProduction ? '' : 'JOIN customers c ON c.id = o.customer_id ')
                . ' WHERE o.is_dispatched = 1 AND o.current_stage < 8';
            $wParams = [];
            if ($isProduction) {
                $wSql .= ' AND (o.assigned_production_user_id = ? OR o.assigned_production_user_id IS NULL)';
                $wParams[] = $userId;
            }
            $wSql .= ' ORDER BY o.expected_delivery_date ASC LIMIT 100';
            $wStmt = $pdo->prepare($wSql);
            $wStmt->execute($wParams);
            $watchOrders = $wStmt->fetchAll();
        }

        jsonResponse([
            'success' => true,
            'unread_count' => $unreadCount,
            'notifications' => $rows,
            'scheduled_watch_orders' => $watchOrders,
        ]);
    }

    // POST /api/notifications/read-all
    if (($method === 'POST' || $method === 'PATCH') && ($segments[0] ?? '') === 'read-all') {
        $pdo->prepare('UPDATE notifications SET is_read = 1 WHERE user_id = ?')->execute([$userId]);
        jsonResponse(['success' => true, 'message' => 'All notifications marked as read']);
    }

    $id = isset($segments[0]) && is_numeric($segments[0]) ? (int)$segments[0] : null;

    // PATCH or POST /api/notifications/:id/read
    if (($method === 'PATCH' || $method === 'POST') && $id !== null && ($segments[1] ?? '') === 'read') {
        $pdo->prepare('UPDATE notifications SET is_read = 1 WHERE id = ? AND user_id = ?')->execute([$id, $userId]);
        jsonResponse(['success' => true, 'message' => 'Notification marked as read']);
    }

    jsonResponse(['success' => false, 'message' => 'Notifications endpoint not found'], 404);
}
