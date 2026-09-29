<?php

declare(strict_types=1);

require __DIR__ . '/_bootstrap.php';

// Deux façons d'arriver ici : un id de personnage précis (depuis le classement),
// ou un steamid (depuis le journal, qui ne connaît que le joueur
// visé — un même steamid pouvant correspondre à plusieurs personnages).
$id = trim((string) ($_GET['id'] ?? ''));
$steamidParam = trim((string) ($_GET['steamid'] ?? ''));

$char = [];
$candidates = [];

if ($id !== '' && ctype_digit($id)) {
    $char = db_try(static function (PDO $db) use ($id): array {
        $stmt = $db->prepare('SELECT * FROM characters WHERE id = :id');
        $stmt->execute(['id' => $id]);
        return $stmt->fetch() ?: [];
    });
} elseif ($steamidParam !== '') {
    $candidates = db_try(static function (PDO $db) use ($steamidParam): array {
        $stmt = $db->prepare('SELECT * FROM characters WHERE steamid = :steamid ORDER BY id ASC');
        $stmt->execute(['steamid' => $steamidParam]);
        return $stmt->fetchAll();
    });
    if (count($candidates) === 1) {
        $char = $candidates[0];
    }
}

$playerSteamid = $char['steamid'] ?? $steamidParam;
$player = db_try(static function (PDO $db) use ($playerSteamid): array {
    if ($playerSteamid === '') return [];
    $stmt = $db->prepare('SELECT * FROM players WHERE steamid = :steamid');
    $stmt->execute(['steamid' => $playerSteamid]);
    return $stmt->fetch() ?: [];
});

// Ce qui a sa propre table character_* : id, libellé pour l'affichage, et nom
// de la colonne "valeur" quand il y en a une (niveau, stade...).
const LIST_SECTIONS = [
    ['label' => 'Statistiques allouées', 'table' => 'character_stats', 'id' => 'stat_id', 'value' => 'value', 'suffix' => 'pt(s)'],
    ['label' => 'Affinités', 'table' => 'character_affinities', 'id' => 'element_id', 'value' => null],
    ['label' => 'Kekkei Genkai', 'table' => 'character_kekkei', 'id' => 'kekkei_id', 'value' => 'level', 'suffix' => 'niv.'],
    ['label' => 'Dōjutsu', 'table' => 'character_dojutsu', 'id' => 'dojutsu_id', 'value' => 'stage', 'suffix' => 'stade'],
    ['label' => 'Jutsu connus', 'table' => 'character_jutsu', 'id' => 'jutsu_id', 'value' => null],
    ['label' => 'Arbre de clan débloqué', 'table' => 'character_clan_tree', 'id' => 'node_id', 'value' => null],
];

$lists = [];
foreach (LIST_SECTIONS as $section) {
    $lists[$section['table']] = db_try(static function (PDO $db) use ($char, $section): array {
        if (!isset($char['id'])) return [];
        $cols = $section['value'] ? "{$section['id']}, {$section['value']}" : $section['id'];
        $stmt = $db->prepare("SELECT {$cols} FROM {$section['table']} WHERE character_id = :id ORDER BY {$section['id']}");
        $stmt->execute(['id' => $char['id']]);
        return $stmt->fetchAll();
    });
}

$inventory = db_try(static function (PDO $db) use ($char): array {
    if (!isset($char['id'])) return [];
    $stmt = $db->prepare('SELECT item_id, quantity FROM character_inventory WHERE character_id = :id ORDER BY item_id');
    $stmt->execute(['id' => $char['id']]);
    return $stmt->fetchAll();
});
$equipped = db_try(static function (PDO $db) use ($char): array {
    if (!isset($char['id'])) return [];
    $stmt = $db->prepare('SELECT slot, item_id FROM character_equipped WHERE character_id = :id ORDER BY slot');
    $stmt->execute(['id' => $char['id']]);
    return $stmt->fetchAll();
});
$loadout = db_try(static function (PDO $db) use ($char): array {
    if (!isset($char['id'])) return [];
    $stmt = $db->prepare('SELECT slot, jutsu_id FROM character_loadout WHERE character_id = :id ORDER BY slot');
    $stmt->execute(['id' => $char['id']]);
    return $stmt->fetchAll();
});

$bodygroups = (isset($char['bodygroups']) && is_string($char['bodygroups'])) ? (json_decode($char['bodygroups'], true) ?: []) : [];
$color = (isset($char['color']) && is_string($char['color'])) ? (json_decode($char['color'], true) ?: []) : [];
$flags = (isset($char['flags']) && is_string($char['flags'])) ? (json_decode($char['flags'], true) ?: []) : [];

$raw = [];
if (isset($char['raw_data']) && is_string($char['raw_data'])) {
    $raw = json_decode($char['raw_data'], true) ?: [];
}

// Champs déjà affichés ailleurs sur la page : pas la peine de les répéter dans
// le bloc générique plus bas (qui ne sert plus qu'aux champs pas encore prévus).
$HEADER_KEYS = [
    'steamid', 'firstname', 'lastname', 'village', 'clan', 'rank', 'level', 'xp',
    'ryo', 'stat_points', 'deserter', 'origin_village', 'playtime', 'created', 'last_seen',
    'model', 'skin', 'bodygroups', 'color', 'flags', 'inventory',
    'stats', 'affinities', 'kekkei', 'dojutsu', 'jutsus', 'clan_tree', 'loadout',
];

/** Rend n'importe quelle valeur JSON (scalaire, liste, ou table clé/valeur) de façon lisible. */
function render_value(mixed $value): string
{
    if ($value === null) return '<span class="empty" style="padding:0">—</span>';
    if (is_bool($value)) return $value ? 'oui' : 'non';
    if (is_scalar($value)) return h((string) $value);

    if (is_array($value)) {
        if ($value === []) return '<span class="empty" style="padding:0">—</span>';

        $isList = array_keys($value) === range(0, count($value) - 1);
        if ($isList) {
            // Liste de scalaires -> pastilles ; liste de tables -> une ligne par entrée
            if (is_scalar($value[0] ?? null)) {
                $pills = array_map(static fn ($v) => '<span class="badge">' . h((string) $v) . '</span>', $value);
                return '<div class="pill-row">' . implode('', $pills) . '</div>';
            }
            $out = '<table>';
            foreach ($value as $item) {
                $out .= '<tr><td class="wrap">' . render_value($item) . '</td></tr>';
            }
            return $out . '</table>';
        }

        // Table clé/valeur
        $out = '<table>';
        foreach ($value as $k => $v) {
            $out .= '<tr><td>' . h((string) $k) . '</td><td class="wrap">' . render_value($v) . '</td></tr>';
        }
        return $out . '</table>';
    }

    return h((string) $value);
}

function pretty_label(string $key): string
{
    $labels = [
        'gender' => 'Genre', 'model' => 'Modèle', 'skin' => 'Skin', 'bodygroups' => 'Bodygroups',
        'color' => 'Couleur', 'affinities' => 'Affinités', 'flags' => 'Flags',
        'clan_tree' => 'Arbre de clan débloqué', 'dojutsu' => 'Dōjutsu', 'inventory' => 'Inventaire',
        'jutsus' => 'Jutsu connus', 'loadout' => 'Emplacements de jutsu', 'reputation' => 'Réputation',
        'stats' => 'Statistiques allouées',
    ];
    return $labels[$key] ?? ucfirst(str_replace('_', ' ', $key));
}

page_start('Fiche personnage');
?>

<a class="back-link" href="characters.php">&larr; Retour au classement</a>

<?php if ($char === [] && count($candidates) > 1): ?>
    <div class="card">
        <h2>Plusieurs personnages pour ce joueur</h2>
        <table>
            <thead><tr><th>Personnage</th><th>Village</th><th>Clan</th><th class="num">Niveau</th></tr></thead>
            <tbody>
            <?php foreach ($candidates as $c): ?>
                <tr>
                    <td data-label="Personnage"><a href="character.php?id=<?= (int) $c['id'] ?>"><?= h(trim($c['firstname'] . ' ' . $c['lastname'])) ?: '#' . $c['id'] ?></a></td>
                    <td data-label="Village"><?= h($c['village'] ?: '—') ?></td>
                    <td data-label="Clan"><?= h($c['clan'] ?: '—') ?></td>
                    <td data-label="Niveau" class="num"><?= h($c['level']) ?></td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
    </div>
<?php elseif ($char === []): ?>
    <div class="card"><p class="empty">Personnage introuvable (<?= h($id !== '' ? "id {$id}" : ($steamidParam ?: 'aucun identifiant fourni')) ?>).</p></div>
<?php else: ?>

    <div class="card">
        <h2><?= h(trim($char['firstname'] . ' ' . $char['lastname'])) ?: '#' . h($char['id']) ?>
            <small>#<?= h($char['id']) ?> — <?= h($char['steamid']) ?></small>
        </h2>
        <div class="kv">
            <div><span class="k">Village</span><span class="v"><?= h($char['village'] ?: '—') ?></span></div>
            <div><span class="k">Clan</span><span class="v"><?= h($char['clan'] ?: '—') ?></span></div>
            <div><span class="k">Grade</span><span class="v"><?= h($char['rank'] ?: '—') ?></span></div>
            <div><span class="k">Niveau</span><span class="v"><?= h($char['level']) ?></span></div>
            <div><span class="k">XP</span><span class="v"><?= fmt_num($char['xp']) ?></span></div>
            <div><span class="k">Ryo</span><span class="v"><?= fmt_num($char['ryo']) ?></span></div>
            <div><span class="k">Points de stats</span><span class="v"><?= h($char['stat_points']) ?></span></div>
            <div><span class="k">Temps de jeu</span><span class="v"><?= h(fmt_playtime((int) $char['playtime'])) ?></span></div>
            <div><span class="k">Déserteur</span><span class="v">
                <?php if ($char['deserter']): ?><span class="badge danger">oui — <?= h($char['origin_village'] ?: '?') ?></span>
                <?php else: ?>non<?php endif; ?>
            </span></div>
            <div><span class="k">Créé le (jeu)</span><span class="v"><?= $char['game_created'] ? h(date('d/m/Y', (int) $char['game_created'])) : '—' ?></span></div>
            <div><span class="k">Dernière sync</span><span class="v"><?= h(fmt_date($char['updated_at'])) ?></span></div>
            <?php if ($char['model']): ?>
                <div><span class="k">Modèle</span><span class="v"><?= h($char['model']) ?><?= $char['skin'] ? ' (skin ' . h($char['skin']) . ')' : '' ?></span></div>
            <?php endif; ?>
            <?php if ($player !== []): ?>
                <div><span class="k">Pseudo Steam</span><span class="v"><?= h($player['steam_name'] ?: '—') ?></span></div>
                <div><span class="k">Sessions</span><span class="v"><?= h($player['session_count']) ?></span></div>
            <?php endif; ?>
        </div>
    </div>

    <?php foreach (LIST_SECTIONS as $section): ?>
        <?php $rows = $lists[$section['table']]; if ($rows === []) continue; ?>
        <div class="card">
            <h2><?= h($section['label']) ?></h2>
            <div class="pill-row">
                <?php foreach ($rows as $row): ?>
                    <?php if ($section['value']): ?>
                        <span class="badge accent"><?= h(ucfirst((string) $row[$section['id']])) ?> — <?= h($section['suffix'] ?? '') ?> <?= h($row[$section['value']]) ?></span>
                    <?php else: ?>
                        <span class="badge"><?= h($row[$section['id']]) ?></span>
                    <?php endif; ?>
                <?php endforeach; ?>
            </div>
        </div>
    <?php endforeach; ?>

    <?php if ($inventory !== [] || $equipped !== []): ?>
        <div class="card">
            <h2>Inventaire</h2>
            <?php if ($equipped !== []): ?>
                <p><strong>Équipé :</strong></p>
                <div class="pill-row">
                    <?php foreach ($equipped as $e): ?>
                        <span class="badge accent"><?= h($e['slot']) ?> : <?= h($e['item_id']) ?></span>
                    <?php endforeach; ?>
                </div>
            <?php endif; ?>
            <?php if ($inventory !== []): ?>
                <table>
                    <thead><tr><th>Objet</th><th class="num">Quantité</th></tr></thead>
                    <tbody>
                    <?php foreach ($inventory as $item): ?>
                        <tr><td data-label="Objet"><?= h($item['item_id']) ?></td><td data-label="Quantité" class="num"><?= fmt_num($item['quantity']) ?></td></tr>
                    <?php endforeach; ?>
                    </tbody>
                </table>
            <?php endif; ?>
        </div>
    <?php endif; ?>

    <?php if ($loadout !== []): ?>
        <div class="card">
            <h2>Emplacements de jutsu (barre de raccourcis)</h2>
            <div class="pill-row">
                <?php foreach ($loadout as $l): ?>
                    <span class="badge"><?= h($l['slot']) ?> : <?= h($l['jutsu_id']) ?></span>
                <?php endforeach; ?>
            </div>
        </div>
    <?php endif; ?>

    <?php if ($bodygroups !== [] || $color !== []): ?>
        <div class="card">
            <h2>Apparence</h2>
            <?= render_value(array_filter(['bodygroups' => $bodygroups ?: null, 'color' => $color ?: null])) ?>
        </div>
    <?php endif; ?>

    <?php if ($flags !== []): ?>
        <div class="card">
            <h2>Flags</h2>
            <?= render_value($flags) ?>
        </div>
    <?php endif; ?>

    <?php foreach ($raw as $key => $value): ?>
        <?php if (in_array($key, $HEADER_KEYS, true)) continue; ?>
        <div class="card">
            <h2><?= h(pretty_label((string) $key)) ?></h2>
            <?= render_value($value) ?>
        </div>
    <?php endforeach; ?>

<?php endif; ?>

<?php page_end(); ?>
