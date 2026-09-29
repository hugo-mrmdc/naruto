<?php

declare(strict_types=1);

require __DIR__ . '/_bootstrap.php';

$category = trim((string) ($_GET['category'] ?? ''));
$element = trim((string) ($_GET['element'] ?? ''));

$rows = db_try(static function (PDO $db) use ($category, $element): array {
    $where = [];
    $params = [];
    if ($category !== '') { $where[] = 'category = :category'; $params['category'] = $category; }
    if ($element !== '') { $where[] = 'element = :element'; $params['element'] = $element; }

    $sql = 'SELECT * FROM jutsu_definitions';
    if ($where !== []) $sql .= ' WHERE ' . implode(' AND ', $where);
    $sql .= ' ORDER BY category, name';

    $stmt = $db->prepare($sql);
    $stmt->execute($params);
    return $stmt->fetchAll();
});

$categories = db_try(static fn (PDO $db) => $db->query("SELECT DISTINCT category FROM jutsu_definitions WHERE category <> '' ORDER BY category")->fetchAll(PDO::FETCH_COLUMN));
$elements = db_try(static fn (PDO $db) => $db->query("SELECT DISTINCT element FROM jutsu_definitions WHERE element <> '' ORDER BY element")->fetchAll(PDO::FETCH_COLUMN));

function requirements_text(?string $json): string
{
    $req = $json ? (json_decode($json, true) ?: []) : [];
    if ($req === []) return '—';

    $parts = [];
    if (!empty($req['level'])) $parts[] = 'niv. ' . $req['level'];
    if (!empty($req['rank'])) $parts[] = 'grade ' . $req['rank'];
    if (!empty($req['affinity'])) {
        $aff = $req['affinity'];
        $parts[] = 'affinité ' . (is_array($aff) ? implode('/', $aff) : $aff);
    }
    if (!empty($req['clan'])) {
        $clan = $req['clan'];
        $parts[] = 'clan ' . (is_array($clan) ? implode('/', $clan) : $clan);
    }
    foreach ($req['stats'] ?? [] as $stat => $min) {
        $parts[] = "{$stat} {$min}";
    }
    if (!empty($req['dojutsu']) && is_array($req['dojutsu'])) {
        $d = $req['dojutsu'];
        $parts[] = ($d['id'] ?? 'dōjutsu') . ' stade ' . ($d['stage'] ?? 1) . (!empty($d['active']) ? ' (actif)' : '');
    }
    return $parts === [] ? '—' : implode(', ', $parts);
}

page_start('Catalogue des jutsu');
?>

<form class="filters" method="get">
    <select name="category" onchange="this.form.submit()">
        <option value="">Toutes les catégories</option>
        <?php foreach ($categories as $c): ?>
            <option value="<?= h($c) ?>" <?= $c === $category ? 'selected' : '' ?>><?= h(ucfirst($c)) ?></option>
        <?php endforeach; ?>
    </select>
    <select name="element" onchange="this.form.submit()">
        <option value="">Tous les éléments</option>
        <?php foreach ($elements as $e): ?>
            <option value="<?= h($e) ?>" <?= $e === $element ? 'selected' : '' ?>><?= h(ucfirst($e)) ?></option>
        <?php endforeach; ?>
    </select>
    <button type="submit">Filtrer</button>
</form>

<div class="card">
    <?php if ($rows === []): ?>
        <p class="empty">Catalogue vide pour l'instant. Il se remplit automatiquement au démarrage du serveur GMod (une fois la synchro activée).</p>
    <?php else: ?>
    <table>
        <thead>
        <tr>
            <th>Nom</th><th>Catégorie</th><th>Élément</th>
            <th class="num">Chakra</th><th class="num">Cooldown</th><th class="num">Dégâts</th>
            <th>Déblocage</th><th>Prérequis</th>
        </tr>
        </thead>
        <tbody>
        <?php foreach ($rows as $j): ?>
            <tr>
                <td data-label="Nom" class="wrap">
                    <strong><?= h($j['name']) ?></strong>
                    <?php if ($j['description']): ?><br><span style="color:var(--text-dim);font-size:.85em"><?= h($j['description']) ?></span><?php endif; ?>
                </td>
                <td data-label="Catégorie"><?= $j['category'] ? '<span class="badge">' . h($j['category']) . '</span>' : '—' ?></td>
                <td data-label="Élément"><?= h($j['element'] ?: '—') ?></td>
                <td data-label="Chakra" class="num"><?= h($j['chakra']) ?></td>
                <td data-label="Cooldown" class="num"><?= h($j['cooldown']) ?> s</td>
                <td data-label="Dégâts" class="num"><?= $j['damage'] ? h($j['damage']) : '—' ?></td>
                <td data-label="Déblocage"><span class="badge <?= $j['unlock'] === 'auto' ? 'success' : 'warning' ?>"><?= h($j['unlock']) ?></span></td>
                <td data-label="Prérequis" class="wrap"><?= h(requirements_text($j['requirements'])) ?></td>
            </tr>
        <?php endforeach; ?>
        </tbody>
    </table>
    <?php endif; ?>
</div>

<?php page_end(); ?>
