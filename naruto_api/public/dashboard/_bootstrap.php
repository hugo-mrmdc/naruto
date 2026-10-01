<?php

declare(strict_types=1);

/**
 * Bootstrap du dashboard : pages PHP classiques (HTML, pas de JSON), rendues
 * côté serveur. Elles lisent la base MySQL directement via Database::connection(),
 * SANS passer par les routes /characters, /logs... de l'API (donc sans
 * jamais avoir besoin de la clé X-Api-Key ici). C'est volontaire : la clé API
 * sert au serveur GMod, elle ne doit jamais atteindre un navigateur.
 *
 * Lecture seule pour les admins ; les super admins peuvent en plus modifier/supprimer
 * (character.php, logs.php, users.php), toujours avec un jeton CSRF.
 */

require __DIR__ . '/../../src/Config.php';
require __DIR__ . '/../../src/Database.php';
require __DIR__ . '/../../src/DashboardAuth.php';

date_default_timezone_set(Config::get('APP_TIMEZONE', 'UTC'));

// Toutes les pages qui chargent ce bootstrap exigent un compte actif
// (login.php et logout.php ne le chargent pas, pour ne pas boucler).
DashboardAuth::requireLogin();

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
    'index.php'      => ['Accueil',     'M3 11l9-8 9 8v9a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z'],
    'characters.php' => ['Personnages', 'M16 11a4 4 0 1 0-8 0 4 4 0 0 0 8 0zM4 21a8 8 0 0 1 16 0'],
    'jutsu.php'      => ['Jutsu',       'M12 2s5 5 5 10a5 5 0 0 1-10 0c0-2 1-3 2-4 0 2 1 3 2 3 0-3-1-5 1-9z'],
    'logs.php'       => ['Journal',     'M5 4h14v16H5zM9 9h6M9 13h6M9 17h3'],
];
$ICON_USERS = 'M17 20v-2a4 4 0 0 0-4-4H7a4 4 0 0 0-4 4v2M10 10a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM21 20v-2a4 4 0 0 0-3-3.9';

/** Icône SVG de trait (24x24) à partir d'un tracé. */
function icon(string $path): string
{
    return '<svg class="ico" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="' . $path . '"/></svg>';
}

/** Couleur stable (teinte) pour un texte : même village = même couleur partout. */
function hue_of(string $text): int
{
    return abs(crc32(mb_strtolower($text))) % 360;
}

/** Pastille ronde avec les initiales d'un personnage. */
function avatar(string $name, string $village = ''): string
{
    $name = trim($name) !== '' ? trim($name) : '?';
    $parts = preg_split('/\s+/', $name) ?: [$name];
    $ini = mb_strtoupper(mb_substr($parts[0], 0, 1) . (isset($parts[1]) ? mb_substr($parts[1], 0, 1) : ''));
    $hue = hue_of($village !== '' ? $village : $name);
    return '<span class="avatar" style="--h:' . $hue . '">' . h($ini) . '</span>';
}

/** Badge de catégorie de journal, couleur stable par catégorie. */
function cat_badge(string $cat): string
{
    return '<span class="badge" style="--h:' . hue_of($cat) . '">' . h($cat) . '</span>';
}

/** Badge de village, couleur stable par village. */
function village_badge(string $village): string
{
    return $village === '' ? '—' : '<span class="badge" style="--h:' . hue_of($village) . '">' . h($village) . '</span>';
}

/** "il y a 5 min" à partir d'une date MySQL. */
function time_ago(?string $mysqlDate): string
{
    $ts = $mysqlDate ? strtotime($mysqlDate) : false;
    if (!$ts) return '—';
    $d = max(0, time() - $ts);
    if ($d < 60) return "à l'instant";
    if ($d < 3600) return 'il y a ' . intdiv($d, 60) . ' min';
    if ($d < 86400) return 'il y a ' . intdiv($d, 3600) . ' h';
    return 'il y a ' . intdiv($d, 86400) . ' j';
}

function page_start(string $title): void
{
    global $NAV, $ICON_USERS;
    $current = basename($_SERVER['SCRIPT_NAME'] ?? '');
    $me = DashboardAuth::currentUser();
    $nav = $NAV;
    if (DashboardAuth::isSuperAdmin()) {
        $nav['users.php'] = ['Utilisateurs', $ICON_USERS];
    }
    // character.php fait partie de la section "Personnages"
    if ($current === 'character.php') $current = 'characters.php';
    ?>
<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title><?= h($title) ?> — Naruto RP</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap">
<script>try{var t=localStorage.getItem("nrp-theme");if(t)document.documentElement.dataset.theme=t;}catch(e){}</script>
<link rel="stylesheet" href="style.css?v=<?= (int) @filemtime(__DIR__ . '/style.css') ?>">
</head>
<body>
<div class="shell">
<aside class="sidebar">
    <a class="brand" href="index.php"><span class="brand-logo"></span><span>Naruto RP<small>Dashboard</small></span></a>
    <nav>
        <?php foreach ($nav as $href => [$label, $path]): ?>
            <a href="<?= h($href) ?>" class="<?= $href === $current ? 'active' : '' ?>"><?= icon($path) ?><span><?= h($label) ?></span></a>
        <?php endforeach; ?>
    </nav>
    <?php if ($me): ?>
        <div class="side-foot">
            <span class="userchip"><?= avatar((string) $me['username']) ?>
                <span class="who"><?= h($me['username']) ?><small><?= h($me['role']) ?></small></span>
            </span>
            <button type="button" class="theme-toggle" id="themeToggle" title="Changer de thème" aria-label="Changer de thème"><?= icon('M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z') ?></button>
            <a class="logout" href="logout.php" title="Déconnexion"><?= icon('M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9') ?></a>
        </div>
    <?php endif; ?>
</aside>
<div class="content">
<main class="container">
<h1 class="page-title"><?= h($title) ?></h1>
<?php
}

function page_end(): void
{
    ?>
</main>
<footer class="footer">Données synchronisées depuis le serveur GMod — naruto_api</footer>
</div>
</div>
<script src="app.js?v=<?= (int) @filemtime(__DIR__ . '/app.js') ?>" defer></script>
</body>
</html>
<?php
}
