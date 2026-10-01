<?php

declare(strict_types=1);

require __DIR__ . '/_bootstrap.php';

$stats = db_try(static function (PDO $db): array {
    return [
        'characters' => (int) $db->query('SELECT COUNT(*) FROM characters')->fetchColumn(),
        'sessions'   => (int) $db->query('SELECT COUNT(*) FROM sessions WHERE disconnected_at IS NULL')->fetchColumn(),
        'playtime'   => (int) $db->query('SELECT COALESCE(SUM(playtime), 0) FROM characters')->fetchColumn(),
        'ryo'        => (int) $db->query('SELECT COALESCE(SUM(ryo), 0) FROM characters')->fetchColumn(),
        'players'    => (int) $db->query('SELECT COUNT(*) FROM players')->fetchColumn(),
        'avg_level'  => (float) $db->query('SELECT COALESCE(AVG(level), 0) FROM characters')->fetchColumn(),
    ];
});

$top = db_try(static function (PDO $db): array {
    return $db->query('SELECT id, steamid, firstname, lastname, village, clan, level, xp FROM characters ORDER BY level DESC, xp DESC LIMIT 5')->fetchAll();
});

$recentLogs = db_try(static function (PDO $db): array {
    return $db->query('SELECT * FROM logs ORDER BY occurred_at DESC LIMIT 8')->fetchAll();
});

// Joueurs actuellement connectés (session ouverte)
$online = db_try(static function (PDO $db): array {
    return $db->query(
        'SELECT s.steamid, s.connected_at, p.steam_name FROM sessions s
         LEFT JOIN players p ON p.steamid = s.steamid
         WHERE s.disconnected_at IS NULL ORDER BY s.connected_at DESC LIMIT 8'
    )->fetchAll();
});

// Répartition des personnages par village
$villages = db_try(static function (PDO $db): array {
    return $db->query("SELECT COALESCE(NULLIF(village, ''), 'Sans village') AS name, COUNT(*) AS n FROM characters GROUP BY name ORDER BY n DESC LIMIT 8")->fetchAll();
});

// Répartition par tranche de 10 niveaux
$levels = db_try(static function (PDO $db): array {
    return $db->query(
        'SELECT FLOOR((GREATEST(level, 1) - 1) / 10) AS b, COUNT(*) AS n FROM characters GROUP BY b ORDER BY b'
    )->fetchAll();
});

// Activité des 14 derniers jours (nombre d'entrées de journal par jour)
$activityRaw = db_try(static function (PDO $db): array {
    return $db->query(
        'SELECT DATE(occurred_at) AS d, COUNT(*) AS n FROM logs
         WHERE occurred_at >= (CURDATE() - INTERVAL 13 DAY) GROUP BY d'
    )->fetchAll(PDO::FETCH_KEY_PAIR);
});
$days = [];
for ($i = 13; $i >= 0; $i--) {
    $d = date('Y-m-d', strtotime("-{$i} day"));
    $days[$d] = (int) ($activityRaw[$d] ?? 0);
}

// Courbe SVG (sans librairie) : on calcule les points ici
$W = 560; $H = 150; $PAD = 8;
$maxDay = max(1, max($days));
$pts = [];
$k = 0;
foreach ($days as $d => $n) {
    $x = $PAD + ($W - 2 * $PAD) * $k / max(1, count($days) - 1);
    $y = $H - $PAD - ($H - 2 * $PAD) * $n / $maxDay;
    $pts[] = [round($x, 1), round($y, 1), $d, $n];
    $k++;
}
$line = implode(' ', array_map(static fn($p) => $p[0] . ',' . $p[1], $pts));
$area = $PAD . ',' . ($H - $PAD) . ' ' . $line . ' ' . ($W - $PAD) . ',' . ($H - $PAD);
$totalActivity = array_sum($days);

$maxVillage = max(1, (int) max(array_map(static fn($v) => (int) $v['n'], $villages) ?: [1]));
$maxLevel   = max(1, (int) max(array_map(static fn($v) => (int) $v['n'], $levels) ?: [1]));
$me = DashboardAuth::currentUser();
$hour = (int) date('G');
$greet = ($hour < 6 || $hour >= 18) ? 'Bonsoir' : 'Bonjour';
$onlineCount = (int) ($stats['sessions'] ?? 0);

page_start('Tableau de bord');
?>

<section class="hero">
    <div>
        <h2><?= $greet ?>, <?= h($me['username'] ?? '') ?></h2>
        <p>Voici l'état du serveur Naruto RP : <strong><?= fmt_num($onlineCount) ?></strong> joueur(s) en ligne
        et <strong><?= fmt_num($totalActivity) ?></strong> action(s) enregistrée(s) ces 14 derniers jours.</p>
    </div>
    <span class="live <?= $onlineCount > 0 ? 'on' : '' ?>"><i></i><?= $onlineCount > 0 ? 'Serveur actif' : 'Aucun joueur' ?></span>
</section>

<div class="grid">
    <div class="stat-card"><div class="stat-ico"><?= icon('M16 11a4 4 0 1 0-8 0 4 4 0 0 0 8 0zM4 21a8 8 0 0 1 16 0') ?></div><div class="value" data-count="<?= (int) ($stats['characters'] ?? 0) ?>"><?= fmt_num($stats['characters'] ?? 0) ?></div><div class="label">Personnages <small>· <?= fmt_num($stats['players'] ?? 0) ?> comptes Steam</small></div></div>
    <div class="stat-card"><div class="stat-ico"><?= icon('M13 2L4 14h7l-1 8 9-12h-7z') ?></div><div class="value" data-count="<?= $onlineCount ?>"><?= fmt_num($onlineCount) ?></div><div class="label">Joueurs en ligne</div></div>
    <div class="stat-card"><div class="stat-ico"><?= icon('M12 7v5l3 2M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0z') ?></div><div class="value"><?= fmt_playtime((int) ($stats['playtime'] ?? 0)) ?></div><div class="label">Temps de jeu cumulé</div></div>
    <div class="stat-card"><div class="stat-ico"><?= icon('M12 2v20M17 6H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6') ?></div><div class="value" data-count="<?= (int) ($stats['ryo'] ?? 0) ?>"><?= fmt_num($stats['ryo'] ?? 0) ?></div><div class="label">Ryo en circulation <small>· niveau moyen <?= number_format((float) ($stats['avg_level'] ?? 0), 1, ',', '') ?></small></div></div>
</div>

<div class="cols">
    <div class="card">
        <h2>Activité <small>14 derniers jours</small></h2>
        <svg class="chart" viewBox="0 0 <?= $W ?> <?= $H ?>" preserveAspectRatio="none" role="img" aria-label="Activité du journal sur 14 jours">
            <defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ff8a2b" stop-opacity=".45"/><stop offset="1" stop-color="#ff8a2b" stop-opacity="0"/></linearGradient></defs>
            <?php for ($g = 1; $g <= 3; $g++): $gy = $PAD + ($H - 2 * $PAD) * $g / 4; ?>
                <line x1="0" x2="<?= $W ?>" y1="<?= $gy ?>" y2="<?= $gy ?>" class="gridline"/>
            <?php endfor; ?>
            <polygon points="<?= $area ?>" fill="url(#g)"/>
            <polyline points="<?= $line ?>" class="curve"/>
            <?php foreach ($pts as $p): ?>
                <circle cx="<?= $p[0] ?>" cy="<?= $p[1] ?>" r="4" class="dot"><title><?= h(date('d/m', strtotime($p[2]))) ?> : <?= (int) $p[3] ?> action(s)</title></circle>
            <?php endforeach; ?>
        </svg>
        <div class="chart-axis"><span><?= h(date('d/m', strtotime((string) array_key_first($days)))) ?></span><span>pic : <?= $maxDay ?>/jour</span><span>aujourd'hui</span></div>
    </div>

    <div class="card">
        <h2>En ligne <small><?= count($online) ?> joueur(s)</small></h2>
        <?php if ($online === []): ?>
            <p class="empty">Personne n'est connecté.</p>
        <?php else: ?>
            <ul class="people">
            <?php foreach ($online as $o): $nm = (string) ($o['steam_name'] ?: $o['steamid']); ?>
                <li><?= avatar($nm) ?>
                    <span class="grow"><strong><?= h($nm) ?></strong><small><?= h($o['steamid']) ?></small></span>
                    <small><?= h(time_ago($o['connected_at'])) ?></small></li>
            <?php endforeach; ?>
            </ul>
        <?php endif; ?>
    </div>
</div>

<div class="cols">
    <div class="card">
        <h2>Villages <small>répartition des personnages</small></h2>
        <?php if ($villages === []): ?>
            <p class="empty">Aucune donnée.</p>
        <?php else: foreach ($villages as $v): ?>
            <div class="bar-row">
                <span class="bar-label"><?= h($v['name']) ?></span>
                <span class="bar"><i style="width:<?= round(100 * (int) $v['n'] / $maxVillage) ?>%;--h:<?= hue_of((string) $v['name']) ?>"></i></span>
                <span class="bar-val"><?= fmt_num($v['n']) ?></span>
            </div>
        <?php endforeach; endif; ?>
    </div>

    <div class="card">
        <h2>Niveaux <small>par tranche de 10</small></h2>
        <?php if ($levels === []): ?>
            <p class="empty">Aucune donnée.</p>
        <?php else: ?>
            <div class="histo">
            <?php foreach ($levels as $l): $from = (int) $l['b'] * 10 + 1; ?>
                <div class="histo-col" title="<?= (int) $l['n'] ?> personnage(s)">
                    <span class="histo-val"><?= (int) $l['n'] ?></span>
                    <span class="histo-bar" style="height:<?= max(4, round(120 * (int) $l['n'] / $maxLevel)) ?>px"></span>
                    <span class="histo-lbl"><?= $from ?>-<?= $from + 9 ?></span>
                </div>
            <?php endforeach; ?>
            </div>
        <?php endif; ?>
    </div>
</div>

<div class="card">
    <h2>Top 5 <small>par niveau — <a href="characters.php">voir tout le classement</a></small></h2>
    <?php if ($top === []): ?>
        <p class="empty">Aucune donnée pour l'instant. Elle apparaîtra ici dès que le serveur GMod synchronisera des personnages.</p>
    <?php else: ?>
    <table>
        <thead><tr><th>#</th><th>Personnage</th><th>Village</th><th>Clan</th><th class="num">Niveau</th><th class="num">XP</th></tr></thead>
        <tbody>
        <?php foreach ($top as $i => $c): $full = trim($c['firstname'] . ' ' . $c['lastname']); ?>
            <tr>
                <td data-label="#"><span class="rank r<?= $i + 1 ?>"><?= $i + 1 ?></span></td>
                <td data-label="Personnage"><a class="who-link" href="character.php?id=<?= (int) $c['id'] ?>"><?= avatar($full, (string) $c['village']) ?><?= $full !== '' ? h($full) : '#' . h($c['id']) ?></a></td>
                <td data-label="Village"><?= $c['village'] ? '<span class="badge" style="--h:' . hue_of((string) $c['village']) . '">' . h($c['village']) . '</span>' : '—' ?></td>
                <td data-label="Clan"><?= h($c['clan'] ?: '—') ?></td>
                <td data-label="Niveau" class="num"><?= h($c['level']) ?></td>
                <td data-label="XP" class="num"><?= fmt_num($c['xp']) ?></td>
            </tr>
        <?php endforeach; ?>
        </tbody>
    </table>
    <?php endif; ?>
</div>

<div class="card">
    <h2>Activité récente <small><a href="logs.php">voir tout le journal</a></small></h2>
    <?php if ($recentLogs === []): ?>
        <p class="empty">Aucune activité enregistrée pour l'instant.</p>
    <?php else: ?>
    <table>
        <thead><tr><th>Quand</th><th>Catégorie</th><th>Acteur</th><th>Cible</th><th>Message</th></tr></thead>
        <tbody>
        <?php foreach ($recentLogs as $log): ?>
            <tr>
                <td data-label="Quand" title="<?= h(fmt_date($log['occurred_at'])) ?>"><?= h(time_ago($log['occurred_at'])) ?></td>
                <td data-label="Catégorie"><?= cat_badge((string) $log['category']) ?></td>
                <td data-label="Acteur"><?= h($log['actor_name'] ?: '—') ?></td>
                <td data-label="Cible"><?= h($log['target_steamid'] ?: '—') ?></td>
                <td data-label="Message" class="wrap"><?= h($log['message']) ?></td>
            </tr>
        <?php endforeach; ?>
        </tbody>
    </table>
    <?php endif; ?>
</div>

<?php page_end(); ?>
