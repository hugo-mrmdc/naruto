<?php

declare(strict_types=1);

/**
 * Comptes du dashboard (staff/admin), SÉPARÉS de la clé X-Api-Key de l'API
 * JSON (qui sert au serveur GMod, jamais à un navigateur) et des comptes
 * joueurs du jeu (aucun rapport avec "characters"/"players").
 *
 * N'importe qui peut créer un compte (register()), mais il reste "pending"
 * (aucun accès) tant qu'un superadmin ne l'active pas via approve(). Le tout
 * premier compte créé (table vide) devient automatiquement superadmin actif,
 * pour amorcer le système sans configuration manuelle.
 *
 * Rôles : "admin" (accès normal au dashboard) et "superadmin" (accès normal
 * + gestion des comptes sur users.php).
 */
final class DashboardAuth
{
    private const SESSION_USER_KEY = 'dashboard_user';
    public const ROLES = ['admin', 'superadmin'];

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
        return !empty($_SESSION[self::SESSION_USER_KEY]);
    }

    /** @return array{id:int, username:string, role:string}|null */
    public static function currentUser(): ?array
    {
        self::start();
        return $_SESSION[self::SESSION_USER_KEY] ?? null;
    }

    public static function isSuperAdmin(): bool
    {
        return (self::currentUser()['role'] ?? '') === 'superadmin';
    }

    /**
     * Redirige vers login.php si pas connecté. Revalide aussi le compte en
     * base à chaque requête (statut + rôle) : un compte désactivé ou
     * rétrogradé par un super admin ne doit pas garder les droits d'une
     * session ouverte avant ce changement, sans attendre qu'il se déconnecte.
     */
    public static function requireLogin(): void
    {
        $user = self::currentUser();
        if (!$user) {
            $redirect = basename($_SERVER['SCRIPT_NAME'] ?? 'index.php');
            header('Location: login.php?redirect=' . urlencode($redirect));
            exit;
        }

        $stmt = Database::connection()->prepare('SELECT role, status FROM dashboard_users WHERE id = :id');
        $stmt->execute(['id' => $user['id']]);
        $fresh = $stmt->fetch();

        if (!$fresh || $fresh['status'] !== 'active') {
            self::logout();
            header('Location: login.php');
            exit;
        }

        if ($fresh['role'] !== $user['role']) {
            $_SESSION[self::SESSION_USER_KEY]['role'] = $fresh['role'];
        }
    }

    /** À appeler après requireLogin() sur les pages réservées aux superadmins. */
    public static function requireSuperAdmin(): void
    {
        self::requireLogin();
        if (!self::isSuperAdmin()) {
            http_response_code(403);
            echo '<!doctype html><meta charset="utf-8"><body style="background:#12121a;color:#e8e8ee;font-family:sans-serif;padding:40px">'
                . '<h1>Accès refusé</h1><p>Réservé aux super admins.</p></body>';
            exit;
        }
    }

    /**
     * Crée un compte. Le tout premier compte (table vide) devient
     * superadmin + actif immédiatement ; les suivants sont "admin" / "pending".
     * @return array{0: bool, 1: string} [succès, message]
     */
    public static function register(string $username, string $password): array
    {
        $username = trim($username);
        if (!preg_match('/^[a-zA-Z0-9_-]{3,32}$/', $username)) {
            return [false, "Nom d'utilisateur invalide (3 à 32 caractères : lettres, chiffres, - ou _)."];
        }
        if (strlen($password) < 8) {
            return [false, 'Mot de passe trop court (8 caractères minimum).'];
        }

        $db = Database::connection();

        $exists = $db->prepare('SELECT 1 FROM dashboard_users WHERE username = :u');
        $exists->execute(['u' => $username]);
        if ($exists->fetchColumn()) {
            return [false, "Ce nom d'utilisateur est déjà pris."];
        }

        $isFirstAccount = (int) $db->query('SELECT COUNT(*) FROM dashboard_users')->fetchColumn() === 0;
        $role = $isFirstAccount ? 'superadmin' : 'admin';
        $status = $isFirstAccount ? 'active' : 'pending';

        $stmt = $db->prepare(
            'INSERT INTO dashboard_users (username, password_hash, role, status, approved_at, approved_by)
             VALUES (:username, :hash, :role, :status, :approved_at, :approved_by)'
        );
        $stmt->execute([
            'username'     => $username,
            'hash'         => password_hash($password, PASSWORD_DEFAULT),
            'role'         => $role,
            'status'       => $status,
            'approved_at'  => $isFirstAccount ? date('Y-m-d H:i:s') : null,
            'approved_by'  => $isFirstAccount ? '(premier compte)' : null,
        ]);

        return $isFirstAccount
            ? [true, 'Compte créé en tant que super admin. Tu peux te connecter.']
            : [true, 'Compte créé. Un super admin doit maintenant activer ton accès.'];
    }

    /**
     * Vérifie identifiants + statut actif, ouvre la session si tout est bon.
     * @return array{0: bool, 1: string} [succès, message d'erreur si échec]
     */
    public static function attempt(string $username, string $password): array
    {
        self::start();

        $stmt = Database::connection()->prepare('SELECT * FROM dashboard_users WHERE username = :u');
        $stmt->execute(['u' => trim($username)]);
        $user = $stmt->fetch();

        if (!$user || !password_verify($password, $user['password_hash'])) {
            return [false, 'Identifiants incorrects.'];
        }
        if ($user['status'] === 'pending') {
            return [false, "Compte en attente d'activation par un super admin."];
        }
        if ($user['status'] !== 'active') {
            return [false, 'Compte désactivé.'];
        }

        session_regenerate_id(true);
        $_SESSION[self::SESSION_USER_KEY] = [
            'id'       => (int) $user['id'],
            'username' => $user['username'],
            'role'     => $user['role'],
        ];
        return [true, ''];
    }

    public static function logout(): void
    {
        self::start();
        $_SESSION = [];
        session_destroy();
    }

    public static function csrfToken(): string
    {
        self::start();
        if (empty($_SESSION['csrf'])) {
            $_SESSION['csrf'] = bin2hex(random_bytes(32));
        }
        return $_SESSION['csrf'];
    }

    public static function checkCsrf(): void
    {
        self::start();
        $token = (string) ($_POST['csrf'] ?? '');
        if ($token === '' || !hash_equals($_SESSION['csrf'] ?? '', $token)) {
            http_response_code(400);
            exit('Requête invalide (jeton CSRF).');
        }
    }

    private static function isHttps(): bool
    {
        return (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off')
            || (($_SERVER['SERVER_PORT'] ?? null) === '443')
            || (($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') === 'https');
    }
}
