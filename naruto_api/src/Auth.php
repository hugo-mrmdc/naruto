<?php

declare(strict_types=1);

/**
 * Authentification simple par clé partagée : l'API est appelée serveur-à-serveur
 * par le gamemode GMod (via http.Post / http.Fetch en Lua), pas par des joueurs
 * individuels. Une seule clé secrète suffit ; elle ne doit JAMAIS être envoyée
 * au client GMod (donc appelée uniquement depuis du code lua "if SERVER").
 */
final class Auth
{
    public static function check(): void
    {
        $expected = Config::get('API_KEY');
        if (!$expected || $expected === 'change_me_avec_une_longue_cle_aleatoire') {
            Response::error('API_KEY non configurée côté serveur.', 500);
        }

        $headers = self::headers();
        $given = $headers['x-api-key'] ?? '';

        if (!hash_equals($expected, $given)) {
            Response::error('Clé API invalide ou manquante.', 401);
        }
    }

    /** @return array<string, string> en-têtes avec des clés en minuscules */
    private static function headers(): array
    {
        $raw = function_exists('getallheaders') ? (getallheaders() ?: []) : [];
        $out = [];
        foreach ($raw as $key => $value) {
            $out[strtolower($key)] = $value;
        }

        // Filet de sécurité : certaines configs PHP-FPM/Nginx ne passent pas
        // getallheaders() correctement, mais exposent toujours $_SERVER.
        if (!isset($out['x-api-key']) && isset($_SERVER['HTTP_X_API_KEY'])) {
            $out['x-api-key'] = $_SERVER['HTTP_X_API_KEY'];
        }

        return $out;
    }
}
