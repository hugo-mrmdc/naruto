-- ============================================================
-- Naruto RP - API externe : schéma MySQL
-- Base SÉPARÉE de celle du serveur GMod (qui reste en SQLite/MySQL local).
-- Le serveur GMod pousse ses données ici via HTTP (voir naruto_dev/gamemodes/
-- narutorp/gamemode/modules/api_sync/sv_api_sync.lua).
-- ============================================================

SET NAMES utf8mb4;

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
-- Fiches personnage (une par steamid dans ce gamemode)
-- Colonnes typées pour ce qui sert aux classements/filtres du site ;
-- "raw_data" garde l'intégralité de ce qu'envoie le jeu (y compris les
-- champs ajoutés plus tard côté Lua sans toucher à ce schéma).
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS characters (
    steamid        VARCHAR(32)   NOT NULL,
    firstname      VARCHAR(64)   NOT NULL DEFAULT '',
    lastname       VARCHAR(64)   NOT NULL DEFAULT '',
    gender         VARCHAR(16)   NOT NULL DEFAULT '',
    village        VARCHAR(32)   NOT NULL DEFAULT '',
    clan           VARCHAR(32)   NOT NULL DEFAULT '',
    rank           VARCHAR(32)   NOT NULL DEFAULT '',
    level          INT           NOT NULL DEFAULT 1,
    xp             BIGINT        NOT NULL DEFAULT 0,
    ryo            BIGINT        NOT NULL DEFAULT 0,
    stat_points    INT           NOT NULL DEFAULT 0,
    clan_points    INT           NOT NULL DEFAULT 0,
    deserter       TINYINT(1)    NOT NULL DEFAULT 0,
    origin_village VARCHAR(32)   NOT NULL DEFAULT '',
    playtime       INT UNSIGNED  NOT NULL DEFAULT 0,
    game_created   INT UNSIGNED  NOT NULL DEFAULT 0, -- horodatage Unix envoyé par le jeu (data.created)
    game_last_seen INT UNSIGNED  NOT NULL DEFAULT 0, -- horodatage Unix envoyé par le jeu (data.lastSeen)
    raw_data       MEDIUMTEXT    NULL,               -- JSON complet envoyé par /characters/sync
    updated_at     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (steamid),
    KEY idx_characters_village (village),
    KEY idx_characters_clan (clan),
    KEY idx_characters_level (level),
    KEY idx_characters_ryo (ryo),
    KEY idx_characters_playtime (playtime)
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
-- Primes / Bingo Book (miroir plein-remplacement à chaque sync)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bounties (
    id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    target_steamid VARCHAR(32)  NOT NULL DEFAULT '',
    target_name    VARCHAR(64)  NOT NULL DEFAULT '',
    amount         BIGINT       NOT NULL DEFAULT 0,
    reason         VARCHAR(160) NOT NULL DEFAULT '',
    issuer_steamid VARCHAR(32)  NOT NULL DEFAULT '',
    issuer_name    VARCHAR(64)  NOT NULL DEFAULT '',
    village        VARCHAR(32)  NOT NULL DEFAULT '',
    game_created   INT UNSIGNED NOT NULL DEFAULT 0,
    active         TINYINT(1)   NOT NULL DEFAULT 1,
    synced_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_bounties_target (target_steamid),
    KEY idx_bounties_active (active)
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
