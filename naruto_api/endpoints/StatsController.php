<?php

declare(strict_types=1);

/**
 * GET /stats/leaderboard?by=level|xp|ryo|playtime&limit=10
 * GET /stats/summary   -> quelques compteurs globaux pour une page d'accueil
 */
final class StatsController
{
    private const METRICS = ['level', 'xp', 'ryo', 'playtime'];

    public static function handle(string $method, array $segments): void
    {
        if ($method !== 'GET') {
            Response::error('Route inconnue.', 404);
        }

        $db = Database::connection();

        if (($segments[0] ?? '') === 'leaderboard') {
            $by = Request::query('by', 'level');
            if (!in_array($by, self::METRICS, true)) {
                $by = 'level';
            }
            $limit = min(max(Request::queryInt('limit', 10), 1), 100);

            $stmt = $db->prepare(
                "SELECT steamid, firstname, lastname, village, clan, rank, level, xp, ryo, playtime
                 FROM characters ORDER BY {$by} DESC LIMIT :limit"
            );
            $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
            $stmt->execute();

            Response::ok(['metric' => $by, 'entries' => $stmt->fetchAll()]);
        }

        if (($segments[0] ?? '') === 'summary') {
            $characters = (int) $db->query('SELECT COUNT(*) FROM characters')->fetchColumn();
            $onlineSessions = (int) $db->query('SELECT COUNT(*) FROM sessions WHERE disconnected_at IS NULL')->fetchColumn();
            $totalPlaytime = (int) $db->query('SELECT COALESCE(SUM(playtime), 0) FROM characters')->fetchColumn();

            Response::ok([
                'characters'      => $characters,
                'open_sessions'   => $onlineSessions,
                'total_playtime_seconds' => $totalPlaytime,
            ]);
        }

        Response::error('Route inconnue.', 404);
    }
}
