--========================================================
-- Crachat de poison de la salamandre (CLIENT)
--
-- Le client ne fait qu'envoyer l'appui sur la touche : incantation, animations,
-- départ du projectile et recharge sont décidés par le serveur
-- (sv_poison_projectile.lua). Le projectile et sa traînée sont gérés par
-- l'entité salamandre_poison_spit (lua/entities).
--========================================================

local KEY = KEY_I

local wasDown = false

hook.Add("Think", "PoisonProjectile_KeyDetection", function()
    local ply = LocalPlayer()
    if vgui.GetKeyboardFocus() or gui.IsGameUIVisible() or not IsValid(ply) or ply:IsTyping() or not ply:Alive() then
        wasDown = false
        return
    end

    -- un appui = un crachat (avant : maintenir la touche relançait le sort en boucle)
    local down = input.IsKeyDown(KEY)
    if down and not wasDown and NA_TouchesDirectes() then
        NA_Lancer("salamandre_poison")
    end
    wasDown = down
end)

-- Lancement (appelé par la touche I ET par la barre de techniques)
NA_Cast = NA_Cast or {}
NA_Cast.salamandre_poison = function()
    net.Start("PoisonProjectile_Fire")
    net.SendToServer()
end


----------------------------------------------------------
-- Voile vert discret tant que tu es empoisonné
----------------------------------------------------------
hook.Add("HUDPaint", "SalamandrePoison_HUD", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() or not ply:GetNW2Bool("NA_Empoisonne", false) then return end

    local a = 25 + math.abs(math.sin(CurTime() * 3)) * 25
    surface.SetDrawColor(40, 200, 40, a)
    surface.DrawRect(0, 0, ScrW(), ScrH())
end)
