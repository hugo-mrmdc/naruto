<?php

declare(strict_types=1);

/**
 * Registre de bans côté site web (historique / modération RP).
 * INDÉPENDANT du blocage réel des joueurs, qui reste géré par ton addon
 * admin GMod (ULX, SAM...) — cette table ne fait qu'archiver/afficher.
 *
 * POST  /bans           { steamid, reason, admin_steamid?, admin_name?, expires_at? (ISO8601, null = permanent) }
 * PATCH /bans/{id}       { lifted_by }   -> marque le ban comme levé
 * GET   /bans?steamid=&active=1
 */
final class BansController
{
    public static function handle(string $method, array $segments): void
    {
        $db = Database::connection();

        if ($method === 'POST' && $segments === []) {
            $data = Request::json();
            Request::requireFields($data, ['steamid', 'reason']);

            $stmt = $db->prepare(
                'INSERT INTO bans (steamid, reason, admin_steamid, admin_name, expires_at, active)
                 VALUES (:steamid, :reason, :admin_steamid, :admin_name, :expires_at, 1)'
            );
            $stmt->execute([
                'steamid'       => (string) $data['steamid'],
                'reason'        => (string) $data['reason'],
                'admin_steamid' => (string) ($data['admin_steamid'] ?? ''),
                'admin_name'    => (string) ($data['admin_name'] ?? ''),
                'expires_at'    => isset($data['expires_at']) ? date('Y-m-d H:i:s', strtotime((string) $data['expires_at'])) : null,
            ]);

            Response::ok(['id' => (int) $db->lastInsertId()], 201);
        }

        if ($method === 'PATCH' && count($segments) === 1) {
            $data = Request::json();
            $stmt = $db->prepare(
                'UPDATE bans SET active = 0, lifted_at = NOW(), lifted_by = :lifted_by WHERE id = :id'
            );
            $stmt->execute(['lifted_by' => (string) ($data['lifted_by'] ?? ''), 'id' => (int) $segments[0]]);

            Response::ok(['updated' => $stmt->rowCount() > 0]);
        }

        if ($method === 'GET' && $segments === []) {
            $where = [];
            $params = [];

            $steamid = Request::query('steamid');
            if ($steamid !== null) {
                $where[] = 'steamid = :steamid';
                $params['steamid'] = $steamid;
            }
            $active = Request::query('active');
            if ($active !== null) {
                $where[] = 'active = :active';
                $params['active'] = $active === '1' ? 1 : 0;
            }

            $sql = 'SELECT * FROM bans';
            if ($where !== []) {
                $sql .= ' WHERE ' . implode(' AND ', $where);
            }
            $sql .= ' ORDER BY created_at DESC';

            $stmt = $db->prepare($sql);
            $stmt->execute($params);
            Response::ok($stmt->fetchAll());
        }

        Response::error('Route inconnue.', 404);
    }
}
