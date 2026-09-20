--[[
    Module : personnage (partagé)

    Chaque module déclare les champs qu'il persiste :
        NRP.Char.RegisterField("clan", {
            type = "string",           -- string | int | bigint | float | bool | json
            default = "",              -- valeur ou fonction
            nw = "String",             -- (optionnel) donnée publique via SetNW2String("NRP_Clan")
            nwKey = "NRP_Clan",
            sync = true,               -- envoyé au propriétaire (défaut true)
            save = true,               -- sauvegardé en base (défaut true)
        })
    La table SQL "characters" est générée à partir de ces champs (colonnes ajoutées automatiquement).

    Données publiques (tous les joueurs) : NW2 -> nom, village, clan, grade, niveau, déserteur.
    Données privées (propriétaire uniquement) : net "NRP.CharSync".
]]

NRP.Char = NRP.Char or {}
local Char = NRP.Char

Char.Fields = {}
Char.FieldList = {}

function Char.RegisterField(key, opts)
    opts.key = key
    opts.column = opts.column or string.lower((string.gsub(key, "(%u)", "_%1")))
    opts.type = opts.type or "string"
    if opts.save == nil then opts.save = true end
    if opts.sync == nil then opts.sync = true end

    if not Char.Fields[key] then
        Char.FieldList[#Char.FieldList + 1] = key
    end
    Char.Fields[key] = opts
end

function Char.DefaultValue(key)
    local field = Char.Fields[key]
    if not field then return nil end
    local d = field.default
    if isfunction(d) then return d() end
    if istable(d) then return table.Copy(d) end
    return d
end

-- Registre des éléments (affinités)
NRP.Elements = NRP.CreateRegistry("elements", {
    validate = function(def) return isstring(def.name), "nom manquant" end,
})
NRP.Elements:RegisterAll(NRP.Config.Elements)

-- Champs de base
Char.RegisterField("firstname", { type = "string", default = "" })
Char.RegisterField("lastname", { type = "string", default = "" })
Char.RegisterField("gender", { type = "string", default = "male" })
Char.RegisterField("model", { type = "string", default = "" })
Char.RegisterField("skin", { type = "int", default = 0 })
Char.RegisterField("bodygroups", { type = "json", default = {} })
Char.RegisterField("color", { type = "json", default = { 255, 255, 255 } })
Char.RegisterField("village", { type = "string", default = "", nw = "String", nwKey = "NRP_Village" })
Char.RegisterField("affinities", { type = "json", default = {} })
Char.RegisterField("ryo", { type = "bigint", default = 0 })
Char.RegisterField("flags", { type = "json", default = {} })
Char.RegisterField("playtime", { type = "int", default = 0, sync = false })
Char.RegisterField("created", { type = "int", default = 0 })
Char.RegisterField("lastSeen", { type = "int", default = 0, sync = false })

---------------------------------------------------------------------------
-- Accès (partagé)
---------------------------------------------------------------------------

function Char.IsLoaded(ply)
    if not IsValid(ply) then return false end
    if SERVER then return ply.NRPChar ~= nil end
    return ply:GetNW2Bool("NRP_Loaded", false)
end

-- Données privées : serveur -> tout joueur ; client -> joueur local seulement
function Char.GetData(ply)
    if SERVER then
        return ply.NRPChar
    end
    if ply == LocalPlayer() then
        return Char.Local
    end
end

function Char.Get(ply, key, fallback)
    local data = Char.GetData(ply)
    if data and data[key] ~= nil then
        return data[key]
    end
    return fallback
end

function Char.GetName(ply)
    local name = ply:GetNW2String("NRP_Name", "")
    if name == "" then
        return ply.SteamName and ply:SteamName() or "Inconnu"
    end
    return name
end

function Char.GetVillage(ply)
    return ply:GetNW2String("NRP_Village", "")
end

function Char.GetClan(ply)
    return ply:GetNW2String("NRP_Clan", "")
end

function Char.GetRank(ply)
    return ply:GetNW2String("NRP_Rank", "")
end

function Char.GetLevel(ply)
    return ply:GetNW2Int("NRP_Level", 1)
end

function Char.IsDeserter(ply)
    return ply:GetNW2Bool("NRP_Deserter", false)
end

function Char.HasAffinity(data, element)
    for _, e in ipairs(data and data.affinities or {}) do
        if e == element then return true end
    end
    return false
end

function Char.PrimaryAffinity(data)
    return data and data.affinities and data.affinities[1] or nil
end

---------------------------------------------------------------------------
-- Nom RP comme pseudo
---------------------------------------------------------------------------

local meta = FindMetaTable("Player")
meta.SteamName = meta.SteamName or meta.Nick

local function RPNick(self)
    if (NRP.Config.General or {}).OverrideNick then
        local name = self:GetNW2String("NRP_Name", "")
        if name ~= "" then return name end
    end
    return self:SteamName()
end

meta.Nick = RPNick
meta.Name = RPNick
meta.GetName = RPNick
