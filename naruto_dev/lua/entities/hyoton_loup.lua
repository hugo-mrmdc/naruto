--========================================================
-- Hyoton : Loup de glace (entité) : même comportement que inkuton_serpent (rampe au sol vers la cible visée,
-- virage à vitesse limitée, un contact = des dégâts, un mur l'arrête), avec le modèle loeve_hyoton_wolf et
-- la particule izox_hyoton_hit (particles/1izoxsolvenr.pcf). Le modèle n'a pas d'animation (pas d'ondulation).
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "inkuton_serpent"
ENT.PrintName = "Loup de glace"
ENT.Spawnable = false

ENT.Model     = "models/hyoton/loeve_hyoton_wolf.mdl"
ENT.PCF       = "particles/1izoxsolvenr.pcf"
ENT.FX_SPAWN  = "izox_hyoton_hit"
ENT.FX_TRACE  = "izox_hyoton_hit"
ENT.FX_HIT    = "izox_hyoton_hit"
ENT.FX_CIBLE  = "izox_hyoton_hit"

ENT.Echelle     = 0.7   -- le modèle fait ~240 unités de long à l'échelle 1 : ajuster si trop gros / petit
ENT.RayonTouche = 60
ENT.DecalageYaw = 90    -- le modèle est long sur son axe Y : si il n'avance pas par la tête, essayer -90, 0 ou 180

if CLIENT then
    game.AddParticles(ENT.PCF)   -- une seule fois (la classe de base charge celui des serpents d'encre)
    PrecacheParticleSystem(ENT.FX_HIT)
end
