--[[
    UI : onglet ADMIN (visible avec la permission admin.menu)
    Chaque action exécute une commande serveur : le serveur vérifie la permission de CETTE commande.
    Les boutons dont la permission manque sont simplement grisés (confort).
]]

local UI = NRP.UI
local S = UI.S
local Admin = NRP.Admin

local selected

local function RegistryChoices(registry, extra)
    local out = {}
    for _, e in ipairs(extra or {}) do out[#out + 1] = e end
    for id, def in registry:Iterate() do
        out[#out + 1] = { (def.name or id) .. "  (" .. id .. ")", id }
    end
    return out
end

-- Ouvre une fenêtre avec une liste déroulante (+ saisie optionnelle) puis exécute la commande
local function PickAndRun(title, choices, command, target, askText, defaultText, prefix)
    local frame = vgui.Create("NRP.Frame")
    frame:SetSize(S(460), askText and S(270) or S(210))
    frame:Center()
    frame:SetHeader(title, IsValid(target) and target:Nick() or nil)
    frame:MakePopup()

    local value
    local combo = UI.Combo(frame, choices, function(data) value = data end)
    combo:Dock(TOP)
    combo:SetValue("Choisir…")

    local entry
    if askText then
        UI.Label(frame, askText, "NRP.Small", UI.Theme().TextDim):DockMargin(0, S(10), 0, S(4))
        entry = UI.TextEntry(frame)
        entry:Dock(TOP)
        entry:SetText(defaultText or "")
    end

    local ok = UI.Button(frame, "Exécuter", function()
        if value == nil then return end
        local args = {}
        if prefix then args[#args + 1] = prefix end
        args[#args + 1] = value
        if entry then args[#args + 1] = entry:GetValue() end
        Admin.Run(command, target, unpack(args))
        frame:Remove()
    end)
    ok:Dock(BOTTOM)
end

local function AskAndRun(title, text, command, target, default)
    UI.RequestText(title, text, default or "", function(value)
        if value ~= "" then Admin.Run(command, target, value) end
    end)
end

local function ActionButton(parent, label, perm, fn, style)
    local btn = UI.Button(parent, label, fn, style or "ghost")
    btn:SetFont("NRP.Small")
    btn:SetTall(S(32))
    if perm and not NRP.Perm.Has(LocalPlayer(), perm) then
        btn:SetDisabledReason("Permission requise : " .. perm)
    end
    return btn
end

local function ButtonGrid(parent, buttons)
    local grid = vgui.Create("DIconLayout", parent)
    grid:Dock(TOP)
    grid:SetSpaceX(S(6))
    grid:SetSpaceY(S(6))
    grid:DockMargin(0, 0, 0, S(6))
    for _, b in ipairs(buttons) do
        local btn = ActionButton(grid, b[1], b[2], b[3], b[4])
        btn:SetWide(S(200))
    end
    return grid
end

local function PlayerActions(panel, target)
    local theme = UI.Theme()
    UI.Label(panel, target:Nick(), "NRP.Title", theme.Accent)
    UI.Label(panel, target:SteamName() .. "  •  " .. (target:SteamID64() or "bot") .. "  •  " .. target:GetUserGroup(), "NRP.Small", theme.TextDim)

    local Villages = NRP.Villages

    UI.Section(panel, "Progression")
    ButtonGrid(panel, {
        { "Donner de l'XP", "admin.xp", function() AskAndRun("XP", "Quantité (négatif pour retirer)", "givexp", target, "100") end },
        { "Définir le niveau", "admin.xp", function() AskAndRun("Niveau", "Nouveau niveau", "setlevel", target) end },
        { "Points de stats", "admin.stats", function() AskAndRun("Points", "Points à ajouter", "statpoints", target, "3") end },
        { "Réinitialiser les stats", "admin.stats", function() Admin.Run("resetstats", target) end },
        { "Changer le grade", "admin.rank", function()
            local choices = {}
            for _, r in ipairs(NRP.Ranks.Sorted()) do choices[#choices + 1] = { r.name, r.id } end
            PickAndRun("Grade", choices, "setrank", target)
        end },
        { "Promouvoir (RP)", "rp.promote", function()
            local choices = {}
            for _, r in ipairs(NRP.Ranks.Sorted()) do choices[#choices + 1] = { r.name, r.id } end
            PickAndRun("Promotion", choices, "promote", target)
        end },
    })

    UI.Section(panel, "Économie et objets")
    ButtonGrid(panel, {
        { "Ajouter des Ryo", "admin.ryo", function() AskAndRun("Ryo", "Montant (négatif pour retirer)", "giveryo", target, "1000") end },
        { "Définir les Ryo", "admin.ryo", function() AskAndRun("Ryo", "Nouveau solde", "setryo", target) end },
        { "Donner un objet", "admin.items", function()
            PickAndRun("Objet", RegistryChoices(NRP.Inventory.Items), "giveitem", target, "Quantité", "1")
        end },
        { "Retirer un objet", "admin.items", function()
            PickAndRun("Objet", RegistryChoices(NRP.Inventory.Items), "takeitem", target, "Quantité", "1")
        end },
    })

    UI.Section(panel, "Clan, affinités et techniques")
    ButtonGrid(panel, {
        { "Attribuer un clan", "admin.clan", function()
            PickAndRun("Clan", RegistryChoices(NRP.Clans.Registry, { { "Aucun clan", "none" } }), "setclan", target)
        end },
        { "Ajouter une affinité", "admin.affinity", function()
            PickAndRun("Affinité", RegistryChoices(NRP.Elements), "addaffinity", target)
        end },
        { "Retirer une affinité", "admin.affinity", function()
            PickAndRun("Affinité", RegistryChoices(NRP.Elements), "removeaffinity", target)
        end },
        { "Affinité principale", "admin.affinity", function()
            PickAndRun("Affinité principale", RegistryChoices(NRP.Elements), "primaryaffinity", target)
        end },
        { "Donner un jutsu", "admin.jutsu", function()
            PickAndRun("Jutsu", RegistryChoices(NRP.Jutsu.Registry, { { "Tous les jutsu", "all" } }), "givejutsu", target)
        end },
        { "Retirer un jutsu", "admin.jutsu", function()
            PickAndRun("Jutsu", RegistryChoices(NRP.Jutsu.Registry), "takejutsu", target)
        end },
        { "Dojutsu", "admin.dojutsu", function()
            PickAndRun("Dojutsu", RegistryChoices(NRP.Dojutsu.Registry), "setdojutsu", target, "Stade (0 = retirer)", "1")
        end },
    })

    UI.Section(panel, "Village")
    ButtonGrid(panel, {
        { "Changer de village", "admin.village", function()
            PickAndRun("Village", RegistryChoices(Villages), "setvillage", target)
        end },
        { "Marquer déserteur", "admin.village", function() Admin.Run("setdeserter", target, 1) end, "danger" },
        { "Gracier (retour)", "admin.village", function() Admin.Run("setdeserter", target, 0) end },
        { "Réputation", "admin.reputation", function()
            PickAndRun("Réputation", RegistryChoices(Villages), "rep", target, "Montant", "10")
        end },
        { "Placer une prime", "admin.bounty", function()
            UI.RequestText("Prime", "Montant (Ryo)", "5000", function(value)
                Admin.Run("bounty", nil, "add", "#" .. target:UserID(), value, "Décision des autorités")
            end, true)
        end },
    })

    UI.Section(panel, "Missions et divers")
    ButtonGrid(panel, {
        { "Lancer une mission", "admin.mission", function()
            PickAndRun("Mission", RegistryChoices(NRP.Missions.Registry), "startmission", target)
        end },
        { "Réussir sa mission", "admin.mission", function() Admin.Run("endmission", target, 1) end },
        { "Annuler sa mission", "admin.mission", function() Admin.Run("endmission", target, 0) end },
        { "Consulter la fiche", "admin.inspect", function() Admin.Run("inspect", target) end },
        { "Réanimer / soigner", "admin.character", function() Admin.Run("revive", target) end },
        { "Renommer", "admin.character", function()
            UI.RequestText("Renommer", "Prénom et nom séparés par un espace", "", function(value)
                local first, last = string.match(value, "^%s*(%S+)%s+(%S+)%s*$")
                if first then Admin.Run("rename", target, first, last) end
            end)
        end },
        { "Supprimer le personnage", "admin.character", function()
            UI.Confirm("Supprimer le personnage", "Action définitive pour " .. target:Nick() .. ". Continuer ?", function()
                Admin.Run("wipechar", target)
                timer.Simple(0.5, function() Admin.Run("wipechar", target) end)
            end, nil, nil, "Supprimer", "Annuler")
        end, "danger" },
    })
end

local function WorldActions(panel)
    local Villages = NRP.Villages
    local theme = UI.Theme()

    UI.Section(panel, "Relations entre villages")
    local a, b, status
    local row = vgui.Create("DPanel", panel)
    row:Dock(TOP)
    row:SetTall(S(34))
    row:SetPaintBackground(false)
    local ca = UI.Combo(row, RegistryChoices(Villages), function(v) a = v end)
    ca:Dock(LEFT)
    ca:SetWide(S(180))
    ca:SetValue("Village A")
    local cb = UI.Combo(row, RegistryChoices(Villages), function(v) b = v end)
    cb:Dock(LEFT)
    cb:SetWide(S(180))
    cb:DockMargin(S(6), 0, 0, 0)
    cb:SetValue("Village B")
    local statuses = {}
    for id, rel in SortedPairsByMemberValue(Villages.RelationTypes, "order") do
        statuses[#statuses + 1] = { rel.name, id }
    end
    local cs = UI.Combo(row, statuses, function(v) status = v end)
    cs:Dock(LEFT)
    cs:SetWide(S(150))
    cs:DockMargin(S(6), 0, 0, 0)
    cs:SetValue("Statut")
    local apply = ActionButton(row, "Appliquer", "admin.villages", function()
        if a and b and status then Admin.Run("relation", nil, a, b, status) end
    end, "primary")
    apply:Dock(FILL)
    apply:DockMargin(S(6), 0, 0, 0)

    UI.Section(panel, "Événement RP")
    local ev = NRP.Events.GetCurrent()
    if ev then
        UI.Label(panel, "En cours : " .. ev.name .. " (" .. (ev.participants or 0) .. " participant(s))", "NRP.Body", theme.Warning)
    end
    ButtonGrid(panel, {
        { "Démarrer…", "rp.event", function()
            UI.RequestText("Nouvel événement", "Nom ; minutes ; multiplicateur XP ; multiplicateur Ryo", "Invasion ; 30 ; 1.5 ; 1", function(value)
                local parts = string.Explode(";", value)
                Admin.Run("event", nil, "start", string.Trim(parts[1] or "Événement"), string.Trim(parts[2] or "30"),
                    string.Trim(parts[3] or "1"), string.Trim(parts[4] or "1"))
            end)
        end },
        { "Définir le lieu (ici)", "rp.event", function() Admin.Run("event", nil, "pos") end },
        { "Description…", "rp.event", function()
            UI.RequestText("Description", "Texte affiché aux joueurs", "", function(value)
                Admin.Run("event", nil, "desc", value)
            end)
        end },
        { "Récompenser…", "rp.event", function()
            UI.RequestText("Récompense", "XP ; Ryo (pour chaque participant)", "100 ; 500", function(value)
                local parts = string.Explode(";", value)
                Admin.Run("event", nil, "reward", string.Trim(parts[1] or "0"), string.Trim(parts[2] or "0"))
            end)
        end },
        { "Terminer", "rp.event", function() Admin.Run("event", nil, "stop") end, "danger" },
    })

    UI.Section(panel, "Carte (" .. game.GetMap() .. ")")
    ButtonGrid(panel, {
        { "Point de mission (ici)", "admin.world", function()
            UI.RequestText("Point de mission", "Tag (delivery, retrieve, recon, bandits, escort, protect, defend, rogues, boss)", "delivery", function(value)
                Admin.Run("mpoint", nil, "add", value)
            end)
        end },
        { "Lister les points proches", "admin.world", function() Admin.Run("mpoint", nil, "near") end },
        { "Spawn de village (ici)", "admin.world", function()
            PickAndRun("Point d'apparition", RegistryChoices(Villages), "spawn", nil, nil, nil, "add")
        end },
        { "Donneur de mission (visé)", "admin.world", function()
            PickAndRun("Donneur de mission", RegistryChoices(Villages, { { "Tous villages", "all" } }), "missionnpc", nil)
        end },
        { "Marchand (visé)", "admin.world", function()
            PickAndRun("Marchand", RegistryChoices(NRP.Inventory.Shops), "shopnpc", nil)
        end },
        { "Mannequin (visé)", "admin.world", function() Admin.Run("dummy") end },
        { "Sauvegarder l'entité visée", "admin.world", function() Admin.Run("persist") end },
        { "Supprimer l'entité visée", "admin.world", function() Admin.Run("unpersist") end, "danger" },
        { "Journal (console)", "admin.inspect", function() Admin.Run("logs", nil, 50) end },
    })
end

UI.RegisterTab("admin", {
    name = "ADMIN",
    order = 99,
    visible = function() return NRP.Perm.Has(LocalPlayer(), "admin.menu") end,
    build = function(parent)
        local theme = UI.Theme()
        local list = vgui.Create("NRP.Card", parent)
        list:Dock(LEFT)
        list:SetWide(S(260))
        list:DockMargin(0, 0, S(12), 0)

        local search = UI.TextEntry(list, "Rechercher un joueur…")
        search:Dock(TOP)
        search:DockMargin(0, 0, 0, S(8))

        local players = vgui.Create("NRP.Scroll", list)
        players:Dock(FILL)

        local content = vgui.Create("NRP.Scroll", parent)
        content:Dock(FILL)

        local function ShowContent()
            content:Clear()
            local tabs = vgui.Create("DPanel", content)
            tabs:Dock(TOP)
            tabs:SetTall(S(36))
            tabs:SetPaintBackground(false)
            tabs:DockMargin(0, 0, 0, S(8))

            local body = vgui.Create("DPanel", content)
            body:Dock(TOP)
            body:SetPaintBackground(false)
            body.PerformLayout = function(self) self:SizeToChildren(false, true) end

            local function Show(which)
                body:Clear()
                if which == "world" then
                    WorldActions(body)
                elseif IsValid(selected) then
                    PlayerActions(body, selected)
                else
                    UI.Label(body, "Sélectionnez un joueur dans la liste.", "NRP.Body", theme.TextDim)
                end
                body:InvalidateLayout()
            end

            local pBtn = UI.Button(tabs, "Joueur", function() Show("player") end, "ghost")
            pBtn:Dock(LEFT)
            pBtn:SetWide(S(140))
            local wBtn = UI.Button(tabs, "Monde & événements", function() Show("world") end, "ghost")
            wBtn:Dock(LEFT)
            wBtn:SetWide(S(200))
            wBtn:DockMargin(S(6), 0, 0, 0)

            Show(IsValid(selected) and "player" or "world")
        end

        local function FillPlayers()
            players:Clear()
            local filter = string.lower(search:GetValue() or "")
            local sorted = player.GetAll()
            table.sort(sorted, function(x, y) return x:Nick() < y:Nick() end)
            for _, ply in ipairs(sorted) do
                local name = ply:Nick()
                if filter == "" or string.find(string.lower(name), filter, 1, true)
                    or string.find(string.lower(ply:SteamName()), filter, 1, true) then
                    local btn = UI.Button(players, name, function()
                        selected = ply
                        FillPlayers()
                        ShowContent()
                    end, selected == ply and "selected" or "ghost")
                    btn:SetFont("NRP.Small")
                    btn:Dock(TOP)
                    btn:DockMargin(0, 0, 0, S(4))
                end
            end
        end

        search.OnChange = FillPlayers
        FillPlayers()
        ShowContent()
    end,
})
