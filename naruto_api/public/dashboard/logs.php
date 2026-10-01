<?php

declare(strict_types=1);

require __DIR__ . '/_bootstrap.php';

$category = trim((string) ($_GET['category'] ?? ''));
$isSuper = DashboardAuth::isSuperAdmin();
$flash = null;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    DashboardAuth::requireSuperAdmin();
    DashboardAuth::checkCsrf();
    if (($_POST['action'] ?? '') === 'delete_log') {
        Database::connection()->prepare('DELETE FROM logs WHERE id = :id')->execute(['id' => (int) ($_POST['log_id'] ?? 0)]);
        $flash = ['success', 'Entrée supprimée.'];
    }
}

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

<?php if ($flash): ?>
    <p class="msg-success"><?= h($flash[1]) ?></p>
<?php endif; ?>

<form class="filters" method="get">
    <select name="category" onchange="this.form.submit()">
        <option value="">Toutes les catégories</option>
        <?php foreach ($categories as $c): ?>
            <option value="<?= h($c) ?>" <?= $c === $category ? 'selected' : '' ?>><?= h($c) ?></option>
        <?php endforeach; ?>
    </select>
    <button type="submit">Filtrer</button>
    <input type="search" class="search" placeholder="Rechercher dans les entrées…" data-filter="#logtable">
    <span class="count" data-count-for="#logtable"><?= count($rows) ?> entrée(s)</span>
</form>

<div class="card">
    <?php if ($rows === []): ?>
        <p class="empty">Aucune entrée de journal pour l'instant.</p>
    <?php else: ?>
    <table id="logtable">
        <thead><tr><th>Quand</th><th>Catégorie</th><th>Acteur</th><th>Cible</th><th>Message</th><?php if ($isSuper): ?><th></th><?php endif; ?></tr></thead>
        <tbody>
        <?php foreach ($rows as $log): ?>
            <tr>
                <td data-label="Quand"><?= h(time_ago($log['occurred_at'])) ?> <small class="dim"><?= h(fmt_date($log['occurred_at'])) ?></small></td>
                <td data-label="Catégorie"><?= cat_badge((string) $log['category']) ?></td>
                <td data-label="Acteur"><?= h($log['actor_name'] ?: '—') ?></td>
                <td data-label="Cible">
                    <?php if ($log['target_steamid']): ?>
                        <a href="character.php?steamid=<?= urlencode($log['target_steamid']) ?>"><?= h($log['target_steamid']) ?></a>
                    <?php else: ?>—<?php endif; ?>
                </td>
                <td data-label="Message" class="wrap"><?= h($log['message']) ?></td>
                <?php if ($isSuper): ?>
                <td>
                    <form method="post" onsubmit="return confirm('Supprimer cette entrée du journal ?')">
                        <input type="hidden" name="csrf" value="<?= h(DashboardAuth::csrfToken()) ?>">
                        <input type="hidden" name="action" value="delete_log">
                        <input type="hidden" name="log_id" value="<?= (int) $log['id'] ?>">
                        <button type="submit" class="badge danger" style="border:none;cursor:pointer">✕</button>
                    </form>
                </td>
                <?php endif; ?>
            </tr>
        <?php endforeach; ?>
        </tbody>
    </table>
    <?php endif; ?>
</div>

<?php page_end(); ?>
