<?php
ini_set('display_errors', '1');
ini_set('display_startup_errors', '1');
error_reporting(E_ALL);
header('Content-Type: text/plain; charset=utf-8');

echo "PHP Version: " . PHP_VERSION . "\n";
echo "PDO MySQL loaded: " . (extension_loaded('pdo_mysql') ? 'YES' : 'NO') . "\n";
echo "GD loaded: " . (extension_loaded('gd') ? 'YES' : 'NO') . "\n";
echo "config.php exists: " . (file_exists(__DIR__ . '/config.php') ? 'YES' : 'NO') . "\n";

if (file_exists(__DIR__ . '/config.php')) {
    echo "Loading config.php...\n";
    require_once __DIR__ . '/config.php';
    echo "DB_HOST: " . DB_HOST . " | DB_NAME: " . DB_NAME . " | DB_USER: " . DB_USER . "\n";

    try {
        $dsn = 'mysql:host=' . DB_HOST . ';port=' . DB_PORT . ';dbname=' . DB_NAME . ';charset=utf8mb4';
        $pdo = new PDO($dsn, DB_USER, DB_PASS, array(PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION));
        echo "MySQL Connected: YES\n";
        $cnt = $pdo->query('SELECT COUNT(*) FROM users')->fetchColumn();
        echo "Users table count: " . $cnt . "\n";
    } catch (Exception $e) {
        echo "MySQL Error: " . $e->getMessage() . "\n";
    }
}
