<?php

declare(strict_types=1);

final class Database
{
    private static ?PDO $pdo = null;

    public static function connection(): PDO
    {
        if (self::$pdo !== null) {
            return self::$pdo;
        }

        if (Config::get('DB_HOST') === null || Config::get('DB_USER') === null) {
            // Sans .env (jamais commité : à créer sur le serveur), on ne tente pas root@127.0.0.1 à l'aveugle.
            $env = realpath(__DIR__ . '/..') . '/.env';
            $etat = is_file($env) ? (is_readable($env) ? 'présent mais sans DB_HOST/DB_USER' : 'présent mais illisible (droits)') : 'introuvable';
            throw new RuntimeException("Configuration DB absente : {$env} {$etat}. Crée ce fichier, ou config.env au même endroit (copie de .env.example).");
        }

        $host = Config::get('DB_HOST', '127.0.0.1');
        $port = Config::get('DB_PORT', '3306');
        $name = Config::get('DB_NAME', 'naruto_api');
        $user = Config::get('DB_USER', 'root');
        $pass = Config::get('DB_PASS', '');

        $dsn = "mysql:host={$host};port={$port};dbname={$name};charset=utf8mb4";

        self::$pdo = new PDO($dsn, $user, $pass, [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES   => false,
        ]);

        return self::$pdo;
    }
}
