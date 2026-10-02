--========================================================
-- Bakuton : Déflagration (SERVEUR)
--
-- Après les mudras, le lanceur est propulsé dans le ciel (NW2Bool "NA_Vol" + NW2Float "NA_MonteVit",
-- lus par lua/kami/sh_kami_wings_move.lua), reste en l'air un instant, puis une énorme bombe d'argile
-- (entité bakuton_bombe) tombe du ciel sur le point visé et explose (mêmes particules que les autres
-- Bakuton, en beaucoup plus gros).
--
-- Réseau : "bakuton_bombe_cast" (client -> serveur)
--========================================================

util.AddNetworkString("bakuton_bombe_cast")

--========================================================
-- RÉGLAGES (valeurs par niveau : _na_niveaux_techniques.lua)
--========================================================
local RECHARGE     = 60
local CHAKRA_COUT  = 70
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local DUREE_MUDRA  = 0.6
local HAUTEUR      = 700    -- montée du lanceur (unités)
local VITESSE      = 900    -- vitesse de la montée
local ATTENTE      = 1.0    -- secondes en l'air avant de lâcher la bombe
local PORTEE       = 6000   -- portée de visée
local HAUTEUR_CHUTE = 2500  -- la bombe apparaît à cette hauteur au-dessus du point visé
local ANIM_APPEL   = "nrp_ninjutsu_defend_dragonflamebombs_start"
--========================================================

local ID = "bakuton_bombe"
local function Niv(ply, stat, base) return NA_Stat(ply, ID, stat, base) end

for _, ext in ipairs({ "mdl", "vvd", "phy", "dx80.vtx", "dx90.vtx" }) do
    resource.AddFile("models/bakuton/bomb_bakuton_solve_custom." .. ext)
end
resource.AddFile("materials/models/bomb_bakuton_solve_geams/white_clay_bomb_geams.vmt")
resource.AddFile("materials/models/bomb_bakuton_solve_geams/white_clay_bomb_geams.vtf")
resource.AddFile("materials/models/kaesar/solve/naruto_bodies/AnbuBlackOps_01/normal.vtf")
resource.AddFile("materials/models/kaesar/solve/naruto_bodies/AnbuBlackOps_01/lightwarptexture.vtf")
resource.AddFile("particles/bigboom.pcf")
resource.AddFile("sound/bakuton/solve_bakuton_explosion.wav")

local enCours = {}   -- [ply] = true pendant toute la technique (mudra, montée, attente)
local pret    = {}   -- [ply] = CurTime à partir duquel on peut relancer

local function TimerNom(ply, n) return "bakuton_bombe_" .. n .. "_" .. ply:EntIndex() end

local function Redescendre(ply)
    enCours[ply] = nil
    timer.Remove(TimerNom(ply, "montee"))
    timer.Remove(TimerNom(ply, "lacher"))
    if not IsValid(ply) then return end
    ply:SetNW2Bool("NA_Vol", false)
    ply:SetNW2Float("NA_MonteVit", -1)
    ply.MokutonNoFall = CurTime() + 10   -- on retombe de haut : pas de dégâts de chute
end

local function PointVise(ply)
    local oeil = ply:EyePos()
    local tr = util.TraceLine({ start = oeil, endpos = oeil + ply:GetAimVector() * PORTEE, filter = ply, mask = MASK_SOLID })
    if tr.Hit then return tr.HitPos end
    -- on vise le ciel : on prend le sol sous le bout du rayon
    local bas = util.TraceLine({ start = tr.HitPos, endpos = tr.HitPos - Vector(0, 0, 8000), filter = ply, mask = MASK_SOLID_BRUSHONLY })
    return bas.HitPos
end

local function LacherBombe(ply)
    if not IsValid(ply) or not ply:Alive() then Redescendre(ply) return end

    local cible = PointVise(ply)
    -- plafond éventuel au-dessus du point visé : la bombe apparaît juste dessous
    local haut = util.TraceLine({ start = cible + Vector(0, 0, 50), endpos = cible + Vector(0, 0, HAUTEUR_CHUTE), mask = MASK_SOLID_BRUSHONLY })

    local ent = ents.Create("bakuton_bombe")
    if IsValid(ent) then
        ent:SetPos(haut.HitPos - Vector(0, 0, haut.Hit and 120 or 0))
        ent:SetOwner(ply)
        ent.Degats = Niv(ply, "degats", 150)
        ent.Rayon  = Niv(ply, "rayon", 450)
        ent:Spawn()
    end

    ply:EmitSound("ambient/wind/wind_snippet1.wav", 70, 100, 0.6)
    Redescendre(ply)
end

net.Receive("bakuton_bombe_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not NA_Debloquee(ply, ID) then return end
    if enCours[ply] or (pret[ply] or 0) > CurTime() then return end
    if ply:GetNW2Bool("NA_Vol", false) or ply:GetNW2Bool("NA_Wings", false) or ply:GetNW2Bool("NA_Dragon", false) then return end

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
        if not IsValid(ply) or not ply:Alive() then enCours[ply] = nil return end

        local hauteur, vitesse = Niv(ply, "hauteur", HAUTEUR), Niv(ply, "vitesse", VITESSE)
        local depart = ply:GetPos().z
        ply:SetNW2Bool("NA_Vol", true)
        ply:SetNW2Float("NA_MonteVit", vitesse)
        ply:EmitSound("ambient/wind/wind_snippet3.wav", 75, 90, 0.7)

        -- montée : on surveille la hauteur (ou un plafond qui bloque), puis on reste en l'air
        timer.Create(TimerNom(ply, "montee"), 0.05, 0, function()
            if not IsValid(ply) or not ply:Alive() then Redescendre(ply) return end
            if ply:GetPos().z - depart >= hauteur or ply:GetVelocity().z < vitesse * 0.3 and ply:GetPos().z - depart > 50 then
                timer.Remove(TimerNom(ply, "montee"))
                ply:SetNW2Float("NA_MonteVit", 0)   -- en l'air, immobile
                timer.Create(TimerNom(ply, "lacher"), Niv(ply, "attente", ATTENTE), 1, function() LacherBombe(ply) end)
            end
        end)
        -- sécurité : si la montée ne finit jamais (coincé sous un plafond au départ), on lâche quand même
        timer.Create(TimerNom(ply, "lacher"), (hauteur / vitesse) + 1.5, 1, function() LacherBombe(ply) end)
    end)
end)

hook.Add("PlayerDeath", "BakutonBombe_Mort", Redescendre)
hook.Add("PlayerSpawn", "BakutonBombe_Spawn", function(ply) if enCours[ply] then Redescendre(ply) end end)

hook.Add("PlayerDisconnected", "BakutonBombe_Nettoyage", function(ply)
    Redescendre(ply)
    pret[ply] = nil
end)
