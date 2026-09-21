--========================================================
-- Invisibilité Fuma (SERVEUR)
--   - dure DUREE secondes, puis le joueur réapparaît tout seul ;
--   - relancer la technique pendant l'invisibilité fait réapparaître tout de suite ;
--   - lancer un autre jutsu fait réapparaître (cl_fumainvi.lua -> Invis_Reveler) ;
--   - fumée solve_smoke_ayatsuri_geams à la disparition et à la réapparition.
--========================================================

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local ADMIN_ONLY = false   -- true = seuls les admins peuvent devenir invisibles
local DUREE      = 10      -- secondes d'invisibilité
local RECHARGE   = 8       -- secondes avant de pouvoir redevenir invisible (après la réapparition)
local FX_FUMEE   = "solve_smoke_ayatsuri_geams"   -- particles/solve_ayatsuri_geams.pcf
local SON_FUMEE  = "ambient/levels/citadel/pod_open1.wav"
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "fuma_invisibilite", stat, base) end

util.AddNetworkString("Invis_F_Toggle")
util.AddNetworkString("Invis_PAC")
util.AddNetworkString("Invis_Reveler")

local function SaveOrigColor(ent)
    if not IsValid(ent) then return end
    if ent.NA_OrigColor then return end -- déjà sauvegardé

    local c = ent:GetColor()
    ent.NA_OrigColor = Color(c.r, c.g, c.b, c.a)
end

local function RestoreOrigColor(ent)
    if not IsValid(ent) then return end
    if not ent.NA_OrigColor then return end

    ent:SetRenderMode(RENDERMODE_TRANSALPHA)
    ent:SetColor(ent.NA_OrigColor)
end

local function ApplyInvisible(ent, state)
    if not IsValid(ent) then return end

    ent:SetRenderMode(RENDERMODE_TRANSALPHA)

    if state then
        -- ON: sauvegarde + alpha 0
        SaveOrigColor(ent)
        local c = ent.NA_OrigColor or ent:GetColor()
        ent:SetNoDraw(false)          -- on peut laisser dessiner mais alpha 0
        ent:DrawShadow(false)
        ent:SetColor(Color(c.r, c.g, c.b, 0))
    else
        -- OFF: restore la vraie couleur
        ent:SetNoDraw(false)
        ent:DrawShadow(true)
        RestoreOrigColor(ent)
    end
end

local function SetInvisible(ply, state)
    if not IsValid(ply) then return end

    ply:SetNWBool("IsInvisible", state)

    -- joueur
    ApplyInvisible(ply, state)
    -- et si tu veux vraiment forcer le no draw complet :
    ply:SetNoDraw(state)

    -- arme
    local wep = ply:GetActiveWeapon()
    if IsValid(wep) then
        ApplyInvisible(wep, state)
        wep:SetNoDraw(state)
    end

    -- tête + cheveux (TES props attachés)
    ApplyInvisible(ply.NA_Head, state)
    ApplyInvisible(ply.NA_Hair, state)
    if IsValid(ply.NA_Head) then ply.NA_Head:SetNoDraw(state) end
    if IsValid(ply.NA_Hair) then ply.NA_Hair:SetNoDraw(state) end
end


-- Nuage de fumée (vu par tout le monde) + son
local function Fumee(ply)
    ParticleEffect(FX_FUMEE, ply:WorldSpaceCenter(), Angle(0, 0, 0))
    ply:EmitSound(SON_FUMEE, 70, 130, 0.6)
end

local function Apparaitre(ply)
    if not IsValid(ply) or not ply:GetNWBool("IsInvisible", false) then return end
    timer.Remove("fuma_invis_" .. ply:EntIndex())
    SetInvisible(ply, false)
    Fumee(ply)

    -- recharge après la réapparition (visible dans la barre)
    ply.NA_NextInvisToggle = CurTime() + NA_Stat(ply, "fuma_invisibilite", "recharge", RECHARGE)
    if NA_CD then NA_CD.Set(ply, "fuma_invisibilite", NA_Stat(ply, "fuma_invisibilite", "recharge", RECHARGE)) end
end
NA_FumaReapparaitre = Apparaitre   -- utilisable par d'autres scripts

local function Disparaitre(ply)
    Fumee(ply)
    SetInvisible(ply, true)
    timer.Create("fuma_invis_" .. ply:EntIndex(), Niv(ply, "duree", DUREE), 1, function() Apparaitre(ply) end)
end

net.Receive("Invis_F_Toggle", function(_, ply)
    if not NA_Debloquee(ply, "fuma_invisibilite") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() then return end
    if ADMIN_ONLY and not ply:IsAdmin() then return end

    -- déjà invisible : relancer la technique fait réapparaître tout de suite
    if ply:GetNWBool("IsInvisible", false) then
        Apparaitre(ply)
        return
    end

    if (ply.NA_NextInvisToggle or 0) > CurTime() then return end
    Disparaitre(ply)
end)

-- un autre jutsu lancé pendant l'invisibilité : on réapparaît
net.Receive("Invis_Reveler", function(_, ply)
    if IsValid(ply) then Apparaitre(ply) end
end)

hook.Add("PlayerSwitchWeapon", "Invis_KeepWeaponHidden_F", function(ply, _, newWep)
    if ply:GetNWBool("IsInvisible", false) and IsValid(newWep) then
        timer.Simple(0, function()
            if IsValid(newWep) then newWep:SetNoDraw(true) end
        end)
    end
end)

hook.Add("PlayerDeath", "Invis_ResetDeath_F", function(ply)
    timer.Remove("fuma_invis_" .. ply:EntIndex())
    if ply:GetNWBool("IsInvisible", false) then
        SetInvisible(ply, false)
    end
end)

hook.Add("PlayerSpawn", "Invis_ResetSpawn_F", function(ply)
    if ply:GetNWBool("IsInvisible", false) then
        SetInvisible(ply, false)
    end
end)
