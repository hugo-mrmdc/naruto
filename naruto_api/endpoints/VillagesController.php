<?php

declare(strict_types=1);

/**
 * POST /villages/relations/sync   { relations: [ {village_a, village_b, status}, ... ] }
 * GET  /villages/relations
 */
final class VillagesController
{
    public static function handle(string $method, array $segments): void
    {
        $db = Database::connection();

        if ($method === 'POST' && ($segments[0] ?? '') === 'relations' && ($segments[1] ?? '') === 'sync') {
            $data = Request::json();
            $relations = $data['relations'] ?? null;
            if (!is_array($relations)) {
                Response::error('Champ "relations" (tableau) manquant.', 422);
            }

            $stmt = $db->prepare(
                'INSERT INTO village_relations (village_a, village_b, status)
                 VALUES (:a, :b, :status)
                 ON DUPLICATE KEY UPDATE status = VALUES(status)'
            );
            foreach ($relations as $r) {
                $a = (string) ($r['village_a'] ?? $r['a'] ?? '');
                $b = (string) ($r['village_b'] ?? $r['b'] ?? '');
                if ($a === '' || $b === '') {
                    continue;
                }
                if ($a > $b) {
                    [$a, $b] = [$b, $a];
                }
                $stmt->execute(['a' => $a, 'b' => $b, 'status' => (string) ($r['status'] ?? 'neutral')]);
            }

            Response::ok(['synced' => count($relations)]);
        }

        if ($method === 'GET' && ($segments[0] ?? '') === 'relations') {
            Response::ok($db->query('SELECT * FROM village_relations')->fetchAll());
        }

        Response::error('Route inconnue.', 404);
    }
}
