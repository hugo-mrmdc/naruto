<?php

declare(strict_types=1);

require __DIR__ . '/../../src/Config.php';
require __DIR__ . '/../../src/DashboardAuth.php';

function h(mixed $value): string
{
    return htmlspecialchars((string) ($value ?? ''), ENT_QUOTES, 'UTF-8');
}

DashboardAuth::start();

$redirect = (string) ($_GET['redirect'] ?? $_POST['redirect'] ?? 'index.php');
if ($redirect === '' || str_contains($redirect, '/') || str_contains($redirect, '\\')) {
    $redirect = 'index.php'; // jamais de redirection hors du dossier dashboard
}

if (DashboardAuth::isLoggedIn()) {
    header('Location: ' . $redirect);
    exit;
}

$error = null;
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $password = (string) ($_POST['password'] ?? '');
    if (DashboardAuth::attempt($password)) {
        header('Location: ' . $redirect);
        exit;
    }
    sleep(1); // ralentit un peu le bruteforce, sans dépendance externe
    $error = 'Mot de passe incorrect.';
}
?>
<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Connexion — Naruto RP</title>
<link rel="stylesheet" href="style.css">
</head>
<body>
<main class="container" style="max-width:380px;padding-top:80px">
    <div class="card">
        <h1 class="page-title" style="margin-bottom:18px">Connexion</h1>
        <?php if ($error): ?>
            <p style="color:var(--danger);margin-top:0"><?= h($error) ?></p>
        <?php endif; ?>
        <form method="post">
            <input type="hidden" name="redirect" value="<?= h($redirect) ?>">
            <label style="display:block;margin-bottom:14px">
                <span style="display:block;color:var(--text-dim);font-size:.85rem;margin-bottom:6px">Mot de passe</span>
                <input type="password" name="password" autofocus required
                       style="width:100%;background:var(--panel-light);border:1px solid var(--border);color:var(--text);padding:9px 12px;border-radius:6px">
            </label>
            <button type="submit" style="width:100%;background:var(--accent);color:#1a0f05;border:none;padding:10px;border-radius:6px;font-weight:600;cursor:pointer">
                Se connecter
            </button>
        </form>
    </div>
</main>
</body>
</html>
