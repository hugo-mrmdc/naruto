--========================================================
-- Touche de l'attaque spéciale des armes (CLIENT)
-- Se change dans les Paramètres (F1), action "special" (cl_parametres.lua). Défaut : clic droit.
-- La touche est recopiée dans la convar userinfo "na_touche_special", lue par le serveur
-- (naruto_arme_base.lua) : clic droit = SecondaryAttack, autre touche = message réseau.
--========================================================

local cv = CreateClientConVar("na_touche_special", tostring(MOUSE_RIGHT), false, true)

local enfonce = false
hook.Add("Think", "NA_ToucheSpecial", function()
    if not NA_Touche then return end
    local touche = NA_Touche("special")
    if cv:GetInt() ~= touche then cv:SetInt(touche) end
    if touche == MOUSE_RIGHT then enfonce = false return end   -- clic droit : géré par SecondaryAttack

    local ply = LocalPlayer()
    local bloque = gui.IsGameUIVisible() or vgui.CursorVisible() or ply:IsTyping()
    local bas = not bloque and NA_ToucheBas("special")
    if bas and not enfonce then
        local w = ply:GetActiveWeapon()
        if IsValid(w) and w.Special then
            net.Start("NA_Arme_Special")
            net.SendToServer()
        end
    end
    enfonce = bas
end)
