chat.AddText(Color(0,255,0), "[Jutsu] script chargé (ANIM + SON)")

local wasDown = false

hook.Add("Think", "Jutsu_Key_Play", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local down = input.IsKeyDown(KEY_I)

    if down and not wasDown and NA_TouchesDirectes and NA_TouchesDirectes() then
        -- Joue l'animation
        
        Jutsu.Play("nrp_ninjutsu_defend_dragonflamebombs_start")
        -- Demande au serveur de jouer le son
        net.Start("Jutsu_PlaySound")
        net.SendToServer()
    end

    wasDown = down
end)
