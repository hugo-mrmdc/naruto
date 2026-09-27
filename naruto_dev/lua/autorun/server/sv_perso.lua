--========================================================
-- Personnalisation du personnage (SERVEUR)
--
-- Reçoit le choix du menu (cl_perso_menu.lua), le valide (_na_perso.lua), le
-- mémorise sur le joueur (PData) et refait sa tête et ses cheveux
-- (sv_playerskin.lua). Les clients lisent le choix dans le NW2String "NA_Perso".
--
--   NA_PersoDe(ply)            -> choix du joueur (table validée)
--   NA_PersoDefinir(ply, p)    -> applique et sauvegarde un choix
--   Chat : !perso  (ou /perso)  ouvre le menu chez le joueur
--========================================================

if not SERVER then return end

util.AddNetworkString("NA_Perso_Envoi")
util.AddNetworkString("NA_Perso_Ouvrir")

local DELAI_ENVOI = 1      -- secondes minimum entre deux envois d'un même joueur
local TAILLE_MAX  = 1000   -- octets de JSON acceptés (un choix complet en fait ~500)

-- textures des visages (matériaux créés côté client, voir cl_perso.lua)
for _, dossier in ipairs({ "face", "shared", "eyebrows", "hair", "hair/headband_atg" }) do
    for _, f in ipairs(file.Find("materials/atg/" .. dossier .. "/*", "GAME")) do
        resource.AddFile("materials/atg/" .. dossier .. "/" .. f)
    end
end

function NA_PersoDe(ply)
    if not ply.NA_Perso then
        local json = ply:GetPData("na_perso", "")
        ply.NA_Perso = NA_PERSO.Decoder(json)
    end
    return ply.NA_Perso
end

function NA_PersoDefinir(ply, p)
    ply.NA_Perso = NA_PERSO.Valider(p)
    ply:SetPData("na_perso", NA_PERSO.Encoder(ply.NA_Perso))
    if ply:Alive() and NA_AppliquerApparence then NA_AppliquerApparence(ply) end
end

net.Receive("NA_Perso_Envoi", function(_, ply)
    if (ply.NA_PersoProchain or 0) > CurTime() then return end
    ply.NA_PersoProchain = CurTime() + DELAI_ENVOI

    local json = net.ReadString()
    if #json > TAILLE_MAX then return end

    NA_PersoDefinir(ply, util.JSONToTable(json))
    ply:ChatPrint("Apparence enregistrée.")
end)

hook.Add("PlayerSay", "NA_Perso_Chat", function(ply, texte)
    local cmd = string.lower(string.Trim(texte))
    if cmd == "!perso" or cmd == "/perso" then
        net.Start("NA_Perso_Ouvrir")
        net.Send(ply)
        return ""
    end
end)
