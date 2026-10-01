--========================================================
-- Atterrissage (SERVEUR)
--   - animation d'atterrissage jouée à chaque réception, vue par tout le monde ;
--   - atterrir accroupi (Ctrl maintenu) annule les dégâts de chute.
--========================================================

--========================================================
-- RÉGLAGES
--========================================================
-- Animation d'atterrissage
local ANIM_ATTERRISSAGE = "nrp_base_land"       -- "" = pas d'animation
-- Hauteur de chute minimale (en unités) pour jouer l'animation.
-- En dessous, c'est l'atterrissage de base de Garry's Mod.
--   saut normal       ~ 35 unités  -> atterrissage de base
--   double saut       ~ 130 unités -> animation
--   1 étage           ~ 130 unités
local HAUTEUR_MIN_ANIM = 100

-- Réception accroupie
local ACTIF = true
local SON   = "physics/body/body_medium_impact_soft1.wav"   -- "" = pas de son
--========================================================

hook.Add("GetFallDamage", "NA_ChuteAccroupi", function(ply, vitesse)
    if not ACTIF then return end

    -- accroupi, ou en train de s'accroupir au moment du contact
    if ply:Crouching() or ply:KeyDown(IN_DUCK) then
        if SON ~= "" then ply:EmitSound(SON, 65, 100, 0.6) end
        return 0
    end
end)

hook.Add("OnPlayerHitGround", "NA_AnimAtterrissage", function(ply, dansLEau, surFlotteur, vitesse)
    if ANIM_ATTERRISSAGE == "" or dansLEau then return end
    if not IsValid(ply) or not ply:Alive() then return end
    -- hauteur de chute d'après la vitesse d'impact : h = v² / (2 × gravité)
    local gravite = GetConVar("sv_gravity"):GetFloat()
    if gravite <= 0 then return end
    local hauteur = vitesse * vitesse / (2 * gravite)
    if hauteur < HAUTEUR_MIN_ANIM then return end
    -- pas pendant les vols / montures qui gèrent déjà leur animation
    if ply:GetNW2Bool("NA_Wings", false) or (ply:GetNWBool("MokutonRide", false) or ply:GetNWBool("InkutonRide", false)) then return end
    -- frappe terrestre Senju lancée en l'air : son animation ne doit pas être masquée par celle d'atterrissage
    if ply:GetNW2Float("NA_FrappeFin", 0) > CurTime() then return end

    -- message réseau du système d'animation de l'addon (jutsu_anim_sv.lua)
    net.Start("Jutsu_Anim_Play")
        net.WriteEntity(ply)
        net.WriteString(ANIM_ATTERRISSAGE)
    net.Broadcast()
end)
