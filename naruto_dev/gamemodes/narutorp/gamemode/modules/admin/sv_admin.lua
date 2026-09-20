--[[
    Module : administration (serveur)

    Le panneau d'administration n'a AUCUN pouvoir propre : chaque bouton exécute une
    commande NRP.Commands via "NRP.AdminCommand", qui revérifie la permission de la commande.
    Consultation : !inspect <joueur>, !inspectid <steamid64>, !logs [n] [steamid64]
]]

local Char = NRP.Char
local DB = NRP.DB

NRP.Net.Pool("AdminInspect")

NRP.Net.Receive("AdminCommand", function(ply)
    local name = NRP.Net.ReadString(32)
    local count = math.min(net.ReadUInt(4), 8)
    local args = {}
    for i = 1, count do
        args[i] = NRP.Net.ReadString(200)
    end

    if not NRP.Commands.List[string.lower(name)] then return end
    NRP.Commands.Run(ply, name, args)
end, { rate = 3, burst = 6, maxBytes = 2048, needChar = false, perm = "admin.menu" })

---------------------------------------------------------------------------
-- Fiches personnage
---------------------------------------------------------------------------

local function SendInspect(caller, data, extra)
    if caller == NULL then
        NRP.Print(util.TableToJSON(data, true))
        return
    end
    local payload = table.Copy(data)
    payload.extra = extra
    NRP.Net.Start("AdminInspect")
        NRP.Net.WriteTable(payload)
    net.Send(caller)
end

NRP.Commands.Add("inspect", {
    perm = "admin.inspect", usage = "inspect <joueur>", description = "Consulter la fiche d'un personnage",
    args = { "player" },
    run = function(caller, target)
        local data = target.NRPChar
        if not data then return false, "Ce joueur n'a pas de personnage." end

        SendInspect(caller, data, {
            online = true,
            steamName = target:SteamName(),
            usergroup = target:GetUserGroup(),
            health = target:Health(),
            maxHealth = target:GetMaxHealth(),
            chakra = math.floor(NRP.Chakra.Get(target)),
            maxChakra = math.floor(NRP.Chakra.GetMax(target)),
            derived = target.NRPDerived,
            stats = target.NRPStats,
            mission = NRP.Missions.GetInstance(target) and NRP.Missions.GetInstance(target).id or nil,
            dojutsu = target:GetNW2String("NRP_Dojutsu", ""),
        })
        return true
    end,
})

NRP.Commands.Add("inspectid", {
    perm = "admin.inspect", usage = "inspectid <steamid64>", description = "Consulter un personnage hors ligne",
    args = { "string" },
    run = function(caller, steamid)
        if not string.match(steamid, "^%d+$") then return false, "SteamID64 invalide." end
        Char.LoadOffline(steamid, function(data)
            if caller ~= NULL and not IsValid(caller) then return end
            if not data then
                NRP.Notify(caller, "Aucun personnage pour ce SteamID64.", NRP.NOTIFY_ERROR)
                return
            end
            SendInspect(caller, data, { online = false })
        end)
        return true
    end,
})

NRP.Commands.Add("logs", {
    perm = "admin.inspect", usage = "logs [nombre] [steamid64]", description = "Dernières actions enregistrées (console)",
    args = { "number?", "string?" },
    run = function(caller, count, steamid)
        count = math.Clamp(math.floor(count or 30), 1, 200)
        local where = ""
        local params = {}
        if steamid and string.match(steamid, "^%d+$") then
            where = " WHERE target = ? OR actor = ?"
            params = { steamid, steamid }
        end

        DB.Query("SELECT * FROM " .. DB.Ident(DB.Table("logs")) .. where .. " ORDER BY id DESC LIMIT " .. count, params, function(rows)
            if caller ~= NULL and not IsValid(caller) then return end
            for i = #rows, 1, -1 do
                local r = rows[i]
                local line = string.format("[%s] %-9s %s : %s", os.date("%d/%m %H:%M", tonumber(r.time) or 0),
                    r.category, r.actor_name, r.message)
                if caller == NULL then NRP.Print(line) else caller:PrintMessage(HUD_PRINTCONSOLE, line) end
            end
            if caller ~= NULL then
                NRP.Notify(caller, #rows .. " entrée(s) affichée(s) dans la console.", NRP.NOTIFY_INFO)
            end
        end)
        return true
    end,
})

---------------------------------------------------------------------------
-- Ryo et personnages
---------------------------------------------------------------------------

NRP.Commands.Add("giveryo", {
    perm = "admin.ryo", usage = "giveryo <joueur> <montant>", description = "Ajouter (ou retirer) des Ryo",
    args = { "player", "number" }, aliases = { "addryo" },
    run = function(caller, target, amount)
        if not target.NRPChar then return false, "Ce joueur n'a pas de personnage." end
        amount = math.floor(amount)
        if not Char.AddRyo(target, amount, "admin") then return false, "Solde insuffisant." end
        NRP.LogAction("admin", caller, target, "Ryo " .. amount)
        return true, NRP.Util.FormatNumber(amount) .. " Ryo -> " .. target:Nick()
    end,
})

NRP.Commands.Add("setryo", {
    perm = "admin.ryo", usage = "setryo <joueur> <montant>", description = "Définir les Ryo",
    args = { "player", "number" },
    run = function(caller, target, amount)
        if not target.NRPChar then return false, "Ce joueur n'a pas de personnage." end
        amount = math.max(0, math.floor(amount))
        Char.Set(target, "ryo", amount)
        NRP.LogAction("admin", caller, target, "Ryo = " .. amount)
        return true, target:Nick() .. " a maintenant " .. NRP.Util.FormatNumber(amount) .. " Ryo"
    end,
})

NRP.Commands.Add("rename", {
    perm = "admin.character", usage = 'rename <joueur> "<prénom>" "<nom>"', description = "Renommer un personnage",
    args = { "player", "string", "string" },
    run = function(caller, target, first, last)
        if not target.NRPChar then return false, "Ce joueur n'a pas de personnage." end
        local ok, err = Char.Rename(target, first, last)
        if not ok then return false, err end
        NRP.LogAction("admin", caller, target, "renommé " .. first .. " " .. last)
        return true, "Personnage renommé."
    end,
})

NRP.Commands.Add("wipechar", {
    perm = "admin.character", usage = "wipechar <joueur>", description = "Supprimer un personnage (confirmation requise)",
    args = { "player" },
    run = function(caller, target)
        if not target.NRPChar then return false, "Ce joueur n'a pas de personnage." end

        local key = caller == NULL and "console" or caller
        Char.WipeConfirm = Char.WipeConfirm or {}
        local pending = Char.WipeConfirm[key]
        if not pending or pending.target ~= target or pending.expires < CurTime() then
            Char.WipeConfirm[key] = { target = target, expires = CurTime() + 15 }
            return true, "Retapez la commande dans les 15 s pour supprimer DÉFINITIVEMENT " .. target:Nick() .. "."
        end

        Char.WipeConfirm[key] = nil
        NRP.LogAction("admin", caller, target, "suppression du personnage " .. target:Nick())
        Char.Delete(target)
        return true, "Personnage supprimé."
    end,
})

NRP.Commands.Add("revive", {
    perm = "admin.character", usage = "revive <joueur>", description = "Réanimer et soigner un joueur",
    args = { "player" },
    run = function(caller, target)
        if not target:Alive() then target:Spawn() end
        target:SetHealth(target:GetMaxHealth())
        NRP.Chakra.Fill(target)
        NRP.Stamina.Fill(target)
        NRP.Status.ClearAll(target)
        NRP.LogAction("admin", caller, target, "réanimation")
        return true, target:Nick() .. " soigné."
    end,
})
