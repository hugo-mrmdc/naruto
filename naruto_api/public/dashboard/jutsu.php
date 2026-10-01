<?php

declare(strict_types=1);

require __DIR__ . '/_bootstrap.php';

$rows = db_try(static fn (PDO $db) => $db->query('SELECT * FROM jutsu_definitions ORDER BY name')->fetchAll());

page_start('Catalogue des jutsu');
?>

<div class="filters">
    <input type="search" class="search" placeholder="Rechercher un jutsu…" data-filter="#jutsutable">
    <span class="count" data-count-for="#jutsutable"><?= count($rows) ?> jutsu</span>
</div>

<div class="card">
    <?php if ($rows === []): ?>
        <p class="empty">Catalogue vide pour l'instant. Il se remplit automatiquement au démarrage du serveur GMod (une fois la synchro activée).</p>
    <?php else: ?>
    <table id="jutsutable">
        <thead><tr><th>Nom</th><th>Description</th></tr></thead>
        <tbody>
        <?php foreach ($rows as $j): ?>
            <tr>
                <td data-label="Nom"><strong><?= h($j['name']) ?></strong></td>
                <td data-label="Description" class="wrap"><?= h($j['description'] ?: '—') ?></td>
            </tr>
        <?php endforeach; ?>
        </tbody>
    </table>
    <?php endif; ?>
</div>

<?php page_end(); ?>
