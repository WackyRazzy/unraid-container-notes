<?php
$notesDir  = '/boot/config/plugins/container-notes';
$notesFile = $notesDir . '/notes.json';
if (!is_dir($notesDir)) mkdir($notesDir, 0755, true);
header('Content-Type: application/json');
$method = $_SERVER['REQUEST_METHOD'];
if ($method === 'GET') {
    echo file_exists($notesFile) ? file_get_contents($notesFile) : json_encode((object)[]);
    exit;
}
if ($method === 'POST') {
    $body = json_decode(file_get_contents('php://input'), true);
    if (!isset($body['container']) || !isset($body['note'])) {
        http_response_code(400); echo json_encode(['error'=>'bad input']); exit;
    }
    $notes = file_exists($notesFile) ? (json_decode(file_get_contents($notesFile), true) ?: []) : [];
    $note  = trim($body['note']);
    if ($note === '') unset($notes[trim($body['container'])]);
    else $notes[trim($body['container'])] = $note;
    file_put_contents($notesFile, json_encode($notes, JSON_PRETTY_PRINT));
    echo json_encode(['ok' => true]);
    exit;
}
http_response_code(405);
echo json_encode(['error' => 'method not allowed']);