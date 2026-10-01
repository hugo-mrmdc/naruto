<?php

declare(strict_types=1);

require __DIR__ . '/../../src/Config.php';
require __DIR__ . '/../../src/Database.php';
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
    [$ok, $message] = DashboardAuth::attempt((string) ($_POST['username'] ?? ''), (string) ($_POST['password'] ?? ''));
    if ($ok) {
        header('Location: ' . $redirect);
        exit;
    }
    sleep(1); // ralentit un peu le bruteforce, sans dépendance externe
    $error = $message;
}
?>
<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Connexion — Naruto RP</title>
<link rel="stylesheet" href="style.css?v=<?= (int) @filemtime(__DIR__ . '/style.css') ?>">
</head>
<body>
<div class="auth-wrap">
    <div class="card auth-card">
        <div class="logo"></div>
        <h1 class="page-title">Connexion</h1>
        <?php if ($error): ?>
            <p class="msg-error"><?= h($error) ?></p>
        <?php endif; ?>
        <form method="post">
            <input type="hidden" name="redirect" value="<?= h($redirect) ?>">
            <label class="field">
                <span>Nom d'utilisateur</span>
                <input type="text" name="username" autofocus required>
            </label>
            <label class="field">
                <span>Mot de passe</span>
                <input type="password" name="password" required>
            </label>
            <button type="submit" class="btn">Se connecter</button>
        </form>
        <p class="auth-foot">Pas de compte ? <a href="register.php">En créer un</a></p>
    </div>
</div>
</body>
</html>
