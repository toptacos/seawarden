<?php
/**
 * SeaWarden status API — serve vault status JSON over HTTPS.
 * Point nginx at this directory. No SSH keys here.
 */
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('X-Content-Type-Options: nosniff');

$allowed = ['production', 'staging', 'development'];
$env = preg_replace('/[^a-z]/', '', (string)($_GET['env'] ?? ''));
if (!in_array($env, $allowed, true)) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'invalid_env']);
    exit;
}

$root = getenv('SEAWARDEN_STATUS_DIR') ?: '/mnt/seawarden_backups/status';
$path = rtrim($root, '/') . '/' . $env . '.json';

if (!is_readable($path)) {
    http_response_code(404);
    echo json_encode(['ok' => false, 'error' => 'not_found', 'env' => $env]);
    exit;
}

readfile($path);
