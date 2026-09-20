--[[
    Serveur : fait télécharger le contenu requis aux joueurs et vérifie ce que
    le serveur lui-même a monté.

    resource.AddWorkshop() suffit pour que les joueurs téléchargent les addons.
    Le SERVEUR, lui, ne monte rien avec ça : pour qu'il connaisse les modèles
    (validation des tenues, hitbox, séquences), lance-le avec une collection :
        +host_workshop_collection <id de la collection>  -authkey <clé API Steam>
]]

local Content = NRP.Content

local added = {}
for _, def in ipairs(NRP.Config.Content.Addons or {}) do
    -- id 0 = contenu local (addons/naruto_content) : rien à télécharger depuis le workshop
    if (def.id or 0) > 0 then
        added[def.id] = true
    end
end
for _, id in ipairs(NRP.Config.General.Workshop or {}) do
    added[tonumber(id) or 0] = true
end

if NRP.Config.Content.AutoDownload then
    for id in pairs(added) do
        if id > 0 then
            resource.AddWorkshop(tostring(id))
        end
    end
end

hook.Add("InitPostEntity", "NRP.Content.ServerCheck", function()
    timer.Simple(1, function()
        local report = Content.Report(nil)
        -- Les animations ne se vérifient que sur un vrai joueur : côté serveur on
        -- ne teste que les fichiers.
        report.sequences = {}
        Content.PrintReport(report, "serveur")
    end)
end)

concommand.Add("nrp_content", function(ply)
    if IsValid(ply) then return end
    local report = Content.Report(nil)
    report.sequences = {}
    Content.PrintReport(report, "serveur")
end)
