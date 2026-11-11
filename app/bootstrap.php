<?php
declare(strict_types=1);

function env_value(string $key, ?string $default = null): ?string {
    $v = getenv($key); return ($v === false || $v === '') ? $default : $v;
}
function db(): PDO {
    static $pdo = null; if ($pdo instanceof PDO) return $pdo;
    $dsn = 'mysql:host='.env_value('DB_HOST','localhost').';dbname='.env_value('DB_NAME').';charset=utf8mb4';
    $pdo = new PDO($dsn, (string)env_value('DB_USER'), (string)env_value('DB_PASS'), [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false,
    ]);
    return $pdo;
}
function json_response(int $status, array $data): never {
    http_response_code($status); header('Content-Type: application/json; charset=utf-8');
    header('Cache-Control: no-store'); echo json_encode($data, JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES); exit;
}
function request_json(): array {
    $raw = file_get_contents('php://input'); $data = json_decode($raw ?: '', true);
    return is_array($data) ? $data : [];
}
function allowed_origin(): void {
    $origin = $_SERVER['HTTP_ORIGIN'] ?? '';
    $allowed = array_filter(array_map('trim', explode(',', (string)env_value('APP_ALLOWED_ORIGINS',''))));
    if ($origin !== '' && in_array($origin, $allowed, true)) {
        header('Access-Control-Allow-Origin: '.$origin); header('Vary: Origin');
        header('Access-Control-Allow-Headers: Authorization, Content-Type'); header('Access-Control-Allow-Methods: GET, POST, PATCH, OPTIONS');
    }
    if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') { http_response_code(204); exit; }
}
