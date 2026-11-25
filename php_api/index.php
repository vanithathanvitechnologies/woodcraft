<?php
// CORS Headers for Flutter Apps & React Admin Panel
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Auth-Token, X-Requested-With');
header('Access-Control-Max-Age: 86400');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

register_shutdown_function(function () {
    $err = error_get_last();
    if ($err && in_array($err['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR], true)) {
        http_response_code(500);
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode([
            'success' => false,
            'message' => 'PHP Fatal Error: ' . $err['message'] . ' in ' . basename($err['file']) . ':' . $err['line'],
        ]);
    }
});

require_once __DIR__ . '/config.php';
require_once __DIR__ . '/helpers/db.php';
require_once __DIR__ . '/helpers/constants.php';
require_once __DIR__ . '/helpers/auth.php';
require_once __DIR__ . '/routes/auth.php';
require_once __DIR__ . '/routes/users.php';
require_once __DIR__ . '/routes/categories.php';
require_once __DIR__ . '/routes/catalog.php';
require_once __DIR__ . '/routes/customers.php';
require_once __DIR__ . '/routes/orders.php';
require_once __DIR__ . '/routes/production.php';
require_once __DIR__ . '/routes/customer_portal.php';
require_once __DIR__ . '/routes/reports.php';

try {
    $method = $_SERVER['REQUEST_METHOD'];
    $uriPath = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);

    // Strip the script base directory (works in /php_api/, /wooden/php_api/, or root /)
    $scriptDir = rtrim(str_replace('\\', '/', dirname($_SERVER['SCRIPT_NAME'])), '/');
    if ($scriptDir !== '' && $scriptDir !== '/' && strpos($uriPath, $scriptDir) === 0) {
        $uriPath = substr($uriPath, strlen($scriptDir));
    }

    $uriPath = trim($uriPath, '/');

    // Allow both /api/auth/login and /auth/login
    if (strpos($uriPath, 'api/') === 0) {
        $uriPath = substr($uriPath, 4);
    } elseif ($uriPath === 'api') {
        $uriPath = '';
    }

    $segments = $uriPath === '' ? [] : explode('/', $uriPath);
    $resource = $segments[0] ?? '';
    $rest = array_slice($segments, 1);

    if ($resource === '' || $resource === 'health') {
        jsonResponse([
            'success' => true,
            'service' => 'Wooden Door & Frame Customizer PHP + MySQL API (cPanel Ready)',
            'timestamp' => date('c'),
        ]);
    }

    if ($resource === 'meta') {
        $activeCategories = getActiveWoodenCategoryNames(getDb());
        jsonResponse([
            'success' => true,
            'stages' => PRODUCTION_STAGES,
            'categories' => $activeCategories,
            'wood_species' => WOOD_SPECIES,
            'polish_shades' => POLISH_SHADES,
        ]);
    }

    switch ($resource) {
        case 'auth':
            handleAuthRoutes($method, $rest);
            break;
        case 'users':
            handleUsersRoutes($method, $rest);
            break;
        case 'categories':
            handleCategoriesRoutes($method, $rest);
            break;
        case 'catalog':
            handleCatalogRoutes($method, $rest);
            break;
        case 'customers':
            handleCustomersRoutes($method, $rest);
            break;
        case 'orders':
            handleOrdersRoutes($method, $rest);
            break;
        case 'production':
            handleProductionRoutes($method, $rest);
            break;
        case 'customer':
            handleCustomerPortalRoutes($method, $rest);
            break;
        case 'reports':
            handleReportsRoutes($method, $rest);
            break;
        default:
            jsonResponse(['success' => false, 'message' => "Route not found: /$uriPath"], 404);
    }
} catch (Throwable $e) {
    jsonResponse([
        'success' => false,
        'message' => 'Server Error: ' . $e->getMessage(),
    ], 500);
}
