<?php

declare(strict_types=1);

/**
 * POST /characters/sync            -> upsert d'une fiche personnage (identifiée par "steamid")
 * GET  /characters                 -> liste / classement (filtres, dont ?steamid=, + tri)
 * GET  /characters/{id}             -> une fiche par son identifiant de PERSONNAGE (raw_data décodé)
 *
 * "id" identifie le personnage, "steamid" identifie juste son propriétaire :
 * un même steamid peut correspondre à plusieurs lignes (plusieurs personnages).
 * Le jeu n'envoie aujourd'hui qu'un steamid (pas d'identifiant de personnage) :
 * tant qu'il n'en enverra pas un, /characters/sync met à jour la première
 * fiche trouvée pour ce steamid, ou en crée une nouvelle s'il n'y en a aucune.
 *
 * Colonnes connues (typées, indexées) mappées explicitement ; tout le payload
 * est en plus conservé tel quel dans "raw_data" (JSON), pour ne rien perdre
 * même si de nouveaux champs sont ajoutés côté Lua sans toucher à cette API.
 */
final class CharactersController
{
    private const KNOWN_COLUMNS = [
        'firstname', 'lastname', 'gender', 'village', 'clan', 'rank',
        'level', 'xp', 'ryo', 'stat_points', 'deserter', 'origin_village', 'playtime',
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

            Response::ok(['synced' => true, 'id' => (int) $existingId]);
        }

        $cols = array_keys($columns);
        $placeholders = array_map(static fn ($c) => ':' . $c, $cols);
        $stmt = $db->prepare('INSERT INTO characters (' . implode(', ', $cols) . ') VALUES (' . implode(', ', $placeholders) . ')');
        foreach ($columns as $key => $value) {
            $stmt->bindValue(":{$key}", $value);
        }
        $stmt->execute();

        Response::ok(['synced' => true, 'id' => (int) $db->lastInsertId()], 201);
    }

    private static function show(string $id): void
    {
        if (!ctype_digit($id)) {
            Response::error('Identifiant de personnage invalide.', 422);
        }

        $stmt = Database::connection()->prepare('SELECT * FROM characters WHERE id = :id');
        $stmt->execute(['id' => $id]);
        $row = $stmt->fetch();

        if (!$row) {
            Response::error('Personnage introuvable.', 404);
        }

        Response::ok(self::decorate($row));
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

        Response::ok(array_map([self::class, 'decorate'], $stmt->fetchAll()));
    }

    private static function decorate(array $row): array
    {
        if (isset($row['raw_data']) && is_string($row['raw_data'])) {
            $row['raw_data'] = json_decode($row['raw_data'], true);
        }
        return $row;
    }
}
