<?php

declare(strict_types=1);

require __DIR__ . '/../../src/Config.php';
require __DIR__ . '/../../src/DashboardAuth.php';

DashboardAuth::logout();
header('Location: login.php');
