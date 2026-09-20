--========================================================
-- Dôme de brume de la salamandre (CLIENT)
--
-- Le client ne fait qu'envoyer l'appui : incantation, zone, dégâts et
-- recharge sont décidés par le serveur (sv_dome_salamandre.lua).
-- La brume est affichée par l'entité salamandre_zone (lua/entities).
--========================================================

local KEY = KEY_T

local appuiDome = false

hook.Add("Think", "SalamandreDome_KeyListener", function()
    local ply = LocalPlayer()
    if vgui.GetKeyboardFocus() or gui.IsGameUIVisible() or not IsValid(ply) or ply:IsTyping() or not ply:Alive() then
        appuiDome = false
        return
    end

    -- un appui = un lancement
    local down = input.IsKeyDown(KEY)
    if down and not appuiDome and NA_TouchesDirectes() then
        NA_Lancer("salamandre_dome")
    end
    appuiDome = down
end)

-- Lancement (appelé par la touche T ET par la barre de techniques).
-- La recharge est vérifiée par NA_Lancer avec la vraie valeur du serveur.
NA_Cast = NA_Cast or {}
NA_Cast.salamandre_dome = function()
    net.Start("dome_Salamandre")
    net.SendToServer()
end
