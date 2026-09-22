--========================================================
-- Noclip sur la touche N (CLIENT)
-- Le serveur décide toujours : GM:PlayerNoClip exige la
-- permission "admin.noclip".
--========================================================

local KEY = KEY_N
local wasDown = false

hook.Add("Think", "NA_NoclipTouche", function()
    local ply = LocalPlayer()
    if vgui.GetKeyboardFocus() or gui.IsGameUIVisible() or not IsValid(ply) or ply:IsTyping() then
        wasDown = false
        return
    end

    local down = input.IsKeyDown(KEY)
    if down and not wasDown then
        RunConsoleCommand("noclip")
    end
    wasDown = down
end)
