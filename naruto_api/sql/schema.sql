-- ============================================================
-- Naruto RP - API externe : schéma MySQL
-- Base SÉPARÉE de celle du serveur GMod (qui reste en SQLite/MySQL local).
-- Le serveur GMod pousse ses données ici via HTTP (voir naruto_dev/gamemodes/
-- narutorp/gamemode/modules/api_sync/sv_api_sync.lua).
-- ============================================================

SET NAMES utf8mb4;

-- ------------------------------------------------------------
-- Comptes du DASHBOARD (staff/admin) — rien à voir avec les joueurs du jeu.
-- N'importe qui peut créer un compte (register.php), mais il reste en
-- "pending" tant qu'un superadmin ne l'active pas depuis users.php.
-- Exception : le tout premier compte créé (table vide) devient
-- automatiquement superadmin + actif, pour amorcer le système.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dashboard_users (
    id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    username      VARCHAR(32)  NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role          VARCHAR(16)  NOT NULL DEFAULT 'admin',   -- admin | superadmin
    status        VARCHAR(16)  NOT NULL DEFAULT 'pending', -- pending | active | disabled
    created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    approved_at   DATETIME     NULL,
    approved_by   VARCHAR(32)  NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uniq_dashboard_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ------------------------------------------------------------
-- Comptes (identité Steam, indépendante du personnage RP)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS players (
    steamid       VARCHAR(32)  NOT NULL,
    steam_name    VARCHAR(64)  NOT NULL DEFAULT '',
    first_seen    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_seen     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    session_count INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (steamid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ------------------------------------------------------------
-- Sessions de connexion (pour le temps de jeu / l'activité récente)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sessions (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    steamid         VARCHAR(32)  NOT NULL,
    connected_at    DATETIME     NOT NULL,
    disconnected_at DATETIME     NULL,
    PRIMARY KEY (id),
    KEY idx_sessions_steamid (steamid),
    KEY idx_sessions_open (steamid, disconnected_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ------------------------------------------------------------
-- Fiches personnage. "id" est l'identifiant du PERSONNAGE (un joueur peut en
-- avoir plusieurs) ; "steamid" identifie juste son propriétaire et n'est donc
-- PAS unique ici (voir "players" pour le compte Steam lui-même).
-- Colonnes typées pour ce qui sert aux classements/filtres du site ;
-- "raw_data" garde l'intégralité de ce qu'envoie le jeu (y compris les
-- champs ajoutés plus tard côté Lua sans toucher à ce schéma).
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS characters (
    id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    steamid        VARCHAR(32)   NOT NULL,
    firstname      VARCHAR(64)   NOT NULL DEFAULT '',
    lastname       VARCHAR(64)   NOT NULL DEFAULT '',
    gender         VARCHAR(16)   NOT NULL DEFAULT '',
    model          VARCHAR(255)  NOT NULL DEFAULT '',
    skin           INT UNSIGNED  NOT NULL DEFAULT 0,
    bodygroups     JSON          NULL,               -- {id_bodygroup: valeur}
    color          JSON          NULL,               -- [r, g, b]
    flags          JSON          NULL,               -- fourre-tout générique (bonusStatPoints, dojutsuPref...)
    village        VARCHAR(32)   NOT NULL DEFAULT '',
    clan           VARCHAR(32)   NOT NULL DEFAULT '',
    rank           VARCHAR(32)   NOT NULL DEFAULT '',
    level          INT           NOT NULL DEFAULT 1,
    xp             BIGINT        NOT NULL DEFAULT 0,
    ryo            BIGINT        NOT NULL DEFAULT 0,
    stat_points    INT           NOT NULL DEFAULT 0,
    deserter       TINYINT(1)    NOT NULL DEFAULT 0,
    origin_village VARCHAR(32)   NOT NULL DEFAULT '',
    playtime       INT UNSIGNED  NOT NULL DEFAULT 0,
    game_created   INT UNSIGNED  NOT NULL DEFAULT 0, -- horodatage Unix envoyé par le jeu (data.created)
    game_last_seen INT UNSIGNED  NOT NULL DEFAULT 0, -- horodatage Unix envoyé par le jeu (data.lastSeen)
    raw_data       MEDIUMTEXT    NULL,               -- JSON complet envoyé (garde-fou pour tout champ pas encore prévu ici)
    updated_at     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_characters_steamid (steamid),
    KEY idx_characters_village (village),
    KEY idx_characters_clan (clan),
    KEY idx_characters_level (level),
    KEY idx_characters_ryo (ryo),
    KEY idx_characters_playtime (playtime)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ------------------------------------------------------------
-- Ce qui était noyé dans "raw_data" (JSON) a chacun sa table : plus facile à
-- filtrer/lister/joindre depuis le site ("qui a tel jutsu", "qui possède tel
-- objet"...). Toutes ont la même forme (character_id + identifiant [+valeur]).
-- ------------------------------------------------------------

-- Statistiques allouées (force, vitesse, chakra...)
CREATE TABLE IF NOT EXISTS character_stats (
    character_id BIGINT UNSIGNED NOT NULL,
    stat_id      VARCHAR(32)     NOT NULL,
    value        INT             NOT NULL DEFAULT 0,
    PRIMARY KEY (character_id, stat_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Affinités élémentaires (katon, suiton, raiton, doton, fuuton)
CREATE TABLE IF NOT EXISTS character_affinities (
    character_id BIGINT UNSIGNED NOT NULL,
    element_id   VARCHAR(32)     NOT NULL,
    PRIMARY KEY (character_id, element_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Kekkei Genkai débloqués (mokuton, hyoton, jinton, yoton, shakuton, futton,
-- jiton, shoton, meiton, bakuton, kiminari...)
CREATE TABLE IF NOT EXISTS character_kekkei (
    character_id BIGINT UNSIGNED NOT NULL,
    kekkei_id    VARCHAR(32)     NOT NULL,
    level        INT             NOT NULL DEFAULT 1,
    PRIMARY KEY (character_id, kekkei_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Jutsu débloqués et leur niveau
CREATE TABLE IF NOT EXISTS character_jutsu (
    character_id BIGINT UNSIGNED NOT NULL,
    jutsu_id     VARCHAR(64)     NOT NULL,
    level        INT             NOT NULL DEFAULT 1,
    PRIMARY KEY (character_id, jutsu_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Nœuds débloqués dans l'arbre de clan
CREATE TABLE IF NOT EXISTS character_clan_tree (
    character_id BIGINT UNSIGNED NOT NULL,
    node_id      VARCHAR(64)     NOT NULL,
    PRIMARY KEY (character_id, node_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Inventaire (objet -> quantité)
CREATE TABLE IF NOT EXISTS character_inventory (
    character_id BIGINT UNSIGNED NOT NULL,
    item_id      VARCHAR(64)     NOT NULL,
    quantity     INT UNSIGNED    NOT NULL DEFAULT 0,
    PRIMARY KEY (character_id, item_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Objets équipés (emplacement -> objet)
CREATE TABLE IF NOT EXISTS character_equipped (
    character_id BIGINT UNSIGNED NOT NULL,
    slot         VARCHAR(16)     NOT NULL,
    item_id      VARCHAR(64)     NOT NULL,
    PRIMARY KEY (character_id, slot)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ------------------------------------------------------------
-- Catalogue des jutsu (référence STATIQUE, miroir de config/jutsu.lua -
-- PAS liée à un personnage). Poussée en une fois par le jeu au démarrage
-- (voir modules/api_sync/sv_api_sync.lua), pour que le site puisse afficher
-- de vrais noms/descriptions au lieu des ids bruts stockés dans
-- character_jutsu.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS jutsu_definitions (
    jutsu_id    VARCHAR(64)  NOT NULL,
    name        VARCHAR(128) NOT NULL DEFAULT '',
    description TEXT         NULL,
    updated_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (jutsu_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ------------------------------------------------------------
-- Journal d'actions (miroir de la table "logs" du jeu, pour affichage web)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS logs (
    id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    occurred_at  DATETIME     NOT NULL,
    category     VARCHAR(32)  NOT NULL DEFAULT '',
    actor_steamid   VARCHAR(32) NOT NULL DEFAULT '',
    actor_name      VARCHAR(64) NOT NULL DEFAULT '',
    target_steamid  VARCHAR(32) NOT NULL DEFAULT '',
    message      TEXT         NULL,
    PRIMARY KEY (id),
    KEY idx_logs_category (category),
    KEY idx_logs_target (target_steamid),
    KEY idx_logs_time (occurred_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ------------------------------------------------------------
-- Relations diplomatiques entre villages (petite table, resync périodique)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS village_relations (
    village_a  VARCHAR(32) NOT NULL,
    village_b  VARCHAR(32) NOT NULL,
    status     VARCHAR(16) NOT NULL DEFAULT 'neutral',
    updated_at DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (village_a, village_b)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ------------------------------------------------------------
-- Bans (registre web, INDÉPENDANT de ton addon admin ULX/SAM qui gère déjà
-- le blocage réel des joueurs. Sert d'historique consultable sur le site).
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bans (
    id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    steamid        VARCHAR(32)  NOT NULL,
    reason         VARCHAR(255) NOT NULL DEFAULT '',
    admin_steamid  VARCHAR(32)  NOT NULL DEFAULT '',
    admin_name     VARCHAR(64)  NOT NULL DEFAULT '',
    created_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at     DATETIME     NULL,       -- NULL = permanent
    active         TINYINT(1)   NOT NULL DEFAULT 1,
    lifted_at      DATETIME     NULL,
    lifted_by      VARCHAR(64)  NULL,
    PRIMARY KEY (id),
    KEY idx_bans_steamid (steamid),
    KEY idx_bans_active (active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
