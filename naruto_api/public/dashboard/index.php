<?php

declare(strict_types=1);

require __DIR__ . '/_bootstrap.php';

$stats = db_try(static function (PDO $db): array {
    return [
        'characters'  => (int) $db->query('SELECT COUNT(*) FROM characters')->fetchColumn(),
        'bounties'    => (int) $db->query('SELECT COUNT(*) FROM bounties WHERE active = 1')->fetchColumn(),
        'sessions'    => (int) $db->query('SELECT COUNT(*) FROM sessions WHERE disconnected_at IS NULL')->fetchColumn(),
        'playtime'    => (int) $db->query('SELECT COALESCE(SUM(playtime), 0) FROM characters')->fetchColumn(),
    ];
});

$top = db_try(static function (PDO $db): array {
    return $db->query('SELECT id, steamid, firstname, lastname, village, clan, level, xp FROM characters ORDER BY level DESC, xp DESC LIMIT 5')->fetchAll();
});

$recentLogs = db_try(static function (PDO $db): array {
    return $db->query('SELECT * FROM logs ORDER BY occurred_at DESC LIMIT 8')->fetchAll();
});

page_start('Tableau de bord');
?>

<div class="grid">
    <div class="stat-card"><div class="value"><?= fmt_num($stats['characters'] ?? 0) ?></div><div class="label">Personnages</div></div>
    <div class="stat-card"><div class="value"><?= fmt_num($stats['bounties'] ?? 0) ?></div><div class="label">Primes actives</div></div>
    <div class="stat-card"><div class="value"><?= fmt_num($stats['sessions'] ?? 0) ?></div><div class="label">Joueurs en ligne</div></div>
    <div class="stat-card"><div class="value"><?= fmt_playtime((int) ($stats['playtime'] ?? 0)) ?></div><div class="label">Temps de jeu cumulé</div></div>
</div>

<div class="card">
    <h2>Top 5 <small>par niveau — <a href="characters.php">voir tout le classement</a></small></h2>
    <?php if ($top === []): ?>
        <p class="empty">Aucune donnée pour l'instant. Elle apparaîtra ici dès que le serveur GMod synchronisera des personnages.</p>
    <?php else: ?>
    <table>
        <thead><tr><th>#</th><th>Personnage</th><th>Village</th><th>Clan</th><th class="num">Niveau</th><th class="num">XP</th></tr></thead>
        <tbody>
        <?php foreach ($top as $i => $c): ?>
            <tr>
                <td data-label="#"><?= $i + 1 ?></td>
                <td data-label="Personnage"><a href="character.php?id=<?= (int) $c['id'] ?>"><?= h(trim($c['firstname'] . ' ' . $c['lastname'])) ?: '#' . h($c['id']) ?></a></td>
                <td data-label="Village"><?= h($c['village'] ?: '—') ?></td>
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
                <td data-label="Quand"><?= h(fmt_date($log['occurred_at'])) ?></td>
                <td data-label="Catégorie"><span class="badge accent"><?= h($log['category']) ?></span></td>
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
