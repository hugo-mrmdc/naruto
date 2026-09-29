<?php

declare(strict_types=1);

/**
 * Bootstrap du dashboard : pages PHP classiques (HTML, pas de JSON), rendues
 * côté serveur. Elles lisent la base MySQL directement via Database::connection(),
 * SANS passer par les routes /characters, /bounties... de l'API (donc sans
 * jamais avoir besoin de la clé X-Api-Key ici). C'est volontaire : la clé API
 * sert au serveur GMod, elle ne doit jamais atteindre un navigateur.
 *
 * Lecture seule : ce dashboard n'écrit jamais dans la base.
 */

require __DIR__ . '/../../src/Config.php';
require __DIR__ . '/../../src/Database.php';

date_default_timezone_set(Config::get('APP_TIMEZONE', 'UTC'));

set_exception_handler(static function (Throwable $e): void {
    error_log('[naruto_api dashboard] ' . $e->getMessage() . ' @ ' . $e->getFile() . ':' . $e->getLine());
    http_response_code(500);
    echo '<!doctype html><meta charset="utf-8"><body style="background:#12121a;color:#e8e8ee;font-family:sans-serif;padding:40px">'
        . '<h1>Erreur</h1><p>Impossible de charger cette page pour le moment.</p></body>';
    exit;
});

/** Échappe pour affichage HTML. */
function h(mixed $value): string
{
    return htmlspecialchars((string) ($value ?? ''), ENT_QUOTES, 'UTF-8');
}

/** Formate un nombre avec des espaces comme séparateur de milliers. */
function fmt_num(mixed $n): string
{
    return number_format((float) ($n ?? 0), 0, ',', ' ');
}

function fmt_playtime(int $seconds): string
{
    $h = intdiv($seconds, 3600);
    $m = intdiv($seconds % 3600, 60);
    return $h > 0 ? "{$h} h {$m} min" : "{$m} min";
}

function fmt_date(?string $mysqlDate): string
{
    if (!$mysqlDate) return '—';
    $ts = strtotime($mysqlDate);
    return $ts ? date('d/m/Y H:i', $ts) : '—';
}

/**
 * Tente une requête et retourne un tableau vide si la base n'est pas encore
 * configurée/accessible (dashboard installé avant le premier déploiement de
 * la base, ou pendant que le serveur GMod n'a encore rien synchronisé).
 */
function db_try(callable $query): array
{
    try {
        return $query(Database::connection());
    } catch (Throwable $e) {
        error_log('[naruto_api dashboard] requête échouée : ' . $e->getMessage());
        return [];
    }
}

$NAV = [
    'index.php'      => 'Accueil',
    'characters.php' => 'Personnages',
    'bounties.php'   => 'Bingo Book',
    'logs.php'       => 'Journal',
];

function page_start(string $title): void
{
    global $NAV;
    $current = basename($_SERVER['SCRIPT_NAME'] ?? '');
    ?>
<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title><?= h($title) ?> — Naruto RP</title>
<link rel="stylesheet" href="style.css">
</head>
<body>
<header class="topbar">
    <div class="topbar-inner">
        <a class="brand" href="index.php">Naruto RP</a>
        <nav>
            <?php foreach ($NAV as $href => $label): ?>
                <a href="<?= h($href) ?>" class="<?= $href === $current ? 'active' : '' ?>"><?= h($label) ?></a>
            <?php endforeach; ?>
        </nav>
    </div>
</header>
<main class="container">
<h1 class="page-title"><?= h($title) ?></h1>
<?php
}

function page_end(): void
{
    ?>
</main>
<footer class="footer">Données synchronisées depuis le serveur GMod — naruto_api</footer>
</body>
</html>
<?php
}
