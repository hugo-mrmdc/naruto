<?php

declare(strict_types=1);

/**
 * POST /characters/sync            -> upsert d'une fiche personnage (identifiée par "steamid")
 * GET  /characters                 -> liste / classement (filtres, dont ?steamid=, + tri)
 * GET  /characters/{id}             -> une fiche par son identifiant de PERSONNAGE (avec ses listes)
 *
 * "id" identifie le personnage, "steamid" identifie juste son propriétaire :
 * un même steamid peut correspondre à plusieurs lignes (plusieurs personnages).
 * Le jeu n'envoie aujourd'hui qu'un steamid (pas d'identifiant de personnage) :
 * tant qu'il n'en enverra pas un, /characters/sync met à jour la première
 * fiche trouvée pour ce steamid, ou en crée une nouvelle s'il n'y en a aucune.
 *
 * Colonnes scalaires connues mappées explicitement sur "characters". Les listes
 * (stats, affinités, jutsu, inventaire, arbre de clan, kekkei genkai...)
 * ont chacune leur table dédiée (character_*), remplacée en entier à chaque sync
 * si la clé correspondante est présente dans le payload (absente = inchangée,
 * [] ou {} = vidée). "raw_data" garde le JSON complet en plus, en garde-fou pour
 * tout ce qui n'a pas encore sa place ici.
 */
final class CharactersController
{
    private const KNOWN_COLUMNS = [
        'firstname', 'lastname', 'gender', 'model', 'skin', 'village', 'clan', 'rank',
        'level', 'xp', 'ryo', 'stat_points', 'deserter', 'origin_village', 'playtime',
    ];

    private const JSON_COLUMNS = ['bodygroups', 'color', 'flags'];

    /** payload key => [table, colonne id, colonne valeur ou null si simple ensemble] */
    private const LIST_TABLES = [
        'stats'      => ['character_stats', 'stat_id', 'value'],
        'affinities' => ['character_affinities', 'element_id', null],
        'kekkei'     => ['character_kekkei', 'kekkei_id', 'level'],
        'jutsus'     => ['character_jutsu', 'jutsu_id', 'level'],
        'clan_tree'  => ['character_clan_tree', 'node_id', null],
    ];

    private const SORTABLE = ['level', 'xp', 'ryo', 'playtime', 'updated_at', 'firstname'];

    public static function handle(string $method, array $segments): void
    {
        if ($method === 'POST' && ($segments[0] ?? '') === 'sync') {
            self::sync();
        }

        if ($method === 'GET' && $segments === []) {
            self::list();
        }

        if ($method === 'GET' && count($segments) === 1) {
            self::show($segments[0]);
        }

        Response::error('Route inconnue.', 404);
    }

    private static function sync(): void
    {
        $data = Request::json();
        Request::requireFields($data, ['steamid']);

        $columns = ['steamid' => (string) $data['steamid']];
        foreach (self::KNOWN_COLUMNS as $col) {
            if (array_key_exists($col, $data)) {
                $value = $data[$col];
                $columns[$col] = is_bool($value) ? (int) $value : $value;
            }
        }
        foreach (self::JSON_COLUMNS as $col) {
            if (array_key_exists($col, $data)) {
                $columns[$col] = json_encode($data[$col], JSON_UNESCAPED_UNICODE);
            }
        }
        // Champs envoyés par le jeu sous un autre nom (data.created / data.lastSeen côté Lua).
        if (array_key_exists('created', $data)) {
            $columns['game_created'] = (int) $data['created'];
        }
        if (array_key_exists('last_seen', $data)) {
            $columns['game_last_seen'] = (int) $data['last_seen'];
        }
        $columns['raw_data'] = json_encode($data, JSON_UNESCAPED_UNICODE);

        $db = Database::connection();

        // "steamid" n'est plus unique (un joueur peut avoir plusieurs personnages) :
        // on cherche une fiche existante pour ce steamid, sinon on en crée une.
        $find = $db->prepare('SELECT id FROM characters WHERE steamid = :steamid ORDER BY id ASC LIMIT 1');
        $find->execute(['steamid' => $columns['steamid']]);
        $existingId = $find->fetchColumn();

        if ($existingId !== false) {
            $set = array_map(static fn ($c) => "{$c} = :{$c}", array_keys($columns));
            $stmt = $db->prepare('UPDATE characters SET ' . implode(', ', $set) . ' WHERE id = :id');
            foreach ($columns as $key => $value) {
                $stmt->bindValue(":{$key}", $value);
            }
            $stmt->bindValue(':id', $existingId, PDO::PARAM_INT);
            $stmt->execute();

            $characterId = (int) $existingId;
            self::syncLists($db, $characterId, $data);
            Response::ok(['synced' => true, 'id' => $characterId]);
        }

        $cols = array_keys($columns);
        $placeholders = array_map(static fn ($c) => ':' . $c, $cols);
        $stmt = $db->prepare('INSERT INTO characters (' . implode(', ', $cols) . ') VALUES (' . implode(', ', $placeholders) . ')');
        foreach ($columns as $key => $value) {
            $stmt->bindValue(":{$key}", $value);
        }
        $stmt->execute();

        $characterId = (int) $db->lastInsertId();
        self::syncLists($db, $characterId, $data);
        Response::ok(['synced' => true, 'id' => $characterId], 201);
    }

    /** Synchronise toutes les tables "liste" déclarées dans LIST_TABLES, plus l'inventaire (2 tables). */
    private static function syncLists(PDO $db, int $characterId, array $data): void
    {
        foreach (self::LIST_TABLES as $key => [$table, $idCol, $valueCol]) {
            if (!array_key_exists($key, $data)) {
                continue;
            }
            self::replaceListTable($db, $table, $idCol, $valueCol, $characterId, $data[$key]);
        }

        $inventory = $data['inventory'] ?? null;
        if (is_array($inventory)) {
            if (array_key_exists('items', $inventory)) {
                self::replaceListTable($db, 'character_inventory', 'item_id', 'quantity', $characterId, $inventory['items']);
            }
            if (array_key_exists('equipped', $inventory)) {
                self::replaceListTable($db, 'character_equipped', 'slot', 'item_id', $characterId, $inventory['equipped']);
            }
        }
    }

    /**
     * Remplace entièrement une table character_* par le contenu envoyé.
     * $valueCol === null : simple ensemble d'identifiants (affinités, arbre de clan).
     * $valueCol fourni    : paire identifiant/valeur (stats, kekkei genkai, jutsu + niveau,
     *                       inventaire, emplacements équipés - valeur numérique ou texte selon la table).
     * Accepte aussi bien une liste (["katon", ...] ou [{id, level}, ...]) qu'une table
     * clé/valeur ({"katon": true, ...} ou {"strength": 12, ...}), pour coller à ce que
     * Lua envoie naturellement selon le champ.
     */
    private static function replaceListTable(PDO $db, string $table, string $idCol, ?string $valueCol, int $characterId, mixed $raw): void
    {
        $db->prepare("DELETE FROM {$table} WHERE character_id = :id")->execute(['id' => $characterId]);

        if (!is_array($raw) || $raw === []) {
            return;
        }

        $pairs = self::extractPairs($raw);
        if ($pairs === []) {
            return;
        }

        if ($valueCol === null) {
            $stmt = $db->prepare("INSERT IGNORE INTO {$table} (character_id, {$idCol}) VALUES (:cid, :val)");
            foreach (array_keys($pairs) as $id) {
                $stmt->execute(['cid' => $characterId, 'val' => $id]);
            }
            return;
        }

        $stmt = $db->prepare("INSERT INTO {$table} (character_id, {$idCol}, {$valueCol}) VALUES (:cid, :k, :v)");
        foreach ($pairs as $id => $value) {
            $stmt->execute(['cid' => $characterId, 'k' => $id, 'v' => $value]);
        }
    }

    /**
     * Ramène n'importe quelle forme envoyée à une table [identifiant => valeur] :
     *   ["katon", "raiton"]                    -> ["katon" => 1, "raiton" => 1]
     *   [{"id":"mokuton","level":3}, ...]       -> ["mokuton" => 3, ...]
     *   {"strength": 12, "uchiha_x": true}      -> ["strength" => 12, "uchiha_x" => 1]
     *   {"1": "kunai", "2": "shuriken"}         -> ["1" => "kunai", "2" => "shuriken"] (emplacements)
     */
    private static function extractPairs(array $raw): array
    {
        $isList = array_keys($raw) === range(0, count($raw) - 1);
        $out = [];

        if (!$isList) {
            foreach ($raw as $key => $value) {
                $out[(string) $key] = self::scalarValue($value);
            }
            return $out;
        }

        foreach ($raw as $item) {
            if (is_scalar($item)) {
                $out[(string) $item] = 1;
                continue;
            }
            if (is_array($item)) {
                $id = (string) ($item['id'] ?? '');
                if ($id === '') continue;
                $out[$id] = self::scalarValue($item['level'] ?? $item['stage'] ?? $item['value'] ?? $item['qty'] ?? 1);
            }
        }
        return $out;
    }

    private static function scalarValue(mixed $value): int|string
    {
        if (is_bool($value)) return $value ? 1 : 0;
        if (is_array($value)) return $value['level'] ?? $value['stage'] ?? $value['value'] ?? 1;
        return $value;
    }

    private static function show(string $id): void
    {
        if (!ctype_digit($id)) {
            Response::error('Identifiant de personnage invalide.', 422);
        }

        $db = Database::connection();
        $stmt = $db->prepare('SELECT * FROM characters WHERE id = :id');
        $stmt->execute(['id' => $id]);
        $row = $stmt->fetch();

        if (!$row) {
            Response::error('Personnage introuvable.', 404);
        }

        Response::ok(self::decorate($db, $row));
    }

    private static function list(): void
    {
        $sort = Request::query('sort', 'level');
        if (!in_array($sort, self::SORTABLE, true)) {
            $sort = 'level';
        }
        $order = strtoupper((string) Request::query('order', 'DESC')) === 'ASC' ? 'ASC' : 'DESC';
        $limit = min(max(Request::queryInt('limit', 50), 1), 200);
        $offset = max(Request::queryInt('offset', 0), 0);

        $where = [];
        $params = [];
        foreach (['village', 'clan', 'rank', 'steamid'] as $filter) {
            $value = Request::query($filter);
            if ($value !== null) {
                $where[] = "{$filter} = :{$filter}";
                $params[$filter] = $value;
            }
        }

        $sql = 'SELECT * FROM characters';
        if ($where !== []) {
            $sql .= ' WHERE ' . implode(' AND ', $where);
        }
        $sql .= " ORDER BY {$sort} {$order} LIMIT :limit OFFSET :offset";

        $db = Database::connection();
        $stmt = $db->prepare($sql);
        foreach ($params as $key => $value) {
            $stmt->bindValue(":{$key}", $value);
        }
        $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
        $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
        $stmt->execute();

        // Liste : pas de sous-tables ici (coûteux en N+1), juste la fiche de base.
        Response::ok(array_map(static fn ($row) => self::decodeJson($row), $stmt->fetchAll()));
    }

    /** Fiche complète : colonnes JSON décodées + toutes les listes character_*. */
    private static function decorate(PDO $db, array $row): array
    {
        $row = self::decodeJson($row);
        $id = $row['id'];

        foreach (self::LIST_TABLES as $key => [$table, $idCol, $valueCol]) {
            $cols = $valueCol === null ? $idCol : "{$idCol}, {$valueCol}";
            $stmt = $db->prepare("SELECT {$cols} FROM {$table} WHERE character_id = :id ORDER BY {$idCol}");
            $stmt->execute(['id' => $id]);
            $row[$key] = $valueCol === null
                ? $stmt->fetchAll(PDO::FETCH_COLUMN)
                : $stmt->fetchAll();
        }

        $items = $db->prepare('SELECT item_id, quantity FROM character_inventory WHERE character_id = :id ORDER BY item_id');
        $items->execute(['id' => $id]);
        $equipped = $db->prepare('SELECT slot, item_id FROM character_equipped WHERE character_id = :id ORDER BY slot');
        $equipped->execute(['id' => $id]);
        $row['inventory'] = [
            'items'    => $items->fetchAll(),
            'equipped' => $equipped->fetchAll(),
        ];

        return $row;
    }

    private static function decodeJson(array $row): array
    {
        foreach (['raw_data', 'bodygroups', 'color', 'flags'] as $col) {
            if (isset($row[$col]) && is_string($row[$col])) {
                $row[$col] = json_decode($row[$col], true);
            }
        }
        return $row;
    }
}
