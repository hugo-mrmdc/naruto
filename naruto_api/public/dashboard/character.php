<?php

declare(strict_types=1);

require __DIR__ . '/_bootstrap.php';

// Deux façons d'arriver ici : un id de personnage précis (depuis le classement),
// ou un steamid (depuis les primes/le journal, qui ne connaissent que le joueur
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

$kekei = db_try(static function (PDO $db) use ($char): array {
    if (!isset($char['id'])) return [];
    $stmt = $db->prepare('SELECT kekei_id, level FROM character_kekei WHERE character_id = :id ORDER BY kekei_id');
    $stmt->execute(['id' => $char['id']]);
    return $stmt->fetchAll();
});

$raw = [];
if (isset($char['raw_data']) && is_string($char['raw_data'])) {
    $raw = json_decode($char['raw_data'], true) ?: [];
}

// Champs déjà affichés dans l'en-tête : pas la peine de les répéter plus bas.
$HEADER_KEYS = [
    'steamid', 'firstname', 'lastname', 'village', 'clan', 'rank', 'level', 'xp',
    'ryo', 'stat_points', 'deserter', 'origin_village', 'playtime', 'created', 'last_seen',
    'kekkei', // affiché séparément via la table dédiée character_kekei
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
            <?php if ($player !== []): ?>
                <div><span class="k">Pseudo Steam</span><span class="v"><?= h($player['steam_name'] ?: '—') ?></span></div>
                <div><span class="k">Sessions</span><span class="v"><?= h($player['session_count']) ?></span></div>
            <?php endif; ?>
        </div>
    </div>

    <?php if ($kekei !== []): ?>
        <div class="card">
            <h2>Kekkei Genkai</h2>
            <div class="pill-row">
                <?php foreach ($kekei as $k): ?>
                    <span class="badge accent"><?= h(ucfirst($k['kekei_id'])) ?> — niv. <?= h($k['level']) ?></span>
                <?php endforeach; ?>
            </div>
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
