<?php

declare(strict_types=1);

/**
 * GET  /players                -> liste (pagination simple)
 * GET  /players/{steamid}      -> un joueur
 */
final class PlayersController
{
    public static function handle(string $method, array $segments): void
    {
        $db = Database::connection();

        if ($method === 'GET' && $segments === []) {
            $limit = min(max(Request::queryInt('limit', 50), 1), 200);
            $offset = max(Request::queryInt('offset', 0), 0);

            $stmt = $db->prepare('SELECT * FROM players ORDER BY last_seen DESC LIMIT :limit OFFSET :offset');
            $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
            $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
            $stmt->execute();

            Response::ok($stmt->fetchAll());
        }

        if ($method === 'GET' && count($segments) === 1) {
            $stmt = $db->prepare('SELECT * FROM players WHERE steamid = :steamid');
            $stmt->execute(['steamid' => $segments[0]]);
            $row = $stmt->fetch();

            if (!$row) {
                Response::error('Joueur introuvable.', 404);
            }
            Response::ok($row);
        }

        Response::error('Route inconnue.', 404);
    }

    /**
     * Crée/rafraîchit la ligne "players" pour ce steamid. Utilisé en interne par
     * SessionsController (démarrage de session = le joueur est bien là).
     */
    public static function upsert(string $steamid, string $steamName): void
    {
        $db = Database::connection();
        $stmt = $db->prepare(
            'INSERT INTO players (steamid, steam_name, first_seen, last_seen, session_count)
             VALUES (:steamid, :name, NOW(), NOW(), 1)
             ON DUPLICATE KEY UPDATE
                steam_name = VALUES(steam_name),
                last_seen = NOW(),
                session_count = session_count + 1'
        );
        $stmt->execute(['steamid' => $steamid, 'name' => $steamName]);
    }
}
