--========================================================
-- Permutation (CLIENT) - touche V par défaut (modifiable dans les Paramètres F1)
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.permutation = function()
    net.Start("permutation_cast")
    net.SendToServer()
end

local last = false
hook.Add("Think", "Permutation_Touche", function()
    local lp = LocalPlayer()
    -- pas de technique en tapant dans le chat / un menu, ni mort
    if vgui.GetKeyboardFocus() or gui.IsGameUIVisible() or not IsValid(lp) or lp:IsTyping() or not lp:Alive() then
        last = false
        return
    end
    local pressed = NA_ToucheBas and NA_ToucheBas("permutation") or false
    if pressed and not last then   -- touche directe : indépendante de NA_TouchesDirectes (désactivé pour les autres techniques)
        NA_Lancer("permutation")
    end
    last = pressed
end)

-- Fumée de la téléportation Fuma, posée à l'endroit envoyé par le serveur (torse)
game.AddParticles("particles/atg_orugi_particle.pcf")
PrecacheParticleSystem("smoke_orugi2")

net.Receive("permutation_fx", function()
    ParticleEffect("smoke_orugi2", net.ReadVector(), angle_zero)
end)
