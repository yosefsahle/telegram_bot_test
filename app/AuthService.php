<?php
declare(strict_types=1);
require_once __DIR__.'/TelegramInitData.php';
final class AuthService {
    public static function login(string $rawInitData): array {
        $botToken = (string)env_value('TELEGRAM_BOT_TOKEN');
        if ($botToken === '') throw new RuntimeException('Server Telegram bot token is not configured.');
        $verified = TelegramInitData::validate($rawInitData, $botToken, (int)env_value('TELEGRAM_INITDATA_MAX_AGE', '300'));
        $u = $verified['user']; $telegramId = (string)$u['id'];
        $pdo = db(); $pdo->beginTransaction();
        try {
            // The legacy registration table is read-only here. No existing registration data is changed.
            $legacy = null;
            try {
                $q = $pdo->prepare('SELECT id, phone_number FROM users WHERE user_id = ? LIMIT 1');
                $q->execute([$telegramId]); $legacy = $q->fetch() ?: null;
            } catch (PDOException $e) {
                // A differently named legacy table must be mapped after inspecting the original bot source.
                if (env_value('LEGACY_USERS_TABLE','users') === 'users') throw $e;
            }
            $language = strtolower(substr((string)($u['language_code'] ?? 'en'),0,2));
            $language = in_array($language,['en','am','ti','om'],true) ? $language : 'en';
            $find = $pdo->prepare('SELECT id FROM lottery_participants WHERE telegram_user_id = ? FOR UPDATE');
            $find->execute([$telegramId]); $participantId = $find->fetchColumn();
            if ($participantId) {
                $up = $pdo->prepare('UPDATE lottery_participants SET legacy_registration_user_id=?, username=?, first_name=?, last_name=?, phone_number=COALESCE(?,phone_number), last_seen_at=UTC_TIMESTAMP() WHERE id=?');
                $up->execute([$legacy['id'] ?? null, $u['username'] ?? null, $u['first_name'] ?? 'Telegram user', $u['last_name'] ?? null, $legacy['phone_number'] ?? null, $participantId]);
            } else {
                $ins = $pdo->prepare('INSERT INTO lottery_participants (legacy_registration_user_id,telegram_user_id,username,first_name,last_name,phone_number,language_code,last_seen_at) VALUES (?,?,?,?,?,?,?,UTC_TIMESTAMP())');
                $ins->execute([$legacy['id'] ?? null,$telegramId,$u['username'] ?? null,$u['first_name'] ?? 'Telegram user',$u['last_name'] ?? null,$legacy['phone_number'] ?? null,$language]);
                $participantId = (int)$pdo->lastInsertId();
            }
            $token = bin2hex(random_bytes(32)); $tokenHash = hash('sha256',$token);
            $expiry = gmdate('Y-m-d H:i:s', time() + ((int)env_value('API_SESSION_TTL', '2592000')));
            $ipHash = isset($_SERVER['REMOTE_ADDR']) ? hash('sha256', $_SERVER['REMOTE_ADDR']) : null;
            $ua = substr((string)($_SERVER['HTTP_USER_AGENT'] ?? ''),0,255);
            $s = $pdo->prepare('INSERT INTO lottery_api_sessions (participant_id,token_hash,expires_at,ip_hash,user_agent) VALUES (?,?,?,?,?)');
            $s->execute([$participantId,$tokenHash,$expiry,$ipHash,$ua]);
            $pdo->commit();
            return ['access_token'=>$token,'token_type'=>'Bearer','expires_at'=>$expiry,'participant_id'=>(int)$participantId];
        } catch (Throwable $e) { if ($pdo->inTransaction()) $pdo->rollBack(); throw $e; }
    }
    public static function currentParticipant(): array {
        $header = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
        if (!preg_match('/^Bearer\s+([a-f0-9]{64})$/i',$header,$m)) json_response(401,['error'=>'unauthorized','message'=>'Bearer token required.']);
        $hash = hash('sha256',$m[1]);
        $q = db()->prepare('SELECT p.id,p.telegram_user_id,p.username,p.first_name,p.last_name,p.phone_number,p.language_code,p.status,s.id AS session_id FROM lottery_api_sessions s JOIN lottery_participants p ON p.id=s.participant_id WHERE s.token_hash=? AND s.revoked_at IS NULL AND s.expires_at>UTC_TIMESTAMP() LIMIT 1');
        $q->execute([$hash]); $row = $q->fetch();
        if (!$row || $row['status'] !== 'active') json_response(401,['error'=>'unauthorized','message'=>'Session expired or account unavailable.']);
        db()->prepare('UPDATE lottery_api_sessions SET last_used_at=UTC_TIMESTAMP() WHERE id=?')->execute([$row['session_id']]);
        unset($row['session_id']); return $row;
    }
}
