--[[
    Module : administration (client)
    NRP.Admin.Run("givexp", target, "100") exécute une commande (vérifiée côté serveur).
    Hook : "NRP.AdminInspect"(data)
]]

NRP.Admin = NRP.Admin or {}
local Admin = NRP.Admin

-- target peut être un joueur (converti en #userid) ou nil
function Admin.Run(command, target, ...)
    if not NRP.Net.CanSend("AdminCommand", 0.3) then return end

    local args = {}
    if IsValid(target) then
        args[1] = "#" .. target:UserID()
    end
    for _, v in ipairs({ ... }) do
        args[#args + 1] = tostring(v)
    end

    NRP.Net.Start("AdminCommand")
        net.WriteString(command)
        net.WriteUInt(math.min(#args, 8), 4)
        for i = 1, math.min(#args, 8) do
            net.WriteString(args[i])
        end
    net.SendToServer()
end

NRP.Net.Receive("AdminInspect", function()
    local data = NRP.Net.ReadTable()
    if data then
        hook.Run("NRP.AdminInspect", data)
    end
end)
