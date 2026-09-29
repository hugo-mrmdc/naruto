<?php

declare(strict_types=1);

/**
 * POST /bounties/sync   { bounties: [ {target, target_name, amount, reason, issuer, issuer_name, village, created}, ... ] }
 *   -> remplace entièrement les primes actives par la liste donnée (le jeu est la source de vérité).
 * GET  /bounties?all=1  -> primes actives (ou tout l'historique si all=1)
 */
final class BountiesController
{
    public static function handle(string $method, array $segments): void
    {
        $db = Database::connection();

        if ($method === 'POST' && ($segments[0] ?? '') === 'sync') {
            $data = Request::json();
            $bounties = $data['bounties'] ?? null;
            if (!is_array($bounties)) {
                Response::error('Champ "bounties" (tableau) manquant.', 422);
            }

            $db->beginTransaction();
            try {
                $db->exec('UPDATE bounties SET active = 0 WHERE active = 1');

                $stmt = $db->prepare(
                    'INSERT INTO bounties (target_steamid, target_name, amount, reason, issuer_steamid, issuer_name, village, game_created, active)
                     VALUES (:target, :target_name, :amount, :reason, :issuer, :issuer_name, :village, :created, 1)'
                );
                foreach ($bounties as $b) {
                    $stmt->execute([
                        'target'      => (string) ($b['target'] ?? ''),
                        'target_name' => (string) ($b['target_name'] ?? $b['targetName'] ?? ''),
                        'amount'      => (int) ($b['amount'] ?? 0),
                        'reason'      => (string) ($b['reason'] ?? ''),
                        'issuer'      => (string) ($b['issuer'] ?? ''),
                        'issuer_name' => (string) ($b['issuer_name'] ?? $b['issuerName'] ?? ''),
                        'village'     => (string) ($b['village'] ?? ''),
                        'created'     => (int) ($b['created'] ?? time()),
                    ]);
                }
                $db->commit();
            } catch (Throwable $e) {
                $db->rollBack();
                throw $e;
            }

            Response::ok(['synced' => count($bounties)]);
        }

        if ($method === 'GET' && $segments === []) {
            $all = Request::query('all') === '1';
            $sql = 'SELECT * FROM bounties' . ($all ? '' : ' WHERE active = 1') . ' ORDER BY amount DESC';
            Response::ok($db->query($sql)->fetchAll());
        }

        Response::error('Route inconnue.', 404);
    }
}
