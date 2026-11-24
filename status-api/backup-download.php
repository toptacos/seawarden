<?php
/**
 * SeaWarden download API — gated artifact download.
 * Set SEAWARDEN_DOWNLOAD_TOKEN in the PHP-FPM environment.
 */
declare(strict_types=1);

header('X-Content-Type-Options: nosniff');

$tokenExpected = getenv('SEAWARDEN_DOWNLOAD_TOKEN') ?: '';
$tokenGiven = (string)($_GET['token'] ?? ($_SERVER['HTTP_X_SEAWARDEN_TOKEN'] ?? ''));
if ($tokenExpected === '' || !hash_equals($tokenExpected, $tokenGiven)) {
    http_response_code(401);
    header('Content-Type: application/json');
    echo json_encode(['ok' => false, 'error' => 'unauthorized']);
    exit;
}

$allowedEnvs = ['production', 'staging', 'development'];
$env = preg_replace('/[^a-z]/', '', (string)($_GET['env'] ?? ''));
$file = basename((string)($_GET['file'] ?? ''));
if (!in_array($env, $allowedEnvs, true) || $file === '' || !preg_match('/^db_\d{8}_\d{6}\.sql\.gz(\.gpg)?$/', $file)) {
    http_response_code(400);
    header('Content-Type: application/json');
    echo json_encode(['ok' => false, 'error' => 'invalid_request']);
    exit;
}

$root = getenv('SEAWARDEN_ROOT') ?: '/mnt/seawarden_backups';
$path = rtrim($root, '/') . '/backups/' . $env . '/' . $file;
if (!is_readable($path)) {
    http_response_code(404);
    header('Content-Type: application/json');
    echo json_encode(['ok' => false, 'error' => 'not_found']);
    exit;
}

header('Content-Type: application/octet-stream');
header('Content-Disposition: attachment; filename="' . $file . '"');
header('Content-Length: ' . (string)filesize($path));
readfile($path);
