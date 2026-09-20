--[[
    Module contenu : vérifie que les modèles, textures et animations sont bien là.

    Un fichier absent côté client = modèle rose et noir.
    Une animation absente = jutsu sans animation (le jutsu marche quand même).
    Le but est de nommer précisément l'addon fautif, des deux côtés.
]]

NRP.Content = NRP.Content or {}
local Content = NRP.Content

local function Cfg()
    return NRP.Config.Content or {}
end

-- Addons dont au moins un fichier caractéristique est introuvable
function Content.MissingAddons()
    local missing = {}
    for _, def in ipairs(Cfg().Addons or {}) do
        for _, path in ipairs(def.files or {}) do
            if not file.Exists(path, "GAME") then
                missing[#missing + 1] = { def = def, file = path }
                break
            end
        end
    end
    return missing
end

-- Animations introuvables sur le modèle d'une entité (client uniquement en pratique :
-- le serveur ne charge pas les mêmes ressources que le joueur).
function Content.MissingSequences(ent)
    local missing = {}
    if not IsValid(ent) then return missing end
    for _, name in ipairs(Cfg().Sequences or {}) do
        local seq = ent:LookupSequence(name)
        if not seq or seq < 0 then
            missing[#missing + 1] = name
        end
    end
    return missing
end

-- DynaBase applique-t-il vraiment ses animations à cette entité ?
function Content.DynaBaseActive(ent)
    if not IsValid(ent) then return false end
    local seq = ent:LookupSequence("_dynamic_wiltos_enabled_")
    return seq ~= nil and seq >= 0
end

-- Rapport complet, utilisé par les deux réalités
function Content.Report(ent)
    return {
        addons = Content.MissingAddons(),
        sequences = Content.MissingSequences(ent),
        dynabase = Content.DynaBaseActive(ent),
    }
end

-- Écrit le rapport dans la console (serveur ou client)
function Content.PrintReport(report, who)
    local prefix = "[Naruto RP] " .. (who or "contenu") .. " : "
    if #report.addons == 0 and #report.sequences == 0 then
        NRP.Print(prefix .. "tout le contenu requis est présent")
        return false
    end

    for _, entry in ipairs(report.addons) do
        NRP.Print(string.format("%scontenu manquant ou désactivé : %s%s",
            prefix, entry.def.name, entry.def.note and (" - " .. entry.def.note) or ""))
        NRP.Print(string.format("           fichier introuvable : %s", entry.file))
        if (entry.def.id or 0) > 0 then
            NRP.Print(string.format("           https://steamcommunity.com/sharedfiles/filedetails/?id=%d", entry.def.id))
        end
    end

    if #report.sequences > 0 then
        if not report.dynabase then
            NRP.Print(prefix .. "wOS DynaBase ne s'applique pas au modèle : les animations de jutsu sont absentes")
        else
            NRP.Print(prefix .. "DynaBase est actif mais des extensions ne sont pas montées (menu DynaBase)")
        end
        for _, name in ipairs(report.sequences) do
            NRP.Print("           animation introuvable : " .. name)
        end
    end

    return true
end
