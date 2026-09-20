--[[
    Module : missions (partagé)

    Ajouter une mission : config/missions.lua ou NRP.Missions.Registry:Register(id, def)
    Ajouter un type     : NRP.Missions.RegisterType("id", { name = "…", Start = …, Check = … })
                          (voir modules/missions/types/)
]]

NRP.Missions = NRP.Missions or {}
local Missions = NRP.Missions

Missions.Types = Missions.Types or {}

function Missions.RegisterType(id, def)
    local existing = Missions.Types[id] or { id = id }
    for k, v in pairs(def) do existing[k] = v end
    Missions.Types[id] = existing
end

-- Noms affichables (les comportements sont enregistrés côté serveur)
Missions.RegisterType("delivery", { name = "Livraison" })
Missions.RegisterType("retrieve", { name = "Récupération" })
Missions.RegisterType("eliminate", { name = "Élimination" })
Missions.RegisterType("escort", { name = "Escorte" })
Missions.RegisterType("protect", { name = "Protection" })
Missions.RegisterType("recon", { name = "Reconnaissance" })
Missions.RegisterType("defend", { name = "Défense de zone" })
Missions.RegisterType("boss", { name = "Boss" })

Missions.Registry = NRP.CreateRegistry("missions", {
    defaults = {
        description = "",
        rank = "D",
        minLevel = 1,
        timeLimit = 900,
        cooldown = 300,
        party = { 1, 4 },
        params = {},
        rewards = {},
    },
    validate = function(def)
        if not isstring(def.name) then return false, "nom manquant" end
        if not NRP.Config.MissionSettings.Ranks[def.rank] then return false, "rang inconnu" end
        if not Missions.Types[def.type] then return false, "type inconnu " .. tostring(def.type) end
        return true
    end,
})

Missions.Registry:RegisterAll(NRP.Config.Missions)

NRP.Char.RegisterField("missionData", { type = "json", default = { cooldowns = {}, completed = {} } })

function Missions.GetRank(rank)
    return NRP.Config.MissionSettings.Ranks[rank]
end

--[[
    Disponibilité d'une mission pour un personnage devant un tableau de missions
    (boardVillage = village du PNJ, "" = tous). Retourne true ou false, raison.
]]
function Missions.CheckAvailability(data, def, boardVillage)
    if not data then return false, "Aucun personnage" end
    local village = data.deserter and "nukenin" or data.village

    if boardVillage and boardVillage ~= "" and boardVillage ~= village then
        return false, "Réservée à un autre village"
    end

    if def.villages then
        if not table.HasValue(def.villages, village) then
            return false, "Indisponible pour votre village"
        end
    elseif village == "nukenin" then
        return false, "Les déserteurs n'ont pas accès à cette mission"
    end

    if not NRP.Ranks.CanAccessMissionRank(data.rank, def.rank) then
        return false, "Grade insuffisant pour le " .. Missions.GetRank(def.rank).name
    end

    if def.minRank and NRP.Ranks.GetOrder(data.rank) < NRP.Ranks.GetOrder(def.minRank) then
        return false, "Grade " .. NRP.Ranks.GetName(def.minRank) .. " requis"
    end

    if (data.level or 1) < def.minLevel then
        return false, "Niveau " .. def.minLevel .. " requis"
    end

    local cd = tonumber(data.missionData and data.missionData.cooldowns[def.id]) or 0
    if cd > os.time() then
        return false, "Disponible dans " .. NRP.Util.FormatTime(cd - os.time())
    end

    return true
end
