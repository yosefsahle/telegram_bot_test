<?php
declare(strict_types=1);
final class TelegramInitData {
    public static function validate(string $raw, string $botToken, int $maxAge = 300): array {
        if ($raw === '' || strlen($raw) > 16384) throw new RuntimeException('Missing or oversized Telegram initData.');
        $pairs = []; parse_str($raw, $pairs);
        $receivedHash = strtolower((string)($pairs['hash'] ?? ''));
        if (!preg_match('/^[a-f0-9]{64}$/', $receivedHash)) throw new RuntimeException('Telegram signature is missing.');
        unset($pairs['hash']); // Telegram's bot-token HMAC check excludes hash only; keep signature if present.
        ksort($pairs, SORT_STRING);
        $lines = [];
        foreach ($pairs as $key => $value) {
            if (is_array($value)) throw new RuntimeException('Invalid Telegram initData format.');
            $lines[] = $key.'='.$value;
        }
        $secretKey = hash_hmac('sha256', $botToken, 'WebAppData', true);
        $calculated = hash_hmac('sha256', implode("\n", $lines), $secretKey);
        if (!hash_equals($calculated, $receivedHash)) throw new RuntimeException('Telegram signature validation failed.');
        $authDate = filter_var($pairs['auth_date'] ?? null, FILTER_VALIDATE_INT);
        if (!$authDate || $authDate > time() + 30 || (time() - $authDate) > $maxAge) throw new RuntimeException('Telegram authentication data has expired. Reopen the Mini App from the bot.');
        $user = json_decode((string)($pairs['user'] ?? ''), true);
        if (!is_array($user) || empty($user['id']) || !ctype_digit((string)$user['id'])) throw new RuntimeException('Telegram user data is invalid.');
        return ['user'=>$user, 'auth_date'=>(int)$authDate];
    }
}
