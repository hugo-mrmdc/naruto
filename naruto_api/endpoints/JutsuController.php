<?php

declare(strict_types=1);

/**
 * Catalogue de RÉFÉRENCE des jutsu (miroir de config/jutsu.lua côté jeu,
 * pas de données par personnage — voir character_jutsu / character_loadout
 * pour ce qu'un personnage a débloqué/équipé).
 *
 * POST /jutsu/sync   { jutsu: [ {id, name, description?}, ... ] }
 *   -> remplace tout le catalogue (le jeu est la source de vérité, envoyée
 *      en une fois au démarrage du serveur).
 * GET  /jutsu         -> liste du catalogue
 * GET  /jutsu/{id}     -> un jutsu
 */
final class JutsuController
{
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
        $list = $data['jutsu'] ?? null;
        if (!is_array($list)) {
            Response::error('Champ "jutsu" (tableau) manquant.', 422);
        }

        $db = Database::connection();
        $db->beginTransaction();
        try {
            $db->exec('DELETE FROM jutsu_definitions');

            $stmt = $db->prepare('INSERT INTO jutsu_definitions (jutsu_id, name, description) VALUES (:id, :name, :description)');
            foreach ($list as $j) {
                $id = (string) ($j['id'] ?? $j['jutsu_id'] ?? '');
                if ($id === '') {
                    continue;
                }
                $stmt->execute([
                    'id'          => $id,
                    'name'        => (string) ($j['name'] ?? $id),
                    'description' => (string) ($j['description'] ?? ''),
                ]);
            }
            $db->commit();
        } catch (Throwable $e) {
            $db->rollBack();
            throw $e;
        }

        Response::ok(['synced' => count($list)]);
    }

    private static function list(): void
    {
        Response::ok(Database::connection()->query('SELECT * FROM jutsu_definitions ORDER BY name')->fetchAll());
    }

    private static function show(string $id): void
    {
        $stmt = Database::connection()->prepare('SELECT * FROM jutsu_definitions WHERE jutsu_id = :id');
        $stmt->execute(['id' => $id]);
        $row = $stmt->fetch();

        if (!$row) {
            Response::error('Jutsu introuvable.', 404);
        }

        Response::ok($row);
    }
}
