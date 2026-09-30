--========================================================
-- Uchiha : Dragons de feu (SERVEUR)
--
-- Une zone de flammes apparaît au sol là où tu regardes (particule katon_explo_big) et
-- des dragons de feu en sortent pendant quelques secondes (visuel : cl_uchiha_dragons.lua).
-- Les ennemis dans la zone sont blessés et brûlés à chaque tick.
--========================================================

util.AddNetworkString("naruto_dev_uchih3")        -- client -> serveur : lancer
util.AddNetworkString("naruto_dev_uchih3_zone")   -- serveur -> clients : zone (pos, durée, rayon)

--========================================================
-- RÉGLAGES (valeurs par niveau : _na_niveaux_techniques.lua)
--========================================================
local COOLDOWN   = 15
local PORTEE     = 1500   -- distance max de la zone
local DUREE      = 6      -- durée de la zone
local RAYON      = 250
local INTERVALLE = 0.5    -- secondes entre deux ticks de dégâts
local DEGATS     = 8      -- par tick
local DELAI      = 0.9    -- incantation avant l'apparition de la zone
--========================================================

local function Niv(ply, stat, base) return NA_Stat(ply, "katon_dragons", stat, base) end

local nextUse = {}

local function CreerZone(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    -- là où le joueur regarde, projeté au sol
    local portee = Niv(ply, "portee", PORTEE)
    local tr = util.TraceLine({
        start  = ply:EyePos(),
        endpos = ply:EyePos() + ply:GetAimVector() * portee,
        filter = ply,
        mask   = MASK_SOLID,
    })
    local sol = util.TraceLine({
        start  = tr.HitPos + Vector(0, 0, 40),
        endpos = tr.HitPos - Vector(0, 0, 600),
        mask   = MASK_SOLID_BRUSHONLY,
    })
    local pos = sol.Hit and sol.HitPos or tr.HitPos

    local duree  = Niv(ply, "duree", DUREE)
    local rayon  = Niv(ply, "rayon", RAYON)
    local degats = Niv(ply, "degats", DEGATS)
    local inter  = Niv(ply, "intervalle", INTERVALLE)

    net.Start("naruto_dev_uchih3_zone")
    net.WriteVector(pos)
    net.WriteFloat(duree)
    net.WriteFloat(rayon)
    net.Broadcast()

    local fin = CurTime() + duree
    local id  = "uchih3_zone_" .. ply:EntIndex() .. "_" .. math.floor(CurTime() * 100)
    timer.Create(id, inter, math.max(1, math.floor(duree / inter)), function()
        if CurTime() > fin then timer.Remove(id) return end
        local owner = IsValid(ply) and ply or game.GetWorld()

        for _, ent in ipairs(ents.FindInSphere(pos, rayon)) do
            if ent == ply or not (ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot()) then continue end
            if ent:IsPlayer() and not ent:Alive() then continue end
            -- zone à plat : on ignore ceux qui sont bien au-dessus
            if math.abs(ent:GetPos().z - pos.z) > 200 then continue end

            local dmg = DamageInfo()
            dmg:SetDamage(degats)
            dmg:SetDamageType(DMG_BURN)
            dmg:SetAttacker(owner)
            dmg:SetInflictor(owner)
            dmg:SetDamagePosition(ent:WorldSpaceCenter())
            ent:TakeDamageInfo(dmg)

            if NA_Bruler then
                NA_Bruler(ent, owner, Niv(ply, "brulure_duree", 3), Niv(ply, "brulure_dps", 3))
            end
        end
    end)
end

net.Receive("naruto_dev_uchih3", function(_, ply)
    if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end
    if not NA_Debloquee(ply, "katon_dragons") then return end   -- technique pas encore débloquée (F6)

    local t = CurTime()
    if t < (nextUse[ply] or 0) then return end
    local recharge = Niv(ply, "recharge", COOLDOWN)
    nextUse[ply] = t + recharge
    if NA_CD then NA_CD.Set(ply, "katon_dragons", recharge) end

    timer.Simple(Niv(ply, "delai", DELAI), function() CreerZone(ply) end)
end)
