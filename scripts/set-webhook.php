
<?php

require_once dirname(__DIR__) . '/config/config.php';
require_once dirname(__DIR__) . '/src/Telegram.php';

$url = envValue('WEBHOOK_URL');

if (!$url || !filter_var($url, FILTER_VALIDATE_URL)) {
    die("Invalid WEBHOOK_URL\n");
}

if (PHP_SAPI !== 'cli') {
    die("Run this script from the command line only.\n");
}

$telegram = new Telegram(BOT_TOKEN);

$result = $telegram->request('setWebhook', [
    'url' => $url,
    'secret_token' => WEBHOOK_SECRET,
    'allowed_updates' => ['message'],
    'drop_pending_updates' => false
]);

echo "Webhook successfully configured!\n";
var_dump($result);
