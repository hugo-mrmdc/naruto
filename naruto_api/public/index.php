<?php

declare(strict_types=1);

error_reporting(E_ALL);
ini_set('display_errors', '0'); // jamais d'erreurs PHP brutes dans une réponse JSON publique

require __DIR__ . '/../src/Config.php';
require __DIR__ . '/../src/Database.php';
require __DIR__ . '/../src/Response.php';
require __DIR__ . '/../src/Auth.php';
require __DIR__ . '/../src/Request.php';

date_default_timezone_set(Config::get('APP_TIMEZONE', 'UTC'));

set_exception_handler(static function (Throwable $e): void {
    error_log('[naruto_api] ' . $e->getMessage() . ' @ ' . $e->getFile() . ':' . $e->getLine());
    Response::error('Erreur interne du serveur.', 500);
});

require __DIR__ . '/../endpoints/PlayersController.php';
require __DIR__ . '/../endpoints/SessionsController.php';
require __DIR__ . '/../endpoints/CharactersController.php';
require __DIR__ . '/../endpoints/LogsController.php';
require __DIR__ . '/../endpoints/VillagesController.php';
require __DIR__ . '/../endpoints/BansController.php';
require __DIR__ . '/../endpoints/StatsController.php';

// Chemin demandé, relatif à ce fichier (fonctionne avec ou sans mod_rewrite) :
//   /naruto_api/public/index.php/characters/76561198000000000
//   /naruto_api/public/characters/76561198000000000   (avec le .htaccess fourni)
$path = $_SERVER['PATH_INFO'] ?? '';
if ($path === '') {
    $uri = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
    $script = str_replace('\\', '/', dirname($_SERVER['SCRIPT_NAME'] ?? ''));
    if ($script !== '/' && str_starts_with($uri, $script)) {
        $uri = substr($uri, strlen($script));
    }
    $path = $uri;
}
$segments = array_values(array_filter(explode('/', trim($path, '/')), static fn ($s) => $s !== ''));
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

if ($segments === [] && $method === 'GET') {
    Response::ok(['name' => 'naruto_api', 'status' => 'up']);
}

if ($segments[0] === 'health' && $method === 'GET') {
    Response::ok(['status' => 'ok', 'time' => date(DATE_ATOM)]);
}

// Tout le reste nécessite la clé API (serveur GMod <-> serveur web uniquement).
Auth::check();

$resource = $segments[0] ?? '';
$rest = array_slice($segments, 1);

try {
    match ($resource) {
        'players'  => PlayersController::handle($method, $rest),
        'sessions' => SessionsController::handle($method, $rest),
        'characters' => CharactersController::handle($method, $rest),
        'logs' => LogsController::handle($method, $rest),
        'villages' => VillagesController::handle($method, $rest),
        'bans' => BansController::handle($method, $rest),
        'stats' => StatsController::handle($method, $rest),
        default => Response::error('Route inconnue.', 404),
    };
} catch (InvalidArgumentException $e) {
    Response::error($e->getMessage(), 422);
}

Response::error('Route inconnue.', 404);
