<?php

declare(strict_types=1);

final class Request
{
    private static ?array $json = null;

    /** @return array<string, mixed> */
    public static function json(): array
    {
        if (self::$json !== null) {
            return self::$json;
        }

        $raw = file_get_contents('php://input') ?: '';
        if ($raw === '') {
            return self::$json = [];
        }

        $decoded = json_decode($raw, true);
        if (!is_array($decoded)) {
            Response::error('Corps de requête JSON invalide.', 400);
        }

        return self::$json = $decoded;
    }

    public static function query(string $key, ?string $default = null): ?string
    {
        $value = $_GET[$key] ?? $default;
        return $value === null ? null : (string) $value;
    }

    public static function queryInt(string $key, int $default): int
    {
        return isset($_GET[$key]) ? (int) $_GET[$key] : $default;
    }

    /** Vérifie que ces clés existent et ne sont pas vides dans le tableau donné. */
    public static function requireFields(array $data, array $keys): void
    {
        $missing = [];
        foreach ($keys as $key) {
            if (!array_key_exists($key, $data) || $data[$key] === null || $data[$key] === '') {
                $missing[] = $key;
            }
        }
        if ($missing !== []) {
            Response::error('Champ(s) manquant(s) : ' . implode(', ', $missing), 422);
        }
    }
}
