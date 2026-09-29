<?php

declare(strict_types=1);

require __DIR__ . '/_bootstrap.php';

const SORTABLE = ['level', 'xp', 'ryo', 'playtime', 'firstname'];
const SORT_LABELS = ['level' => 'Niveau', 'xp' => 'XP', 'ryo' => 'Ryo', 'playtime' => 'Temps de jeu', 'firstname' => 'Nom'];

$sort = $_GET['sort'] ?? 'level';
if (!in_array($sort, SORTABLE, true)) $sort = 'level';
$order = strtoupper((string) ($_GET['order'] ?? 'DESC')) === 'ASC' ? 'ASC' : 'DESC';
$village = trim((string) ($_GET['village'] ?? ''));
$clan = trim((string) ($_GET['clan'] ?? ''));

$rows = db_try(static function (PDO $db) use ($sort, $order, $village, $clan): array {
    $where = [];
    $params = [];
    if ($village !== '') { $where[] = 'village = :village'; $params['village'] = $village; }
    if ($clan !== '') { $where[] = 'clan = :clan'; $params['clan'] = $clan; }

    $sql = 'SELECT id, steamid, firstname, lastname, village, clan, rank, level, xp, ryo, playtime FROM characters';
    if ($where !== []) $sql .= ' WHERE ' . implode(' AND ', $where);
    $sql .= " ORDER BY {$sort} {$order} LIMIT 200";

    $stmt = $db->prepare($sql);
    $stmt->execute($params);
    return $stmt->fetchAll();
});

$villages = db_try(static fn (PDO $db) => $db->query('SELECT DISTINCT village FROM characters WHERE village <> \'\' ORDER BY village')->fetchAll(PDO::FETCH_COLUMN));
$clans = db_try(static fn (PDO $db) => $db->query('SELECT DISTINCT clan FROM characters WHERE clan <> \'\' ORDER BY clan')->fetchAll(PDO::FETCH_COLUMN));

function sort_link(string $col, string $label, string $sort, string $order, string $village, string $clan): string
{
    $nextOrder = ($sort === $col && $order === 'DESC') ? 'ASC' : 'DESC';
    $qs = http_build_query(['sort' => $col, 'order' => $nextOrder, 'village' => $village, 'clan' => $clan]);
    $active = $sort === $col ? ' active' : '';
    $arrow = $sort === $col ? ($order === 'DESC' ? ' ▼' : ' ▲') : '';
    return '<a class="sortlink' . $active . '" href="?' . $qs . '">' . h($label) . $arrow . '</a>';
}

page_start('Personnages');
?>

<form class="filters" method="get">
    <input type="hidden" name="sort" value="<?= h($sort) ?>">
    <input type="hidden" name="order" value="<?= h($order) ?>">
    <select name="village">
        <option value="">Tous les villages</option>
        <?php foreach ($villages as $v): ?>
            <option value="<?= h($v) ?>" <?= $v === $village ? 'selected' : '' ?>><?= h($v) ?></option>
        <?php endforeach; ?>
    </select>
    <select name="clan">
        <option value="">Tous les clans</option>
        <?php foreach ($clans as $c): ?>
            <option value="<?= h($c) ?>" <?= $c === $clan ? 'selected' : '' ?>><?= h($c) ?></option>
        <?php endforeach; ?>
    </select>
    <button type="submit">Filtrer</button>
</form>

<div class="card">
    <?php if ($rows === []): ?>
        <p class="empty">Aucun personnage pour l'instant. Ils apparaîtront ici dès que le serveur GMod synchronisera des fiches (<code>POST /characters/sync</code>).</p>
    <?php else: ?>
    <table>
        <thead>
        <tr>
            <th>Personnage</th>
            <th>Village</th>
            <th>Clan</th>
            <th>Grade</th>
            <th class="num"><?= sort_link('level', SORT_LABELS['level'], $sort, $order, $village, $clan) ?></th>
            <th class="num"><?= sort_link('xp', SORT_LABELS['xp'], $sort, $order, $village, $clan) ?></th>
            <th class="num"><?= sort_link('ryo', SORT_LABELS['ryo'], $sort, $order, $village, $clan) ?></th>
            <th class="num"><?= sort_link('playtime', SORT_LABELS['playtime'], $sort, $order, $village, $clan) ?></th>
        </tr>
        </thead>
        <tbody>
        <?php foreach ($rows as $c): ?>
            <tr>
                <td data-label="Personnage"><a href="character.php?id=<?= (int) $c['id'] ?>"><?= h(trim($c['firstname'] . ' ' . $c['lastname'])) ?: '#' . h($c['id']) ?></a></td>
                <td data-label="Village"><?= h($c['village'] ?: '—') ?></td>
                <td data-label="Clan"><?= h($c['clan'] ?: '—') ?></td>
                <td data-label="Grade"><?= h($c['rank'] ?: '—') ?></td>
                <td data-label="Niveau" class="num"><?= h($c['level']) ?></td>
                <td data-label="XP" class="num"><?= fmt_num($c['xp']) ?></td>
                <td data-label="Ryo" class="num"><?= fmt_num($c['ryo']) ?></td>
                <td data-label="Temps de jeu" class="num"><?= h(fmt_playtime((int) $c['playtime'])) ?></td>
            </tr>
        <?php endforeach; ?>
        </tbody>
    </table>
    <?php endif; ?>
</div>

<?php page_end(); ?>
