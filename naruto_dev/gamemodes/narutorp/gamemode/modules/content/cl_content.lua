--[[
    Client : vérifie le contenu réellement monté chez le joueur et le lui dit
    dans le chat, avec le nom exact de l'addon à activer.

    La vérification tourne une fois après l'arrivée en jeu, puis à la demande
    (commande nrp_content).
]]

local Content = NRP.Content

local function Cfg()
    return NRP.Config.Content or {}
end

local function Warn(report)
    local theme = NRP.Config.General.Theme
    chat.AddText(theme.Error, "[Naruto RP] ", theme.Text, "Du contenu manque : tes modèles ou tes animations ne s'afficheront pas correctement.")

    for _, entry in ipairs(report.addons) do
        chat.AddText(theme.Warning, "  - ", theme.Text, entry.def.name,
            theme.TextDim, " (à activer dans le menu Addons, puis redémarrer le jeu)")
    end

    if #report.sequences > 0 and #report.addons == 0 then
        if not report.dynabase then
            chat.AddText(theme.Warning, "  - ", theme.Text,
                "wOS DynaBase est installé mais inactif : active-le dans le menu Addons et redémarre le jeu.")
        else
            chat.AddText(theme.Warning, "  - ", theme.Text,
                "Les extensions d'animation ne sont pas montées : ouvre le menu DynaBase et active-les.")
        end
    end

    chat.AddText(theme.TextDim, "  Détail complet dans la console : ", theme.Text, "nrp_content")
end

local checked = false
local function Check(manual)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local report = Content.Report(ply)
    local problems = Content.PrintReport(report, "client")

    if manual then
        if not problems then
            chat.AddText(NRP.Config.General.Theme.Success, "[Naruto RP] Tout le contenu requis est présent.")
        else
            Warn(report)
        end
        return
    end

    if problems and Cfg().WarnPlayers and not checked then
        checked = true
        Warn(report)
    end
end

-- Une fois le personnage synchronisé : le joueur a son vrai modèle, donc ses animations
hook.Add("NRP.CharSynced", "NRP.Content.Check", function()
    timer.Simple(Cfg().CheckDelay or 12, function() Check(false) end)
end)

-- Filet de sécurité : joueur sans personnage, ou synchronisation ratée
hook.Add("InitPostEntity", "NRP.Content.CheckFallback", function()
    timer.Simple((Cfg().CheckDelay or 12) + 15, function() Check(false) end)
end)

concommand.Add("nrp_content", function()
    Check(true)
end)
