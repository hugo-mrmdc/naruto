<?php

declare(strict_types=1);

require __DIR__ . '/_bootstrap.php';

$category = trim((string) ($_GET['category'] ?? ''));

$rows = db_try(static function (PDO $db) use ($category): array {
    $sql = 'SELECT * FROM logs';
    $params = [];
    if ($category !== '') {
        $sql .= ' WHERE category = :category';
        $params['category'] = $category;
    }
    $sql .= ' ORDER BY occurred_at DESC LIMIT 200';
    $stmt = $db->prepare($sql);
    $stmt->execute($params);
    return $stmt->fetchAll();
});

$categories = db_try(static fn (PDO $db) => $db->query('SELECT DISTINCT category FROM logs ORDER BY category')->fetchAll(PDO::FETCH_COLUMN));

page_start('Journal d\'actions');
?>

<form class="filters" method="get">
    <select name="category" onchange="this.form.submit()">
        <option value="">Toutes les catégories</option>
        <?php foreach ($categories as $c): ?>
            <option value="<?= h($c) ?>" <?= $c === $category ? 'selected' : '' ?>><?= h($c) ?></option>
        <?php endforeach; ?>
    </select>
    <button type="submit">Filtrer</button>
</form>

<div class="card">
    <?php if ($rows === []): ?>
        <p class="empty">Aucune entrée de journal pour l'instant.</p>
    <?php else: ?>
    <table>
        <thead><tr><th>Quand</th><th>Catégorie</th><th>Acteur</th><th>Cible</th><th>Message</th></tr></thead>
        <tbody>
        <?php foreach ($rows as $log): ?>
            <tr>
                <td data-label="Quand"><?= h(fmt_date($log['occurred_at'])) ?></td>
                <td data-label="Catégorie"><span class="badge accent"><?= h($log['category']) ?></span></td>
                <td data-label="Acteur"><?= h($log['actor_name'] ?: '—') ?></td>
                <td data-label="Cible">
                    <?php if ($log['target_steamid']): ?>
                        <a href="character.php?steamid=<?= urlencode($log['target_steamid']) ?>"><?= h($log['target_steamid']) ?></a>
                    <?php else: ?>—<?php endif; ?>
                </td>
                <td data-label="Message" class="wrap"><?= h($log['message']) ?></td>
            </tr>
        <?php endforeach; ?>
        </tbody>
    </table>
    <?php endif; ?>
</div>

<?php page_end(); ?>
