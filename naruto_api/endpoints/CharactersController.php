<?php

declare(strict_types=1);

/**
 * POST /characters/sync        -> upsert complet d'une fiche personnage
 * GET  /characters              -> liste / classement (filtres + tri)
 * GET  /characters/{steamid}    -> une fiche (raw_data décodé)
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
        $cols = array_keys($columns);
        $placeholders = array_map(static fn ($c) => ':' . $c, $cols);
        $updates = array_map(static fn ($c) => "{$c} = VALUES({$c})", array_filter($cols, static fn ($c) => $c !== 'steamid'));

        $sql = sprintf(
            'INSERT INTO characters (%s) VALUES (%s) ON DUPLICATE KEY UPDATE %s',
            implode(', ', $cols),
            implode(', ', $placeholders),
            implode(', ', $updates)
        );

        $stmt = $db->prepare($sql);
        foreach ($columns as $key => $value) {
            $stmt->bindValue(":{$key}", $value);
        }
        $stmt->execute();

        Response::ok(['synced' => true]);
    }

    private static function show(string $steamid): void
    {
        $stmt = Database::connection()->prepare('SELECT * FROM characters WHERE steamid = :steamid');
        $stmt->execute(['steamid' => $steamid]);
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
        foreach (['village', 'clan', 'rank'] as $filter) {
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
