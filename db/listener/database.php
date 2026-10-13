<?php
// Reads connection settings from config/db.ini, which db/setup.sh creates.
$cfg = parse_ini_file(__DIR__ . '/config/db.ini');
$conn = new mysqli($cfg['host'], $cfg['user'], $cfg['pass'], $cfg['name']);
if ($conn->connect_error) {
        die('DB connection failed: ' . $conn->connect_error);
}