<?php

declare(strict_types=1);

/**
 * POST /sessions/start  { steamid, steam_name }
 * POST /sessions/end    { steamid }
 * GET  /sessions?steamid=...&limit=...   -> historique (plus récentes d'abord)
 */
final class SessionsController
{
    public static function handle(string $method, array $segments): void
    {
        $db = Database::connection();

        if ($method === 'POST' && ($segments[0] ?? '') === 'start') {
            $data = Request::json();
            Request::requireFields($data, ['steamid']);

            PlayersController::upsert((string) $data['steamid'], (string) ($data['steam_name'] ?? ''));

            $stmt = $db->prepare('INSERT INTO sessions (steamid, connected_at) VALUES (:steamid, NOW())');
            $stmt->execute(['steamid' => $data['steamid']]);

            Response::ok(['session_id' => (int) $db->lastInsertId()], 201);
        }

        if ($method === 'POST' && ($segments[0] ?? '') === 'end') {
            $data = Request::json();
            Request::requireFields($data, ['steamid']);

            // Ferme la session ouverte la plus récente pour ce steamid.
            $stmt = $db->prepare(
                'UPDATE sessions SET disconnected_at = NOW()
                 WHERE steamid = :steamid AND disconnected_at IS NULL
                 ORDER BY connected_at DESC LIMIT 1'
            );
            $stmt->execute(['steamid' => $data['steamid']]);

            $stmt = $db->prepare('UPDATE players SET last_seen = NOW() WHERE steamid = :steamid');
            $stmt->execute(['steamid' => $data['steamid']]);

            Response::ok(['closed' => $stmt->rowCount() >= 0]);
        }

        if ($method === 'GET' && $segments === []) {
            $steamid = Request::query('steamid');
            $limit = min(max(Request::queryInt('limit', 50), 1), 200);

            $sql = 'SELECT * FROM sessions';
            $params = [];
            if ($steamid !== null) {
                $sql .= ' WHERE steamid = :steamid';
                $params['steamid'] = $steamid;
            }
            $sql .= ' ORDER BY connected_at DESC LIMIT :limit';

            $stmt = $db->prepare($sql);
            foreach ($params as $key => $value) {
                $stmt->bindValue(":{$key}", $value);
            }
            $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
            $stmt->execute();

            Response::ok($stmt->fetchAll());
        }

        Response::error('Route inconnue.', 404);
    }
}
