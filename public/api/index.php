<?php
declare(strict_types=1);
require_once dirname(__DIR__,2).'/app/bootstrap.php';
require_once dirname(__DIR__,2).'/app/AuthService.php';
allowed_origin();
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
$path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH);
$path = preg_replace('#^.*/api/v1#','',$path);
try {
    if ($method === 'GET' && $path === '/health') json_response(200,['ok'=>true,'service'=>'lottery-api','version'=>'1.0.0']);
    if ($method === 'POST' && $path === '/auth/telegram') {
        $body = request_json(); $result = AuthService::login((string)($body['initData'] ?? ''));
        json_response(200,['ok'=>true,'data'=>$result]);
    }
    if ($method === 'GET' && $path === '/me') json_response(200,['ok'=>true,'data'=>AuthService::currentParticipant()]);
    if ($method === 'PATCH' && $path === '/me') {
        $participant = AuthService::currentParticipant(); $body = request_json();
        $language = strtolower((string)($body['language_code'] ?? ''));
        if (!in_array($language,['en','am','ti','om'],true)) json_response(422,['error'=>'validation_error','message'=>'language_code must be en, am, ti, or om.']);
        db()->prepare('UPDATE lottery_participants SET language_code=? WHERE id=?')->execute([$language,$participant['id']]);
        json_response(200,['ok'=>true,'data'=>['language_code'=>$language]]);
    }
    if ($method === 'POST' && $path === '/auth/logout') {
        $participant = AuthService::currentParticipant();
        $header = $_SERVER['HTTP_AUTHORIZATION'] ?? ''; preg_match('/^Bearer\s+([a-f0-9]{64})$/i',$header,$m);
        db()->prepare('UPDATE lottery_api_sessions SET revoked_at=UTC_TIMESTAMP() WHERE token_hash=?')->execute([hash('sha256',$m[1])]);
        json_response(200,['ok'=>true]);
    }
    json_response(404,['error'=>'not_found','message'=>'Endpoint not found.']);
} catch (RuntimeException $e) { json_response(401,['error'=>'authentication_failed','message'=>$e->getMessage()]); }
  catch (Throwable $e) { error_log('[lottery-api] '.$e->getMessage()); json_response(500,['error'=>'server_error','message'=>'An internal error occurred.']); }
