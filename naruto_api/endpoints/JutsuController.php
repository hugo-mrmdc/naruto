<?php

declare(strict_types=1);

/**
 * Catalogue de RÉFÉRENCE des jutsu (miroir de config/jutsu.lua côté jeu,
 * pas de données par personnage — voir character_jutsu / character_loadout
 * pour ce qu'un personnage a débloqué/équipé).
 *
 * POST /jutsu/sync   { jutsu: [ {id, name, description?, category?, element?,
 *                                archetype?, chakra?, cooldown?, cast_time?,
 *                                damage?, range?, unlock?, requirements?}, ... ] }
 *   -> remplace tout le catalogue (le jeu est la source de vérité, envoyée
 *      en une fois au démarrage du serveur).
 * GET  /jutsu?category=&element=   -> liste du catalogue
 * GET  /jutsu/{id}                  -> un jutsu
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

            $stmt = $db->prepare(
                'INSERT INTO jutsu_definitions
                    (jutsu_id, name, description, category, element, archetype, chakra, cooldown, cast_time, damage, range_units, unlock, requirements)
                 VALUES (:id, :name, :description, :category, :element, :archetype, :chakra, :cooldown, :cast_time, :damage, :range_units, :unlock, :requirements)'
            );
            foreach ($list as $j) {
                $id = (string) ($j['id'] ?? $j['jutsu_id'] ?? '');
                if ($id === '') {
                    continue;
                }
                $stmt->execute([
                    'id'           => $id,
                    'name'         => (string) ($j['name'] ?? $id),
                    'description'  => (string) ($j['description'] ?? ''),
                    'category'     => (string) ($j['category'] ?? ''),
                    'element'      => (string) ($j['element'] ?? ''),
                    'archetype'    => (string) ($j['archetype'] ?? ''),
                    'chakra'       => (int) ($j['chakra'] ?? 0),
                    'cooldown'     => (float) ($j['cooldown'] ?? 0),
                    'cast_time'    => (float) ($j['cast_time'] ?? $j['castTime'] ?? 0),
                    'damage'       => (int) ($j['damage'] ?? 0),
                    'range_units'  => (int) ($j['range'] ?? $j['range_units'] ?? 0),
                    'unlock'       => (string) ($j['unlock'] ?? 'auto'),
                    'requirements' => json_encode($j['requirements'] ?? new stdClass(), JSON_UNESCAPED_UNICODE),
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
        $where = [];
        $params = [];
        foreach (['category', 'element'] as $filter) {
            $value = Request::query($filter);
            if ($value !== null) {
                $where[] = "{$filter} = :{$filter}";
                $params[$filter] = $value;
            }
        }

        $sql = 'SELECT * FROM jutsu_definitions';
        if ($where !== []) {
            $sql .= ' WHERE ' . implode(' AND ', $where);
        }
        $sql .= ' ORDER BY category, name';

        $db = Database::connection();
        $stmt = $db->prepare($sql);
        $stmt->execute($params);

        Response::ok(array_map([self::class, 'decorate'], $stmt->fetchAll()));
    }

    private static function show(string $id): void
    {
        $stmt = Database::connection()->prepare('SELECT * FROM jutsu_definitions WHERE jutsu_id = :id');
        $stmt->execute(['id' => $id]);
        $row = $stmt->fetch();

        if (!$row) {
            Response::error('Jutsu introuvable.', 404);
        }

        Response::ok(self::decorate($row));
    }

    private static function decorate(array $row): array
    {
        if (isset($row['requirements']) && is_string($row['requirements'])) {
            $row['requirements'] = json_decode($row['requirements'], true);
        }
        return $row;
    }
}
