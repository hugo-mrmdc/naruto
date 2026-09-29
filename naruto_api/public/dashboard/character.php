<?php

declare(strict_types=1);

require __DIR__ . '/_bootstrap.php';

$steamid = trim((string) ($_GET['steamid'] ?? ''));

$char = db_try(static function (PDO $db) use ($steamid): array {
    if ($steamid === '') return [];
    $stmt = $db->prepare('SELECT * FROM characters WHERE steamid = :steamid');
    $stmt->execute(['steamid' => $steamid]);
    $row = $stmt->fetch();
    return $row ?: [];
});

$player = db_try(static function (PDO $db) use ($steamid): array {
    if ($steamid === '') return [];
    $stmt = $db->prepare('SELECT * FROM players WHERE steamid = :steamid');
    $stmt->execute(['steamid' => $steamid]);
    return $stmt->fetch() ?: [];
});

$raw = [];
if (isset($char['raw_data']) && is_string($char['raw_data'])) {
    $raw = json_decode($char['raw_data'], true) ?: [];
}

// Champs déjà affichés dans l'en-tête : pas la peine de les répéter plus bas.
$HEADER_KEYS = [
    'steamid', 'firstname', 'lastname', 'village', 'clan', 'rank', 'level', 'xp',
    'ryo', 'stat_points', 'deserter', 'origin_village', 'playtime', 'created', 'last_seen',
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

<?php if ($char === []): ?>
    <div class="card"><p class="empty">Personnage introuvable (<?= h($steamid ?: 'aucun identifiant fourni') ?>).</p></div>
<?php else: ?>

    <div class="card">
        <h2><?= h(trim($char['firstname'] . ' ' . $char['lastname'])) ?: h($char['steamid']) ?>
            <small><?= h($char['steamid']) ?></small>
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

    <?php foreach ($raw as $key => $value): ?>
        <?php if (in_array($key, $HEADER_KEYS, true)) continue; ?>
        <div class="card">
            <h2><?= h(pretty_label((string) $key)) ?></h2>
            <?= render_value($value) ?>
        </div>
    <?php endforeach; ?>

<?php endif; ?>

<?php page_end(); ?>
