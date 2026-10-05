--========================================================
-- Mudras : état "en train d'incanter" (PARTAGÉ serveur + client)
--
-- Pendant les mudras d'une technique (DUREE_MUDRA dans les fichiers serveur),
-- le joueur ne peut pas frapper : les armes (poings, épées...) lisent
-- NA_EnMudra(ply) dans lua/weapons/naruto_arme_base.lua.
--
-- Côté serveur, une technique démarre ses mudras avec :
--   NA_Mudra(ply, DUREE_MUDRA)
-- et joue ses animations de jutsu (lancer, attaque...) avec :
--   NA_AnimJutsu(ply, "nom_de_la_sequence")
-- qui bloque aussi les coups pendant toute la durée de l'animation.
-- L'état passe par un NW2Float : le client le connaît aussi, donc il ne joue
-- pas l'animation ni le son d'un coup refusé.
--========================================================

if SERVER then AddCSLuaFile() end

-- Le joueur est-il en train de faire ses mudras ?
function NA_EnMudra(ply)
    return IsValid(ply) and ply:GetNW2Float("NA_MudraFin", 0) > CurTime()
end

if CLIENT then return end

-- Le joueur fait ses mudras pendant "duree" secondes (on ne raccourcit jamais
-- des mudras déjà en cours)
function NA_Mudra(ply, duree)
    if not IsValid(ply) then return end
    local fin = CurTime() + (tonumber(duree) or 0)
    if fin > ply:GetNW2Float("NA_MudraFin", 0) then
        ply:SetNW2Float("NA_MudraFin", fin)
    end
end

-- Son d'incantation d'un jutsu, choisi dans le pack naruto_sound selon l'élément
-- (= dossier du fichier appelant dans autorun/server/<élément>/).
local NS = "naruto_sound/jutsu/"
local G  = "geams/solve_jutsu/"
local DOSSIER = {
    katon = G .. "katon", hyoton = G .. "hyoton", bakuton = G .. "bakuton", shoton = G .. "shoton",
    kami = G .. "meiton", doton = NS .. "doton", futon = NS .. "futon", futton = NS .. "futon",
    raiton = NS .. "raiton", kiminari = NS .. "raiton", jiton = NS .. "jishaku", jinton = NS .. "jishaku",
    hyuga = NS .. "hyuga", chinoike = NS .. "mugen",
}
local DEFAUT = NS .. "senju"   -- senju, mokuton, inkuton, suiton, salamandre...
-- Sons dédiés du pack (par fichier de jutsu), prioritaires sur le son d'élément
local G2 = "geams/solve_jutsu/"
local DEDIE = {
    sv_raiton_kirin = G2 .. "solve_kirin_geams.wav",
    sv_jinton_laser = "solve_naruto_base/jutsu/jinton/laser_start.wav",
    sv_jinton_cube = "solve_naruto_base/jutsu/jinton/cage_cube_start.wav",
    sv_jinton_bouclier = "solve_naruto_base/jutsu/jinton/shield_start.wav",
}
local sons = {}
local function Sons(dir)
    if not sons[dir] then sons[dir] = file.Find("sound/" .. dir .. "/*.wav", "GAME") end
    return sons[dir]
end

function NA_SonJutsu(ply, niveau)
    if not IsValid(ply) then return end
    local src = debug.getinfo(niveau or 2, "S").short_src or ""
    local dedie = DEDIE[src:match("([^/]+)%.lua$") or ""]
    if dedie then ply:EmitSound(dedie, 80, 100) return end
    local elem = src:match("autorun/server/([^/]+)/") or ""
    if elem == "inkuton" or elem == "taijutsu" then return end   -- pas de son d'incantation
    local dir = DOSSIER[elem] or ((elem == "uchiha" or elem == "kaguya" or elem == "fumaSpell") and NS .. "uchiha") or DEFAUT
    local liste = Sons(dir)
    if #liste == 0 then return end
    ply:EmitSound(dir .. "/" .. liste[math.random(#liste)], 80, math.random(95, 105))
end

-- Animation de jutsu : jouée chez tout le monde (jutsu_anim_cl.lua) et, pendant
-- sa durée (lue dans le modèle du joueur), pas de coups d'arme.
local ANIM_DUREE_DEFAUT = 0.8   -- si la séquence est introuvable sur le modèle
local ANIM_DUREE_MAX    = 0.5     -- les coups sont bloqués au plus ce temps après un jutsu (même si son animation est plus longue)

util.AddNetworkString("Jutsu_Anim_Play")

-- coupe (optionnelle) : secondes après lesquelles l'animation est coupée
-- (nil ou 0 = animation entière). Le blocage des coups s'arrête en même temps.
-- vitesse (optionnelle) : vitesse de lecture (2 = deux fois plus vite ; nil = normale)
function NA_AnimJutsu(ply, seq, coupe, vitesse)
    if not IsValid(ply) or not seq or seq == "" then return end
    coupe = tonumber(coupe) or 0
    vitesse = math.max(tonumber(vitesse) or 1, 0.1)

    net.Start("Jutsu_Anim_Play")
        net.WriteEntity(ply)
        net.WriteString(seq)
        net.WriteFloat(coupe)
        net.WriteFloat(vitesse)
    net.Broadcast()

    NA_SonJutsu(ply, 3)

    local id = ply:LookupSequence(seq)
    local duree = ((id and id >= 0) and ply:SequenceDuration(id) or ANIM_DUREE_DEFAUT) / vitesse
    if coupe > 0 then duree = math.min(duree, coupe) end
    NA_Mudra(ply, math.Clamp(duree, 0, ANIM_DUREE_MAX))
end

-- mort ou réapparition : plus de mudras
local function Arreter(ply)
    if IsValid(ply) then ply:SetNW2Float("NA_MudraFin", 0) end
end
hook.Add("PlayerDeath", "NA_Mudra_Mort", Arreter)
hook.Add("PlayerSpawn", "NA_Mudra_Spawn", Arreter)
