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

// Tables enfants d'un personnage : nom de table => colonne qui identifie une ligne.
const CHILD_TABLES = [
    'character_stats' => 'stat_id', 'character_affinities' => 'element_id', 'character_kekkei' => 'kekkei_id',
    'character_jutsu' => 'jutsu_id', 'character_clan_tree' => 'node_id',
    'character_inventory' => 'item_id', 'character_equipped' => 'slot',
];

$flash = null;
$isSuper = DashboardAuth::isSuperAdmin();

// Modifications / suppressions : réservées aux super admins (+ jeton CSRF).
// Attention : le serveur GMod ré-écrase la fiche à sa prochaine synchro
// (sauvegarde du personnage) — les changements faits ici ne survivent que si le
// jeu est aussi mis à jour de son côté.
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    DashboardAuth::requireSuperAdmin();
    DashboardAuth::checkCsrf();

    $db = Database::connection();
    $charId = (int) ($_POST['character_id'] ?? 0);
    $action = (string) ($_POST['action'] ?? '');
    $exists = $db->prepare('SELECT COUNT(*) FROM characters WHERE id = :id');
    $exists->execute(['id' => $charId]);

    if (!$exists->fetchColumn()) {
        $flash = ['error', 'Personnage introuvable.'];
    } elseif ($action === 'update') {
        $text = static fn (string $k, int $max): string => mb_substr(trim((string) ($_POST[$k] ?? '')), 0, $max);
        $int = static fn (string $k): int => (int) ($_POST[$k] ?? 0);
        $db->prepare(
            'UPDATE characters SET firstname = :firstname, lastname = :lastname, village = :village, clan = :clan,
                    `rank` = :rank, level = :level, xp = :xp, ryo = :ryo, stat_points = :stat_points,
                    deserter = :deserter, origin_village = :origin_village
             WHERE id = :id'
        )->execute([
            'firstname' => $text('firstname', 64), 'lastname' => $text('lastname', 64),
            'village' => $text('village', 32), 'clan' => $text('clan', 32), 'rank' => $text('rank', 32),
            'level' => max(1, $int('level')), 'xp' => max(0, $int('xp')), 'ryo' => max(0, $int('ryo')),
            'stat_points' => max(0, $int('stat_points')),
            'deserter' => isset($_POST['deserter']) ? 1 : 0,
            'origin_village' => $text('origin_village', 32),
            'id' => $charId,
        ]);
        $flash = ['success', 'Personnage mis à jour.'];
    } elseif ($action === 'delete_entry') {
        $table = (string) ($_POST['table'] ?? '');
        if (!isset(CHILD_TABLES[$table])) {
            $flash = ['error', 'Table inconnue.'];
        } else {
            $col = CHILD_TABLES[$table];
            $db->prepare("DELETE FROM {$table} WHERE character_id = :id AND {$col} = :key")
                ->execute(['id' => $charId, 'key' => (string) ($_POST['key'] ?? '')]);
            $flash = ['success', 'Entrée supprimée.'];
        }
    } elseif ($action === 'delete_character') {
        $db->beginTransaction();
        foreach (array_keys(CHILD_TABLES) as $table) {
            $db->prepare("DELETE FROM {$table} WHERE character_id = :id")->execute(['id' => $charId]);
        }
        $db->prepare('DELETE FROM characters WHERE id = :id')->execute(['id' => $charId]);
        $db->commit();
        header('Location: characters.php');
        exit;
    } else {
        $flash = ['error', 'Action inconnue.'];
    }

    $id = (string) $charId; // ré-affiche la fiche modifiée
}

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
    ['label' => 'Jutsu connus', 'table' => 'character_jutsu', 'id' => 'jutsu_id', 'value' => 'level', 'suffix' => 'niv.', 'joinJutsu' => true],
    ['label' => 'Arbre de clan débloqué', 'table' => 'character_clan_tree', 'id' => 'node_id', 'value' => null],
];

$lists = [];
foreach (LIST_SECTIONS as $section) {
    $lists[$section['table']] = db_try(static function (PDO $db) use ($char, $section): array {
        if (!isset($char['id'])) return [];
        if (!empty($section['joinJutsu'])) {
            $valueCol = $section['value'] ? ", t.{$section['value']} AS jlevel" : '';
            $stmt = $db->prepare(
                "SELECT t.{$section['id']} AS jid{$valueCol}, jd.name AS jname
                 FROM {$section['table']} t LEFT JOIN jutsu_definitions jd ON jd.jutsu_id = t.{$section['id']}
                 WHERE t.character_id = :id ORDER BY t.{$section['id']}"
            );
            $stmt->execute(['id' => $char['id']]);
            return $stmt->fetchAll();
        }
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
        'clan_tree' => 'Arbre de clan débloqué', 'inventory' => 'Inventaire',
        'jutsus' => 'Jutsu connus', 'reputation' => 'Réputation',
        'stats' => 'Statistiques allouées',
    ];
    return $labels[$key] ?? ucfirst(str_replace('_', ' ', $key));
}

/** Petit bouton "✕" (super admin) qui supprime une ligne d'une table enfant. */
function delete_entry_form(int $charId, string $table, string $key): string
{
    if (!DashboardAuth::isSuperAdmin()) return '';
    return '<form method="post" style="display:inline" onsubmit="return confirm(\'Supprimer cette entrée ?\')">'
        . '<input type="hidden" name="csrf" value="' . h(DashboardAuth::csrfToken()) . '">'
        . '<input type="hidden" name="action" value="delete_entry">'
        . '<input type="hidden" name="character_id" value="' . $charId . '">'
        . '<input type="hidden" name="table" value="' . h($table) . '">'
        . '<input type="hidden" name="key" value="' . h($key) . '">'
        . '<button type="submit" class="badge danger" style="border:none;cursor:pointer" title="Supprimer">✕</button></form>';
}

page_start('Fiche personnage');
?>

<a class="back-link" href="characters.php">&larr; Retour au classement</a>

<?php if ($flash): ?>
    <p class="<?= $flash[0] === 'success' ? 'msg-success' : 'msg-error' ?>"><?= h($flash[1]) ?></p>
<?php endif; ?>

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

    <?php if ($isSuper): ?>
    <div class="card">
        <details>
            <summary><strong>Modifier / supprimer (super admin)</strong></summary>
            <form method="post" style="margin-top:12px">
                <input type="hidden" name="csrf" value="<?= h(DashboardAuth::csrfToken()) ?>">
                <input type="hidden" name="action" value="update">
                <input type="hidden" name="character_id" value="<?= (int) $char['id'] ?>">
                <div class="kv">
                    <?php foreach ([
                        'firstname' => 'Prénom', 'lastname' => 'Nom', 'village' => 'Village', 'clan' => 'Clan',
                        'rank' => 'Grade', 'origin_village' => "Village d'origine",
                    ] as $field => $label): ?>
                        <div><span class="k"><?= h($label) ?></span><input type="text" name="<?= h($field) ?>" value="<?= h($char[$field]) ?>"></div>
                    <?php endforeach; ?>
                    <?php foreach ([
                        'level' => 'Niveau', 'xp' => 'XP', 'ryo' => 'Ryo', 'stat_points' => 'Points de stats',
                    ] as $field => $label): ?>
                        <div><span class="k"><?= h($label) ?></span><input type="number" name="<?= h($field) ?>" value="<?= h($char[$field]) ?>"></div>
                    <?php endforeach; ?>
                    <div><span class="k">Déserteur</span><label><input type="checkbox" name="deserter" <?= $char['deserter'] ? 'checked' : '' ?>> oui</label></div>
                </div>
                <p><button type="submit">Enregistrer</button></p>
            </form>
            <form method="post" onsubmit="return confirm('Supprimer définitivement ce personnage et toutes ses données ?')">
                <input type="hidden" name="csrf" value="<?= h(DashboardAuth::csrfToken()) ?>">
                <input type="hidden" name="action" value="delete_character">
                <input type="hidden" name="character_id" value="<?= (int) $char['id'] ?>">
                <button type="submit" class="badge danger" style="border:none;cursor:pointer">Supprimer ce personnage</button>
            </form>
            <p style="color:var(--text-dim);font-size:.85rem">Le serveur GMod ré-écrase la fiche à sa prochaine synchronisation : ces changements ne durent que s'ils sont aussi faits en jeu.</p>
        </details>
    </div>
    <?php endif; ?>

    <?php foreach (LIST_SECTIONS as $section): ?>
        <?php $rows = $lists[$section['table']]; if ($rows === []) continue; ?>
        <div class="card">
            <h2><?= h($section['label']) ?></h2>
            <div class="pill-row">
                <?php foreach ($rows as $row): ?>
                    <?php if (!empty($section['joinJutsu'])): ?>
                        <span class="badge accent" <?= $row['jname'] ? 'title="' . h($row['jid']) . '"' : '' ?>><?= h($row['jname'] ?: $row['jid']) ?><?php if ($section['value']): ?> — <?= h($section['suffix'] ?? '') ?> <?= h($row['jlevel']) ?><?php endif; ?> <?= delete_entry_form((int) $char['id'], $section['table'], (string) $row['jid']) ?></span>
                    <?php elseif ($section['value']): ?>
                        <span class="badge accent"><?= h(ucfirst((string) $row[$section['id']])) ?> — <?= h($section['suffix'] ?? '') ?> <?= h($row[$section['value']]) ?> <?= delete_entry_form((int) $char['id'], $section['table'], (string) $row[$section['id']]) ?></span>
                    <?php else: ?>
                        <span class="badge"><?= h($row[$section['id']]) ?> <?= delete_entry_form((int) $char['id'], $section['table'], (string) $row[$section['id']]) ?></span>
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
                        <span class="badge accent"><?= h($e['slot']) ?> : <?= h($e['item_id']) ?> <?= delete_entry_form((int) $char['id'], 'character_equipped', (string) $e['slot']) ?></span>
                    <?php endforeach; ?>
                </div>
            <?php endif; ?>
            <?php if ($inventory !== []): ?>
                <table>
                    <thead><tr><th>Objet</th><th class="num">Quantité</th><?php if ($isSuper): ?><th></th><?php endif; ?></tr></thead>
                    <tbody>
                    <?php foreach ($inventory as $item): ?>
                        <tr><td data-label="Objet"><?= h($item['item_id']) ?></td><td data-label="Quantité" class="num"><?= fmt_num($item['quantity']) ?></td><?php if ($isSuper): ?><td><?= delete_entry_form((int) $char['id'], 'character_inventory', (string) $item['item_id']) ?></td><?php endif; ?></tr>
                    <?php endforeach; ?>
                    </tbody>
                </table>
            <?php endif; ?>
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
