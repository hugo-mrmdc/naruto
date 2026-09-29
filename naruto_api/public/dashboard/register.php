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
<link rel="stylesheet" href="style.css">
</head>
<body>
<main class="container" style="max-width:380px;padding-top:80px">
    <div class="card">
        <h1 class="page-title" style="margin-bottom:18px">Créer un compte</h1>
        <?php if ($error): ?>
            <p style="color:var(--danger);margin-top:0"><?= h($error) ?></p>
        <?php endif; ?>
        <?php if ($success): ?>
            <p style="color:var(--success);margin-top:0"><?= h($success) ?></p>
            <p><a href="login.php">Aller à la connexion</a></p>
        <?php else: ?>
        <form method="post">
            <label style="display:block;margin-bottom:14px">
                <span style="display:block;color:var(--text-dim);font-size:.85rem;margin-bottom:6px">Nom d'utilisateur</span>
                <input type="text" name="username" autofocus required minlength="3" maxlength="32" pattern="[a-zA-Z0-9_-]+"
                       value="<?= h($_POST['username'] ?? '') ?>"
                       style="width:100%;background:var(--panel-light);border:1px solid var(--border);color:var(--text);padding:9px 12px;border-radius:6px">
            </label>
            <label style="display:block;margin-bottom:14px">
                <span style="display:block;color:var(--text-dim);font-size:.85rem;margin-bottom:6px">Mot de passe (8 caractères min.)</span>
                <input type="password" name="password" required minlength="8"
                       style="width:100%;background:var(--panel-light);border:1px solid var(--border);color:var(--text);padding:9px 12px;border-radius:6px">
            </label>
            <label style="display:block;margin-bottom:14px">
                <span style="display:block;color:var(--text-dim);font-size:.85rem;margin-bottom:6px">Confirme le mot de passe</span>
                <input type="password" name="password_confirm" required minlength="8"
                       style="width:100%;background:var(--panel-light);border:1px solid var(--border);color:var(--text);padding:9px 12px;border-radius:6px">
            </label>
            <button type="submit" style="width:100%;background:var(--accent);color:#1a0f05;border:none;padding:10px;border-radius:6px;font-weight:600;cursor:pointer">
                Créer le compte
            </button>
        </form>
        <p style="color:var(--text-dim);font-size:.8rem;margin-top:14px">
            Le compte reste inactif tant qu'un super admin ne l'a pas approuvé
            (sauf s'il s'agit du tout premier compte créé sur ce dashboard).
        </p>
        <?php endif; ?>
        <p style="text-align:center;margin-bottom:0;margin-top:16px;color:var(--text-dim);font-size:.85rem">
            Déjà un compte ? <a href="login.php">Se connecter</a>
        </p>
    </div>
</main>
</body>
</html>
