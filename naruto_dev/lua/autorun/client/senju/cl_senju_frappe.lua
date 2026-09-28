--========================================================
-- Senju : Frappe terrestre (CLIENT)
--
-- Envoie seulement l'appui au serveur (sv_senju_frappe.lua, qui décide de tout).
-- La particule d'impact est lancée par le serveur.
--========================================================

game.AddParticles("particles/solve_doton.pcf")
PrecacheParticleSystem("solve_doton_pics_floor")

NA_Cast = NA_Cast or {}
NA_Cast.senju_frappe = function()
    net.Start("senju_frappe_cast")
    net.SendToServer()
end
