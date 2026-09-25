--========================================================
-- Suiton : Boule d'eau (CLIENT)
--
-- Envoie seulement l'appui au serveur (sv_suiton_waterball.lua, qui décide de
-- tout). La boule est affichée par l'entité suiton_waterball (lua/entities).
--========================================================

-- particule d'impact (jet_eau_hit_pat), jouée par l'entité à l'impact
game.AddParticles("particles/atg_particules2.pcf")
PrecacheParticleSystem("jet_eau_hit_pat")

-- Lancement (barre de techniques : pas de touche directe).
-- La recharge est vérifiée par NA_Lancer avec la vraie valeur du serveur.
NA_Cast = NA_Cast or {}
NA_Cast.suiton_waterball = function()
    net.Start("suiton_waterball_cast")
    net.SendToServer()
end
