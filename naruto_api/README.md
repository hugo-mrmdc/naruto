# naruto_api

API PHP + MySQL pour le serveur **Naruto RP** (GMod). Base de données **séparée**
de celle du jeu : le serveur GMod pousse ses données ici en HTTP (voir
`naruto_dev/gamemodes/narutorp/gamemode/modules/api_sync/sv_api_sync.lua`).

Aucune dépendance externe (pas de Composer, pas de framework) : du PHP 8.1+
et une base MySQL/MariaDB suffisent, ce qui marche sur à peu près n'importe
quel hébergement mutualisé.

## Installation

1. Crée une base MySQL dédiée (différente de celle du jeu si le jeu en a une) et importe le schéma :
   ```
   mysql -u root -p < sql/schema.sql
   ```
2. Copie `.env.example` en `.env` et remplis `DB_HOST`, `DB_NAME`, `DB_USER`, `DB_PASS`.
3. Génère une clé secrète pour `API_KEY` :
   ```
   php -r "echo bin2hex(random_bytes(32));"
   ```
4. Pointe le vhost / sous-domaine sur le dossier `public/` (c'est le seul dossier
   à exposer publiquement — jamais `src/`, `endpoints/`, `sql/` ni `.env`).
5. Vérifie que `mod_rewrite` est actif (le `.htaccess` fourni dans `public/`
   route tout vers `index.php`). Sans Apache/mod_rewrite, l'API fonctionne
   quand même via `index.php/characters/...` (PATH_INFO).
6. Teste : `curl https://tonsite/naruto_api/public/health` doit répondre `{"success":true,...}`.

## Dashboard visuel

`public/dashboard/` est un site en lecture seule (PHP classique, pas de JS,
pas de framework) qui affiche les données déjà en base : `dashboard/index.php`
(résumé + activité récente), `characters.php` (classement filtrable/triable),
`character.php?steamid=...` (fiche complète, décode `raw_data`), `bounties.php`
(Bingo Book) et `logs.php` (journal filtrable).

Il lit la base **directement** (`Database::connection()`), pas via les routes
JSON `/characters`, `/bounties`... donc **pas besoin de la clé `X-Api-Key`**
pour le consulter — cette clé ne doit de toute façon jamais arriver dans un
navigateur. Il n'écrit jamais dans la base.

Il est indépendant du serveur GMod : dès que `sql/schema.sql` est importé, il
tourne et affiche des pages vides (avec un message clair) même sans aucune
synchronisation Lua active. Il se remplit tout seul dès que le jeu commence à
pousser des données (voir plus bas), sans rien à reconfigurer.

Accès : `https://tonsite/naruto_api/public/dashboard/`

## Côté serveur GMod (optionnel, à activer quand tu es prêt)

Dans `naruto_dev/gamemodes/narutorp/gamemode/config/sv_api.lua` :
- `Enabled = true`
- `BaseUrl` = l'URL de `public/index.php` (ou de `public/` si mod_rewrite est actif)
- `ApiKey` = **exactement** la même valeur que `API_KEY` dans `naruto_api/.env`

Une fois activé, `modules/api_sync/sv_api_sync.lua` pousse automatiquement :
- la fiche personnage complète à chaque sauvegarde (autosave, déconnexion, arrêt serveur) ;
- le début/fin de session de connexion ;
- chaque entrée du journal d'actions (`NRP.LogAction`, primes, etc. l'utilisent déjà) ;
- les primes actives et les relations entre villages, toutes les `SyncInterval` secondes.

Tout est best-effort : si l'API est injoignable, le jeu continue de fonctionner
normalement (aucune de ces requêtes ne bloque une action du joueur).

## Authentification

Toutes les routes sauf `/` et `/health` exigent l'en-tête `X-Api-Key` (clé
partagée, appel serveur-à-serveur uniquement — jamais depuis le client GMod).

## Routes

| Méthode | Route | Description |
|---|---|---|
| GET | `/health` | ping, sans authentification |
| POST | `/characters/sync` | crée/met à jour une fiche personnage (voir "Identifiant de personnage" plus bas) |
| GET | `/characters?sort=level\|xp\|ryo\|playtime&order=desc&village=&clan=&rank=&steamid=&limit=&offset=` | liste / classement |
| GET | `/characters/{id}` | une fiche complète, par son identifiant de personnage |
| POST | `/sessions/start` `{steamid, steam_name}` | ouvre une session |
| POST | `/sessions/end` `{steamid}` | ferme la session ouverte la plus récente |
| GET | `/sessions?steamid=&limit=` | historique des sessions |
| GET / POST | `/players`, `/players/{steamid}` | comptes (steamid, dernière connexion...) |
| POST | `/logs` `{category, actor_steamid?, actor_name?, target_steamid?, message}` | ajoute une entrée au journal |
| GET | `/logs?category=&actor_steamid=&target_steamid=&limit=&offset=` | consulte le journal |
| POST | `/bounties/sync` `{bounties: [...]}` | remplace la liste des primes actives |
| GET | `/bounties?all=1` | primes actives (ou tout l'historique) |
| POST | `/villages/relations/sync` `{relations: [...]}` | met à jour les relations entre villages |
| GET | `/villages/relations` | toutes les relations |
| POST | `/bans` `{steamid, reason, admin_steamid?, admin_name?, expires_at?}` | archive un ban (registre web) |
| PATCH | `/bans/{id}` `{lifted_by}` | marque un ban comme levé |
| GET | `/bans?steamid=&active=1` | historique des bans |
| GET | `/stats/leaderboard?by=level\|xp\|ryo\|playtime&limit=10` | classement |
| GET | `/stats/summary` | quelques compteurs globaux (page d'accueil du site) |

Toutes les réponses sont au format `{"success": true, "data": ...}` ou
`{"success": false, "error": "..."}`.

### Identifiant de personnage (`id`) vs `steamid`

`characters.id` identifie le **personnage**, `steamid` identifie juste son
**propriétaire** — un même joueur pourra un jour avoir plusieurs personnages,
donc `steamid` n'est pas unique dans cette table (contrairement à `players`,
qui identifie bien un compte Steam).

Aujourd'hui le gamemode n'envoie encore qu'un personnage par steamid (pas
d'identifiant de personnage côté Lua) : `POST /characters/sync` met donc à
jour la première fiche trouvée pour ce steamid, ou en crée une nouvelle s'il
n'y en a aucune, et renvoie toujours l'`id` de la fiche concernée
(`{"synced": true, "id": 4}`). Le jour où le jeu gérera plusieurs personnages
par joueur, il suffira qu'il envoie aussi un identifiant de personnage dans
le payload pour que chacun soit synchronisé sur sa propre ligne.

### Notes sur `/bans`

Ce registre est pensé pour un historique/modération **côté site web** : il
n'empêche pas un joueur banni de se reconnecter (ça reste le rôle de ton
addon admin GMod, ULX/SAM...). Si tu veux un jour bloquer la connexion
directement depuis cette table, il suffira d'appeler `GET /bans?steamid=...&active=1`
dans le hook `CheckPassword` ou `PlayerAuthed` du serveur GMod.

### `raw_data`

`characters.raw_data` contient l'intégralité du JSON envoyé par le jeu à
chaque sync (inventaire, jutsu, stats, affinités...). Les colonnes dédiées
(`level`, `xp`, `ryo`, `village`, `clan`...) ne servent qu'aux tris/filtres
rapides du site ; si un module Lua ajoute un nouveau champ de personnage
plus tard, il apparaît automatiquement dans `raw_data` sans toucher à cette
API.
