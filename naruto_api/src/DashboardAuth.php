<?php

declare(strict_types=1);

/**
 * Authentification du dashboard (mot de passe unique + session PHP), SÉPARÉE
 * de la clé X-Api-Key de l'API JSON : cette dernière sert au serveur GMod et
 * ne doit jamais atteindre un navigateur, alors que le dashboard est
 * justement consulté depuis un navigateur.
 *
 * Un seul mot de passe partagé (pas de compte par utilisateur) : c'est un
 * dashboard interne/staff, pas un site avec des comptes joueurs.
 */
final class DashboardAuth
{
    private const SESSION_KEY = 'dashboard_authed';

    public static function start(): void
    {
        if (session_status() === PHP_SESSION_NONE) {
            session_set_cookie_params([
                'httponly' => true,
                'samesite' => 'Lax',
                'secure'   => self::isHttps(),
            ]);
            session_start();
        }
    }

    public static function isLoggedIn(): bool
    {
        self::start();
        return !empty($_SESSION[self::SESSION_KEY]);
    }

    /** Redirige vers login.php si pas connecté, en gardant la page demandée pour y revenir après. */
    public static function requireLogin(): void
    {
        if (self::isLoggedIn()) {
            return;
        }
        $redirect = basename($_SERVER['SCRIPT_NAME'] ?? 'index.php');
        header('Location: login.php?redirect=' . urlencode($redirect));
        exit;
    }

    /**
     * Vérifie le mot de passe contre DASHBOARD_PASSWORD_HASH (.env). Si ce
     * réglage est absent/laissé à sa valeur d'exemple, refuse tout le monde
     * (fail closed) plutôt que d'exposer le dashboard par erreur de config.
     */
    public static function attempt(string $password): bool
    {
        self::start();

        $hash = Config::get('DASHBOARD_PASSWORD_HASH', '');
        if ($hash === '' || $hash === 'colle_ici_le_hash_genere') {
            return false;
        }

        if (!password_verify($password, $hash)) {
            return false;
        }

        session_regenerate_id(true);
        $_SESSION[self::SESSION_KEY] = true;
        return true;
    }

    public static function logout(): void
    {
        self::start();
        $_SESSION = [];
        session_destroy();
    }

    private static function isHttps(): bool
    {
        return (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off')
            || (($_SERVER['SERVER_PORT'] ?? null) === '443')
            || (($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') === 'https');
    }
}
