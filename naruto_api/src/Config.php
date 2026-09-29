<?php

declare(strict_types=1);

/**
 * Charge le ".env" (à la racine de naruto_api/) et expose ses valeurs.
 * Pas de dépendance externe : parseur minimal suffisant pour un fichier KEY=VALUE.
 */
final class Config
{
    private static array $values = [];
    private static bool $loaded = false;

    public static function load(): void
    {
        if (self::$loaded) {
            return;
        }
        self::$loaded = true;

        // ".env" en priorité ; "config.env" en secours (certains hébergeurs/clients FTP refusent les fichiers en ".")
        $path = __DIR__ . '/../.env';
        if (!is_file($path)) {
            $path = __DIR__ . '/../config.env';
        }
        if (!is_file($path)) {
            return; // en prod, les valeurs peuvent venir des variables d'environnement du serveur web
        }

        foreach (file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
            $line = trim(preg_replace('/^ï»¿/', '', $line)); // BOM UTF-8 éventuel
            if ($line === '' || str_starts_with($line, '#') || !str_contains($line, '=')) {
                continue;
            }
            [$key, $value] = explode('=', $line, 2);
            $value = trim($value);
            if (strlen($value) >= 2 && ($value[0] === '"' || $value[0] === "'") && $value[-1] === $value[0]) {
                $value = substr($value, 1, -1);
            }
            self::$values[trim($key)] = $value;
        }
    }

    public static function get(string $key, ?string $default = null): ?string
    {
        self::load();

        if (array_key_exists($key, $_ENV)) {
            return $_ENV[$key];
        }

        $fromGetenv = getenv($key);
        if ($fromGetenv !== false) {
            return $fromGetenv;
        }

        return self::$values[$key] ?? $default;
    }
}
