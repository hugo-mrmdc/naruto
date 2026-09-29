<?php

declare(strict_types=1);

require __DIR__ . '/_bootstrap.php';

$showAll = ($_GET['all'] ?? '') === '1';

$rows = db_try(static function (PDO $db) use ($showAll): array {
    $sql = 'SELECT * FROM bounties' . ($showAll ? '' : ' WHERE active = 1') . ' ORDER BY amount DESC';
    return $db->query($sql)->fetchAll();
});

page_start('Bingo Book');
?>

<div class="filters">
    <a href="bounties.php" class="badge <?= !$showAll ? 'accent' : '' ?>">Primes actives</a>
    <a href="bounties.php?all=1" class="badge <?= $showAll ? 'accent' : '' ?>">Historique complet</a>
</div>

<div class="card">
    <?php if ($rows === []): ?>
        <p class="empty">Aucune prime <?= $showAll ? 'enregistrée' : 'active' ?> pour l'instant.</p>
    <?php else: ?>
    <table>
        <thead><tr><th>Cible</th><th class="num">Montant</th><th>Raison</th><th>Émetteur</th><th>Village</th><th>Statut</th></tr></thead>
        <tbody>
        <?php foreach ($rows as $b): ?>
            <tr>
                <td data-label="Cible"><a href="character.php?steamid=<?= urlencode($b['target_steamid']) ?>"><?= h($b['target_name'] ?: $b['target_steamid']) ?></a></td>
                <td data-label="Montant" class="num"><?= fmt_num($b['amount']) ?> Ryo</td>
                <td data-label="Raison" class="wrap"><?= h($b['reason']) ?></td>
                <td data-label="Émetteur"><?= h($b['issuer_name'] ?: 'Village') ?></td>
                <td data-label="Village"><?= h($b['village'] ?: '—') ?></td>
                <td data-label="Statut"><?= $b['active'] ? '<span class="badge warning">active</span>' : '<span class="badge">terminée</span>' ?></td>
            </tr>
        <?php endforeach; ?>
        </tbody>
    </table>
    <?php endif; ?>
</div>

<?php page_end(); ?>
