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

if (DashboardAuth::isLoggedIn()) {
    header('Location: index.php');
    exit;
}

$error = null;
$success = null;
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $username = (string) ($_POST['username'] ?? '');
    $password = (string) ($_POST['password'] ?? '');
    $confirm = (string) ($_POST['password_confirm'] ?? '');

    if ($password !== $confirm) {
        $error = 'Les deux mots de passe ne correspondent pas.';
    } else {
        [$ok, $message] = DashboardAuth::register($username, $password);
        if ($ok) {
            $success = $message;
        } else {
            $error = $message;
        }
    }
}
?>
<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Créer un compte — Naruto RP</title>
<link rel="stylesheet" href="style.css?v=<?= (int) @filemtime(__DIR__ . '/style.css') ?>">
</head>
<body>
<div class="auth-wrap">
    <div class="card auth-card">
        <div class="logo"></div>
        <h1 class="page-title">Créer un compte</h1>
        <?php if ($error): ?>
            <p class="msg-error"><?= h($error) ?></p>
        <?php endif; ?>
        <?php if ($success): ?>
            <p class="msg-success"><?= h($success) ?></p>
            <p class="auth-foot"><a href="login.php">Aller à la connexion</a></p>
        <?php else: ?>
        <form method="post">
            <label class="field">
                <span>Nom d'utilisateur</span>
                <input type="text" name="username" autofocus required minlength="3" maxlength="32" pattern="[a-zA-Z0-9_-]+"
                       value="<?= h($_POST['username'] ?? '') ?>">
            </label>
            <label class="field">
                <span>Mot de passe (8 caractères min.)</span>
                <input type="password" name="password" required minlength="8">
            </label>
            <label class="field">
                <span>Confirme le mot de passe</span>
                <input type="password" name="password_confirm" required minlength="8">
            </label>
            <button type="submit" class="btn">Créer le compte</button>
        </form>
        <p class="auth-foot">
            Le compte reste inactif tant qu'un super admin ne l'a pas approuvé
            (sauf s'il s'agit du tout premier compte créé sur ce dashboard).
        </p>
        <?php endif; ?>
        <p class="auth-foot">Déjà un compte ? <a href="login.php">Se connecter</a></p>
    </div>
</div>
</body>
</html>
