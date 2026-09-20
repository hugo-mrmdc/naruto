--========================================================
-- Étourdissement commun (SERVEUR)
--
--   NA_Etourdir(ent, secondes)  -> immobilise un joueur / PNJ pendant ce temps
--   NA_EstEtourdi(ent)          -> true s'il est étourdi
--
-- Joueurs : Freeze + NW2Bool "NA_Etourdi" (animation : cl_etourdi_anim.lua,
-- jutsus bloqués : _na_registre.lua). PNJ : maintenus sur place.
-- Plusieurs étourdissements se cumulent : on garde la fin la plus tardive.
--========================================================

local etourdis = {}   -- entité -> true

function NA_EstEtourdi(ent)
    return IsValid(ent) and (ent.NA_EtourdiFin or 0) > CurTime()
end

function NA_Etourdir(ent, duree)
    if not IsValid(ent) or duree <= 0 then return end
    ent.NA_EtourdiFin = math.max(ent.NA_EtourdiFin or 0, CurTime() + duree)
    etourdis[ent] = true

    if ent:IsPlayer() then
        ent:Freeze(true)
        ent:SetNW2Bool("NA_Etourdi", true)
        ent:SetVelocity(-ent:GetVelocity())
    else
        ent.NA_EtourdiPos = ent.NA_EtourdiPos or ent:GetPos()
        if ent:IsNPC() then
            ent:ClearSchedule()
            ent:StopMoving()
        end
    end
end

local function CubeActif(ent)
    for _, cube in ipairs(ents.FindByClass("jinton_cube")) do
        if cube.Actif and cube:GetCible() == ent then return true end
    end
    return false
end

local function Liberer(ent)
    etourdis[ent] = nil
    if not IsValid(ent) then return end
    ent.NA_EtourdiFin = nil
    ent.NA_EtourdiPos = nil
    if CubeActif(ent) then return end   -- le cube Jinton le tient encore : il le libérera

    if ent:IsPlayer() then
        ent:Freeze(false)
        ent:SetNW2Bool("NA_Etourdi", false)
    end
end
NA_Liberer = Liberer

hook.Add("Think", "NA_Etourdissement", function()
    local now = CurTime()
    for ent in pairs(etourdis) do
        if not IsValid(ent) then
            etourdis[ent] = nil
        elseif now >= (ent.NA_EtourdiFin or 0) then
            Liberer(ent)
        elseif ent:IsPlayer() then
            ent:SetVelocity(-ent:GetVelocity())
        elseif ent.NA_EtourdiPos then
            ent:SetPos(ent.NA_EtourdiPos)
            ent:SetVelocity(vector_origin)
            if ent:IsNPC() then ent:StopMoving() end
        end
    end
end)

hook.Add("PlayerDeath", "NA_Etourdissement_Mort", function(ply)
    if etourdis[ply] then Liberer(ply) end
end)
