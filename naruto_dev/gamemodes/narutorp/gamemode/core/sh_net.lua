--[[
    Core : réseau

    Tous les messages sont préfixés "NRP.".
    Côté serveur, NRP.Net.Receive ajoute automatiquement :
        - util.AddNetworkString
        - une limite de débit par joueur (token bucket)
        - une taille maximale de message
        - une vérification de permission / de personnage chargé / de joueur vivant
        - un pcall pour qu'un message malformé ne casse pas le serveur
    Un joueur qui dépasse trop souvent les limites est signalé puis expulsé (config Net).

    Règle : le client n'envoie que des INTENTIONS (ids, index). Le serveur revalide tout.
]]

NRP.Net = NRP.Net or {}
local Net = NRP.Net

local PREFIX = "NRP."

local function NetConfig()
    return NRP.Config.Net or {}
end

function Net.Name(name)
    return PREFIX .. name
end

function Net.Start(name, unreliable)
    net.Start(PREFIX .. name, unreliable)
end

-- Tables compressées (serveur -> client uniquement : le serveur n'accepte jamais
-- de table arbitraire venant d'un client).
function Net.WriteTable(tbl)
    local data = util.Compress(util.TableToJSON(tbl or {}))
    net.WriteUInt(#data, 32)
    net.WriteData(data, #data)
end

function Net.ReadTable(maxBytes)
    local len = net.ReadUInt(32)
    if len <= 0 or len > (maxBytes or 1048576) then return nil end
    local json = util.Decompress(net.ReadData(len))
    if not json then return nil end
    return util.JSONToTable(json)
end

-- Chaîne bornée : tronque et nettoie les caractères de contrôle.
function Net.ReadString(maxLen)
    local s = net.ReadString()
    if #s > (maxLen or 64) then
        s = string.sub(s, 1, maxLen or 64)
    end
    return (string.gsub(s, "[%c]", ""))
end

function Net.ReadId()
    local id = net.ReadString()
    if not NRP.Util.IsValidId(id) then return nil end
    return id
end

if SERVER then
    local buckets = {}

    -- Déclare un message émis par le serveur.
    function Net.Pool(name)
        util.AddNetworkString(PREFIX .. name)
    end

    function Net.Consume(ply, key, rate, burst)
        local now = SysTime()
        local perPly = buckets[ply]
        if not perPly then
            perPly = {}
            buckets[ply] = perPly
        end

        local b = perPly[key]
        if not b then
            b = { tokens = burst, last = now }
            perPly[key] = b
        end

        b.tokens = math.min(burst, b.tokens + (now - b.last) * rate)
        b.last = now

        if b.tokens < 1 then
            return false
        end
        b.tokens = b.tokens - 1
        return true
    end

    function Net.Flag(ply, name, reason)
        ply.NRPNetFlags = (ply.NRPNetFlags or 0) + 1
        local cfg = NetConfig()

        if (ply.NRPNextFlagLog or 0) < SysTime() then
            ply.NRPNextFlagLog = SysTime() + 5
            NRP.Warn(string.format("Net suspect : %s (%s) %s -> %s [%d]",
                ply:Nick(), ply:SteamID64() or "?", name, reason, ply.NRPNetFlags))
        end

        if cfg.KickThreshold and ply.NRPNetFlags >= cfg.KickThreshold then
            ply:Kick(cfg.KickMessage or "Trop de requêtes réseau")
        end
    end

    --[[
        opts :
            rate      = messages/seconde autorisés (défaut 4)
            burst     = rafale max (défaut rate)
            maxBytes  = taille max du message (défaut 512)
            perm      = permission requise
            needChar  = personnage chargé requis (défaut true)
            alive     = joueur vivant requis
    ]]
    function Net.Receive(name, fn, opts)
        opts = opts or {}
        local full = PREFIX .. name
        local rate = opts.rate or 4
        local burst = opts.burst or math.max(1, rate)
        local maxBits = (opts.maxBytes or 512) * 8

        util.AddNetworkString(full)

        net.Receive(full, function(len, ply)
            if not IsValid(ply) then return end

            if len > maxBits then
                Net.Flag(ply, full, "taille " .. len)
                return
            end

            if not Net.Consume(ply, full, rate, burst) then
                Net.Flag(ply, full, "débit")
                return
            end

            if opts.needChar ~= false and not ply.NRPChar then return end
            if opts.alive and not ply:Alive() then return end

            if opts.perm and not NRP.Perm.Has(ply, opts.perm) then
                Net.Flag(ply, full, "permission " .. opts.perm)
                return
            end

            local ok, err = pcall(fn, ply, len)
            if not ok then
                NRP.Error("Erreur dans le handler " .. full .. " :", err)
            end
        end)
    end

    -- Les signalements s'effacent progressivement.
    timer.Create("NRP.Net.FlagDecay", 60, 0, function()
        for _, ply in NRP.Util.PlayerIterator() do
            if (ply.NRPNetFlags or 0) > 0 then
                ply.NRPNetFlags = math.max(0, ply.NRPNetFlags - (NetConfig().FlagDecay or 5))
            end
        end
    end)

    hook.Add("PlayerDisconnected", "NRP.Net.Cleanup", function(ply)
        buckets[ply] = nil
    end)
else
    function Net.Receive(name, fn)
        net.Receive(PREFIX .. name, fn)
    end

    -- Anti-rebond côté client pour ne pas se faire signaler bêtement.
    local lastSend = {}
    function Net.CanSend(name, interval)
        local now = RealTime()
        if (lastSend[name] or 0) + (interval or 0.25) > now then
            return false
        end
        lastSend[name] = now
        return true
    end
end
