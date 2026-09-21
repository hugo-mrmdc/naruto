--========================================================
-- Chakra : réserve maximale (PARTAGÉ serveur + client, chargé en premier)
--
-- C'est le SEUL endroit où changer le chakra maximum des joueurs.
-- Tout le reste lit NA_CHAKRA_MAX : régénération et course de chakra
-- (sv_sprint_chakra.lua), barre du HUD (cl_hud_vie.lua, cl_sprint_chakra.lua),
-- dash, double saut et toutes les techniques.
--
-- Les autres réglages du chakra (régénération, délai, course de chakra)
-- sont dans autorun/server/sv_sprint_chakra.lua.
--========================================================

if SERVER then AddCSLuaFile() end

NA_CHAKRA_MAX = 500   -- chakra maximum
