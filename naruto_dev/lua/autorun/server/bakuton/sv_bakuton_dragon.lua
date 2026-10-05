--========================================================
-- Bakuton : Dragon d'argile (SERVEUR)
--
-- Après les mudras, un dragon d'argile (modèle atg_dragon_bakuton, affiché par cl_bakuton_dragon.lua
-- d'après NW2Bool "NA_Dragon") porte le lanceur : il VOLE, avec le même pilotage que les ailes de
-- papier (NW2Bool "NA_Vol", lua/kami/sh_kami_wings_move.lua : ZQSD, Espace monte, Ctrl descend).
-- Il dure DUREE secondes ; E (ou relancer la technique) permet d'en descendre avant.
--
-- Réseau : "bakuton_dragon_cast" (client -> serveur)
--========================================================

util.AddNetworkString("bakuton_dragon_cast")

--========================================================
-- RÉGLAGES (valeurs par niveau : _na_niveaux_techniques.lua)
--========================================================
local DUREE        = 20     -- secondes sur le dragon
local RECHARGE     = 45     -- secondes avant de pouvoir relancer (depuis le lancement)
local CHAKRA_COUT  = 40
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local DUREE_MUDRA  = 0.6
local ANIM_APPEL   = "nrp_ninjutsu_defend_dragonflamebombs_start"

local TOUCHE_DESCENDRE = IN_USE   -- E
--========================================================

local ID = "bakuton_dragon"
local function Niv(ply, stat, base) return NA_Stat(ply, ID, stat, base) end

for _, ext in ipairs({ "mdl", "vvd", "dx80.vtx", "dx90.vtx" }) do
    resource.AddFile("models/bakuton/atg_dragon_bakuton." .. ext)
end
for _, f in ipairs({ "atg_bakuton_dragon1.vmt", "atg_bakuton_dragon1.vtf", "atg_bakuton_dragon2.vmt", "atg_bakuton_dragon2.vtf" }) do
    resource.AddFile("materials/atg/pvp/bakuton/atg_dragon/" .. f)
end
resource.AddFile("materials/atg/pvp/bakuton/atg_mignon/atg_outline.vmt")
resource.AddFile("materials/atg/pvp/bakuton/atg_mignon/atg_outline.vtf")
resource.AddFile("materials/atg_props/shared/normal.vtf")
resource.AddFile("materials/atg_props/shared/lightwarpshader_bakuton.vtf")

local enCours = {}
local pret    = {}

local function TimerNom(ply) return "bakuton_dragon_" .. ply:EntIndex() end

local function Descendre(ply)
    if not IsValid(ply) or not ply:GetNW2Bool("NA_Dragon", false) then return end
    timer.Remove(TimerNom(ply))

    ply:SetNW2Bool("NA_Dragon", false)
    ply:SetNW2Bool("NA_Vol", false)
    ply.MokutonNoFall = CurTime() + 5   -- on peut retomber de haut : pas de dégâts de chute
    ply:EmitSound("geams/solve_jutsu/bakuton/solve_bakuton_bigexplosion.wav", 65, 110, 0.5)
end

local function Monter(ply)
    if not IsValid(ply) then return end

    ply:SetNW2Bool("NA_Dragon", true)
    ply:SetNW2Bool("NA_Vol", true)
    ply:SetVelocity(Vector(0, 0, 200))   -- petit décollage
    ply:EmitSound("geams/solve_jutsu/bakuton/solve_bakuton_flying_bird.wav", 70, 90, 0.6)

    timer.Create(TimerNom(ply), Niv(ply, "duree", DUREE), 1, function() Descendre(ply) end)
end

net.Receive("bakuton_dragon_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not NA_Debloquee(ply, ID) then return end
    if ply:GetNW2Bool("NA_Dragon", false) then Descendre(ply) return end   -- relancer = descendre
    if enCours[ply] or (pret[ply] or 0) > CurTime() then return end
    if ply:GetNW2Bool("NA_Vol", false) or ply:GetNW2Bool("NA_Wings", false) then return end   -- déjà en vol

    local cout = Niv(ply, "chakra", CHAKRA_COUT)
    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if cout > 0 then
        if chakra < cout then
            ply:PrintMessage(HUD_PRINTCENTER, "Pas assez de chakra")
            return
        end
        ply:SetNW2Float("NA_Chakra", chakra - cout)
    end

    local recharge = Niv(ply, "recharge", RECHARGE)
    enCours[ply] = true
    pret[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, ID, recharge) end

    NA_AnimJutsu(ply, ANIM_APPEL)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    if NA_Mudra then NA_Mudra(ply, mudra) end
    timer.Simple(mudra, function()
        enCours[ply] = nil
        if not IsValid(ply) or not ply:Alive() then return end
        Monter(ply)
    end)
end)

-- E : on descend du dragon
hook.Add("KeyPress", "BakutonDragon_Descendre", function(ply, key)
    if key == TOUCHE_DESCENDRE then Descendre(ply) end
end)

hook.Add("PlayerDeath", "BakutonDragon_Mort", function(ply)
    enCours[ply] = nil
    Descendre(ply)
end)

hook.Add("PlayerSpawn", "BakutonDragon_Spawn", Descendre)

hook.Add("PlayerDisconnected", "BakutonDragon_Nettoyage", function(ply)
    enCours[ply] = nil
    pret[ply] = nil
    timer.Remove(TimerNom(ply))
end)
