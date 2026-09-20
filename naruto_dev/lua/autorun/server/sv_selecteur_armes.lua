--========================================================
-- Sélecteur d'armes à la molette (SERVEUR)
-- Équipe l'élément choisi dans le menu (cl_selecteur_armes.lua).
--
-- L'épée proposée est celle équipée dans l'emplacement "Arme" du menu F4
-- (cl_monmenu.lua) : mémorisée dans NW2String "NA_Epee", donnée au joueur,
-- et redonnée à chaque réapparition.
--========================================================

util.AddNetworkString("NA_Selecteur_Choisir")
util.AddNetworkString("NA_EquiperEpee")
util.AddNetworkString("NA_RetirerEpee")
util.AddNetworkString("NA_EpeeDos")

for _, f in ipairs({ "camera", "empty", "poing", "sword", "cercle_wp", "demi_cercle_wp" }) do
    resource.AddFile("materials/ui/hud/weapon_selector/" .. f .. ".png")
end

local function Equiper(ply, classe)
    if not ply:HasWeapon(classe) then ply:Give(classe) end
    ply:SelectWeapon(classe)
end

-- Une classe d'arme peut-elle être équipée comme épée ?
local function EstEpee(classe)
    local def = weapons.Get(classe)
    return def ~= nil and def.NA_Arme == true and def.Spawnable == true and classe ~= "naruto_poings"
end

----------------------------------------------------------
-- Épée équipée depuis le menu F4
----------------------------------------------------------
local function RetirerEpee(ply)
    local ancienne = ply:GetNW2String("NA_Epee", "")
    if ancienne ~= "" and ply:HasWeapon(ancienne) then ply:StripWeapon(ancienne) end
    ply:SetNW2String("NA_Epee", "")
end

local function EquiperEpee(ply, classe)
    if ply:GetNW2String("NA_Epee", "") == classe and ply:HasWeapon(classe) then return end
    RetirerEpee(ply)
    ply:SetNW2String("NA_Epee", classe)
    if not ply:HasWeapon(classe) then ply:Give(classe, true) end   -- rangée dans le dos
end

local prochainF4 = {}
local function AntiSpam(ply)
    if (prochainF4[ply] or 0) > CurTime() then return false end
    prochainF4[ply] = CurTime() + 0.25
    return true
end

net.Receive("NA_EquiperEpee", function(_, ply)
    local classe = net.ReadString()
    if not IsValid(ply) or not AntiSpam(ply) or not EstEpee(classe) then return end
    EquiperEpee(ply, classe)
end)

net.Receive("NA_RetirerEpee", function(_, ply)
    if not IsValid(ply) or not AntiSpam(ply) then return end
    RetirerEpee(ply)
end)

-- Placement de l'épée dans le dos, réglé dans le menu F4 (vu par tout le monde)
local DECALAGE_MAX = 60
net.Receive("NA_EpeeDos", function(_, ply)
    local classe = net.ReadString()
    local reinit = net.ReadBool()
    local pos, ang, echelle
    if not reinit then
        pos, ang, echelle = net.ReadVector(), net.ReadAngle(), net.ReadFloat()
    end
    if not IsValid(ply) or not EstEpee(classe) then return end

    ply.NA_DosEpees = ply.NA_DosEpees or {}
    if reinit then
        ply.NA_DosEpees[classe] = nil
    else
        local function B(v) return math.Clamp(v, -DECALAGE_MAX, DECALAGE_MAX) end
        ply.NA_DosEpees[classe] = {
            x = B(pos.x), y = B(pos.y), z = B(pos.z),
            p = math.NormalizeAngle(ang.p), ya = math.NormalizeAngle(ang.y), r = math.NormalizeAngle(ang.r),
            s = math.Clamp(echelle, 0.1, 3),
        }
    end
    ply:SetNW2String("NA_EpeeDos", next(ply.NA_DosEpees) and util.TableToJSON(ply.NA_DosEpees) or "")
end)

-- l'épée équipée revient à chaque apparition (les armes sont retirées à la mort)
hook.Add("PlayerSpawn", "NA_Epee_Redonner", function(ply)
    timer.Simple(0.3, function()
        if not IsValid(ply) or not ply:Alive() then return end
        local classe = ply:GetNW2String("NA_Epee", "")
        if classe ~= "" and not ply:HasWeapon(classe) then ply:Give(classe, true) end
    end)
end)

local ACTIONS = {
    camera = function(ply) end,                                  -- rien pour l'instant
    mains  = function(ply) Equiper(ply, "hand") end,             -- mains vides
    poings = function(ply) Equiper(ply, "naruto_poings") end,    -- coups de poing
    epee   = function(ply)                                       -- l'épée équipée dans le menu F4
        local classe = ply:GetNW2String("NA_Epee", "")
        if classe ~= "" then Equiper(ply, classe) end
    end,
}

local prochain = {}

net.Receive("NA_Selecteur_Choisir", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if (prochain[ply] or 0) > CurTime() then return end
    prochain[ply] = CurTime() + 0.15

    local action = ACTIONS[net.ReadString()]
    if action then action(ply) end
end)

hook.Add("PlayerDisconnected", "NA_Selecteur_Nettoyage", function(ply)
    prochain[ply] = nil
    prochainF4[ply] = nil
end)
