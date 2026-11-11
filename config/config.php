
<?php

function loadEnv($path)
{
    if (!file_exists($path)) {
        throw new RuntimeException(".env file not found");
    }

    $lines = file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);

    foreach ($lines as $line) {
        $line = trim($line);

        if ($line === '' || str_starts_with($line, '#')) {
            continue;
        }

        [$key, $value] = array_pad(explode('=', $line, 2), 2, '');

        $_ENV[trim($key)] = trim($value);
    }
}

loadEnv(dirname(__DIR__) . '/.env');

function envValue($key, $default = null)
{
    return $_ENV[$key] ?? $default;
}

define('BOT_TOKEN', envValue('BOT_TOKEN'));
define('DB_HOST', envValue('DB_HOST', 'localhost'));
define('DB_NAME', envValue('DB_NAME'));
define('DB_USER', envValue('DB_USER'));
define('DB_PASS', envValue('DB_PASS', ''));

define('WEBHOOK_SECRET', envValue('WEBHOOK_SECRET'));

if (!BOT_TOKEN || !DB_NAME || !DB_USER || !WEBHOOK_SECRET) {
    throw new RuntimeException('Missing required configuration');
}
