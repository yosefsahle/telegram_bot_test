
<?php

require_once dirname(__DIR__) . '/config/config.php';
require_once dirname(__DIR__) . '/src/Database.php';
require_once dirname(__DIR__) . '/src/Telegram.php';
require_once dirname(__DIR__) . '/src/Registration.php';
require_once dirname(__DIR__) . '/src/Bot.php';

header('Content-Type: application/json');

try {
    // Verify Telegram webhook secret.
    $secret = $_SERVER['HTTP_X_TELEGRAM_BOT_API_SECRET_TOKEN'] ?? '';

    if (
        !is_string($secret) ||
        !hash_equals(WEBHOOK_SECRET, $secret)
    ) {
        http_response_code(403);
        echo json_encode(['ok' => false]);
        exit;
    }

    $input = file_get_contents('php://input');

    $update = json_decode($input, true);

    if (!is_array($update)) {
        http_response_code(400);
        echo json_encode(['ok' => false]);
        exit;
    }

    $db = Database::connect();

    $telegram = new Telegram(BOT_TOKEN);

    $bot = new Bot($db, $telegram);

    $bot->handle($update);

    echo json_encode(['ok' => true]);

} catch (Throwable $e) {

    error_log(
        date('Y-m-d H:i:s') . ' - ' . $e->getMessage() . PHP_EOL,
        3,
        dirname(__DIR__) . '/logs/bot.log'
    );

    http_response_code(500);

    echo json_encode([
        'ok' => false,
        'message' => 'Internal server error'
    ]);
}
