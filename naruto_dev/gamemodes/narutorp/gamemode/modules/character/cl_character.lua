--[[
    Module : personnage (client)

    NRP.Char.Local contient les données privées du joueur local.
    Hooks émis :
        "NRP.CharSynced"(changedKeys, full)   -- après chaque réception
        "NRP.OpenCreation"(info)              -- l'UI ouvre la création
        "NRP.CreationResult"(ok, message)
]]

local Char = NRP.Char

NRP.Net.Receive("CharSync", function()
    local full = net.ReadBool()
    local payload = NRP.Net.ReadTable()
    if not payload then return end

    if full or not Char.Local then
        Char.Local = payload
    else
        for k, v in pairs(payload) do
            Char.Local[k] = v
        end
    end

    local changed = {}
    for k in pairs(payload) do
        changed[k] = true
    end

    hook.Run("NRP.CharSynced", changed, full)
end)

NRP.Net.Receive("OpenCreation", function()
    local info = NRP.Net.ReadTable() or {}
    Char.Local = nil
    Char.CreationInfo = info
    hook.Run("NRP.OpenCreation", info)
end)

NRP.Net.Receive("CreationResult", function()
    local ok = net.ReadBool()
    local message = net.ReadString()
    hook.Run("NRP.CreationResult", ok, message)
end)

-- Les messages réseau ne sont fiables qu'une fois les entités créées côté client.
hook.Add("InitPostEntity", "NRP.Char.ClientReady", function()
    NRP.Net.Start("ClientReady")
    net.SendToServer()
end)

-- Envoi de la demande de création (appelé par l'UI)
function Char.RequestCreate(req)
    if not NRP.Net.CanSend("CreateCharacter", 1) then return false end

    NRP.Net.Start("CreateCharacter")
        net.WriteString(req.firstname or "")
        net.WriteString(req.lastname or "")
        net.WriteString(req.gender or "")
        net.WriteString(req.village or "")
        net.WriteString(req.clan or "")
        net.WriteString(req.affinity or "")
        net.WriteUInt(math.Clamp(req.modelIndex or 1, 0, 255), 8)
        net.WriteUInt(math.Clamp(req.skin or 0, 0, 255), 8)

        local bodygroups = {}
        for id, value in pairs(req.bodygroups or {}) do
            if #bodygroups < 31 then
                bodygroups[#bodygroups + 1] = { id, value }
            end
        end
        net.WriteUInt(#bodygroups, 5)
        for _, bg in ipairs(bodygroups) do
            net.WriteUInt(math.Clamp(bg[1], 0, 255), 8)
            net.WriteUInt(math.Clamp(bg[2], 0, 255), 8)
        end

        local c = req.color or { 255, 255, 255 }
        net.WriteUInt(math.Clamp(c[1] or 255, 0, 255), 8)
        net.WriteUInt(math.Clamp(c[2] or 255, 0, 255), 8)
        net.WriteUInt(math.Clamp(c[3] or 255, 0, 255), 8)
    net.SendToServer()
    return true
end
