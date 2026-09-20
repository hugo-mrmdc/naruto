--[[
    Core : commandes (chat "!cmd" ou "/cmd", console "nrp cmd ...")

        NRP.Commands.Add("givexp", {
            perm = "admin.xp",
            description = "Donne de l'XP",
            args = { "player", "number" },
            run = function(caller, target, amount) ... return true, "message" end,
        })

    Types d'arguments : "player", "number", "string", "text" (reste de la ligne),
    suffixe "?" pour un argument optionnel ("number?").
    Pour un argument "player", « moi » (ou « ^ ») désigne l'auteur de la commande.
]]

NRP.Commands = NRP.Commands or {}
local Commands = NRP.Commands

Commands.List = Commands.List or {}

function Commands.Add(name, def)
    name = string.lower(name)
    def.name = name
    Commands.List[name] = def
    for _, alias in ipairs(def.aliases or {}) do
        Commands.List[string.lower(alias)] = def
    end
end

local function Reply(caller, ok, message)
    if not message or message == "" then return end
    if caller == NULL then
        NRP.Print(message)
    else
        NRP.Notify(caller, message, ok and NRP.NOTIFY_SUCCESS or NRP.NOTIFY_ERROR)
    end
end

-- "moi", "me" ou "^" désignent le joueur qui tape la commande
local SELF_ALIASES = { moi = true, me = true, ["^"] = true }

local function ParseArgs(caller, def, raw)
    local out = {}
    local specs = def.args or {}

    for i, spec in ipairs(specs) do
        local optional = string.sub(spec, -1) == "?"
        local kind = optional and string.sub(spec, 1, -2) or spec
        local value = raw[i]

        if kind == "text" then
            value = table.concat(raw, " ", i)
            if value == "" then value = nil end
        end

        if value == nil then
            if not optional then
                return nil, "Argument manquant (" .. kind .. "). Usage : " .. (def.usage or def.name)
            end
        elseif kind == "player" then
            local self = caller ~= NULL and IsValid(caller) and SELF_ALIASES[string.lower(value)]
            local ply, err
            if self then
                ply = caller
            else
                ply, err = NRP.Util.FindPlayer(value)
            end
            if not ply then return nil, err end
            value = ply
        elseif kind == "number" then
            value = tonumber(value)
            if not value or value ~= value or math.abs(value) == math.huge then
                return nil, "Nombre invalide : " .. tostring(raw[i])
            end
        end

        out[i] = value
        if kind == "text" then break end
    end

    return out, #specs
end

function Commands.Run(caller, name, rawArgs)
    local def = Commands.List[string.lower(name or "")]
    if not def then return false end

    if def.perm and not NRP.Perm.Has(caller, def.perm) then
        Reply(caller, false, "Vous n'avez pas la permission d'utiliser cette commande.")
        return true
    end

    if def.needChar and caller ~= NULL and not caller.NRPChar then
        Reply(caller, false, "Vous devez avoir un personnage.")
        return true
    end

    -- anti-spam
    if caller ~= NULL then
        if (caller.NRPNextCommand or 0) > CurTime() then return true end
        caller.NRPNextCommand = CurTime() + 0.3
    end

    local args, count = ParseArgs(caller, def, rawArgs)
    if not args then
        Reply(caller, false, count)
        return true
    end

    local ok, success, message = pcall(def.run, caller, unpack(args, 1, count))
    if not ok then
        NRP.Error("Commande " .. def.name .. " :", success)
        Reply(caller, false, "Erreur interne lors de l'exécution de la commande.")
        return true
    end

    Reply(caller, success ~= false, message)
    return true
end

hook.Add("PlayerSay", "NRP.Commands", function(ply, text)
    local prefix = string.sub(text, 1, 1)
    if prefix ~= "!" and prefix ~= "/" then return end

    local args = NRP.Util.SplitArgs(string.sub(text, 2))
    local name = table.remove(args, 1)
    if name and Commands.List[string.lower(name)] then
        Commands.Run(ply, name, args)
        return ""
    end
end)

concommand.Add("nrp", function(ply, _, args)
    local name = table.remove(args, 1)
    if not name or not Commands.Run(ply, name, args) then
        Reply(ply, false, "Commande inconnue. Tapez « nrp help ».")
    end
end)

Commands.Add("help", {
    description = "Liste des commandes disponibles",
    aliases = { "aide", "commands" },
    run = function(caller)
        local lines = {}
        local seen = {}
        for _, def in SortedPairs(Commands.List) do
            if not seen[def] and (not def.perm or NRP.Perm.Has(caller, def.perm)) then
                seen[def] = true
                lines[#lines + 1] = "!" .. (def.usage or def.name) .. "  -  " .. (def.description or "")
            end
        end

        if caller == NULL then
            for _, l in ipairs(lines) do NRP.Print(l) end
        else
            NRP.ChatPrint(caller, Color(255, 140, 30), "[Naruto RP] ", color_white, #lines .. " commandes (voir console)")
            caller:PrintMessage(HUD_PRINTCONSOLE, "--- Naruto RP ---")
            for _, l in ipairs(lines) do
                caller:PrintMessage(HUD_PRINTCONSOLE, l)
            end
        end
        return true
    end,
})
