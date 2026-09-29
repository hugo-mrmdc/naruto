<?php

declare(strict_types=1);

/**
 * POST /logs   { category, actor_steamid?, actor_name?, target_steamid?, message }
 * GET  /logs?category=&target_steamid=&limit=&offset=
 */
final class LogsController
{
    public static function handle(string $method, array $segments): void
    {
        $db = Database::connection();

        if ($method === 'POST' && $segments === []) {
            $data = Request::json();
            Request::requireFields($data, ['category', 'message']);

            $stmt = $db->prepare(
                'INSERT INTO logs (occurred_at, category, actor_steamid, actor_name, target_steamid, message)
                 VALUES (:occurred_at, :category, :actor_steamid, :actor_name, :target_steamid, :message)'
            );
            $stmt->execute([
                'occurred_at'    => isset($data['occurred_at']) ? date('Y-m-d H:i:s', (int) $data['occurred_at']) : date('Y-m-d H:i:s'),
                'category'       => (string) $data['category'],
                'actor_steamid'  => (string) ($data['actor_steamid'] ?? ''),
                'actor_name'     => (string) ($data['actor_name'] ?? ''),
                'target_steamid' => (string) ($data['target_steamid'] ?? ''),
                'message'        => (string) $data['message'],
            ]);

            Response::ok(['id' => (int) $db->lastInsertId()], 201);
        }

        if ($method === 'GET' && $segments === []) {
            $where = [];
            $params = [];
            foreach (['category', 'actor_steamid', 'target_steamid'] as $filter) {
                $value = Request::query($filter);
                if ($value !== null) {
                    $where[] = "{$filter} = :{$filter}";
                    $params[$filter] = $value;
                }
            }

            $limit = min(max(Request::queryInt('limit', 100), 1), 500);
            $offset = max(Request::queryInt('offset', 0), 0);

            $sql = 'SELECT * FROM logs';
            if ($where !== []) {
                $sql .= ' WHERE ' . implode(' AND ', $where);
            }
            $sql .= ' ORDER BY occurred_at DESC LIMIT :limit OFFSET :offset';

            $stmt = $db->prepare($sql);
            foreach ($params as $key => $value) {
                $stmt->bindValue(":{$key}", $value);
            }
            $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
            $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
            $stmt->execute();

            Response::ok($stmt->fetchAll());
        }

        Response::error('Route inconnue.', 404);
    }
}
