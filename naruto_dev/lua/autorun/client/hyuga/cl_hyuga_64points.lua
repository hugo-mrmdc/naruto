--========================================================
-- Hyuga : 64 Points du Hakke (CLIENT)
-- Lancement depuis la barre de techniques (l'animation passe par
-- Jutsu_Anim_Play, jutsu_anim_cl.lua, sans code ici). Particule au sol sous
-- la cible touchée ("hyuga_64points_fx", sv_hyuga_64points.lua) — copie de la
-- 32 Points (cl_hyuga_32points.lua) avec cette particule à la place de aegvfc.
--========================================================

--========================================================
-- RÉGLAGES
--========================================================
local FX_IMPACT = "hyuga_floor_pat_64"   -- particles/patlick_atgparticules.pcf
local FX_HAUTEUR = 5        -- au-dessus des pieds (0 = pile au sol)

local FX_HIT      = "aegvfc"   -- particles/ctg_hyuga_nael.pcf (même particule d'impact que la 32 Points)

local ANIM_LOOP = "attack_hyuga_64poings"   -- doit matcher ANIM_APPEL de sv_hyuga_64points.lua
--========================================================

-- Séquence à forcer sur "ply" tant que NA_Hakke64PoingsFin est dans le futur
-- (comme cl_etourdi_anim.lua / cl_hyuga_tourbillon.lua) : boucle sans
-- redémarrer sans arrêt tant que le stun (et donc la rafale) n'est pas fini.
local function SeqHakke64(ply)
    if ply:GetNW2Float("NA_Hakke64PoingsFin", 0) > CurTime() then
        local seq = ply:LookupSequence(ANIM_LOOP)
        if seq and seq >= 0 then return seq end
    end
end

hook.Add("CalcMainActivity", "NA_Hakke64Poings_Anim", function(ply)
    local seq = SeqHakke64(ply)
    if seq then return ACT_MP_STAND_IDLE, seq end
end)

-- forcée à chaque image : aucune autre animation ne la remplace tant que ça dure.
-- "attack_hyuga_64poings" n'est pas une séquence loopée nativement (contrairement
-- à "..._slow" de la 32 Points) : se fier à GetCycle() pour savoir quand la
-- reboucler ne marche pas bien ici (elle se bloque sur la 1ère frame). On
-- pilote donc le cycle nous-mêmes à partir du temps écoulé depuis le lancer.
hook.Add("UpdateAnimation", "NA_Hakke64Poings_Anim_Force", function(ply)
    local seq = SeqHakke64(ply)
    if not seq then return end
    if ply:GetSequence() ~= seq then
        ply:SetSequence(seq)
    end

    local natDuree = ply:SequenceDuration(seq)
    if natDuree > 0 then
        local debut = ply:GetNW2Float("NA_Hakke64PoingsDebut", CurTime())
        local phase = (CurTime() - debut) % natDuree
        ply:SetCycle(phase / natDuree)
    end
    ply:SetPlaybackRate(0)   -- le cycle est piloté à la main juste au-dessus
    return true
end)

NA_Cast = NA_Cast or {}
NA_Cast.hyuga_64points = function()
    net.Start("hyuga_64points_cast")
    net.SendToServer()
end

game.AddParticles("particles/patlick_atgparticules.pcf")
PrecacheParticleSystem(FX_IMPACT)
game.AddParticles("particles/ctg_hyuga_nael.pcf")
PrecacheParticleSystem(FX_HIT)

net.Receive("hyuga_64points_fx", function()
    local ply = net.ReadEntity()
    local ent = net.ReadEntity()
    local etourdi = net.ReadFloat()   -- durée réelle du stun (Niv, sv_hyuga_64points.lua) : les particules doivent disparaître pile à ce moment
    if not IsValid(ent) then return end

    -- cercle au sol sous le LANCEUR (pas la cible), position figée une fois
    -- pour toutes. Parenté au MONDE (game.GetWorld()) : une entité animée
    -- (bones, hitbox) peut retoucher le control point à chaque invalidation
    -- de bones même en PATTACH_WORLDORIGIN. Le monde, lui, ne bouge jamais.
    if IsValid(ply) then
        local pos = ply:GetPos() + Vector(0, 0, FX_HAUTEUR)
        local fx = CreateParticleSystem(game.GetWorld(), FX_IMPACT, PATTACH_WORLDORIGIN, 0, pos)
        if fx and fx:IsValid() then
            timer.Simple(etourdi, function()
                if IsValid(fx) then fx:StopEmissionAndDestroyImmediately() end
            end)
        end
    end

    -- particule d'impact sur la cible (buste), comme la 32 Points
    local fxHit = CreateParticleSystem(ent, FX_HIT, PATTACH_ABSORIGIN_FOLLOW, 0, Vector(0, 0, ent:OBBMaxs().z * 0.5))
    if fxHit and fxHit:IsValid() then
        timer.Simple(etourdi, function()
            if IsValid(fxHit) then fxHit:StopEmissionAndDestroyImmediately() end
        end)
    end
end)
